/**
 * Score Sync Job — node-cron (FREE npm package)
 *
 * Runs on a schedule to:
 *  1. Fetch finished matches from football-data.org (free API)
 *  2. Map scorer stats to player_scores table
 *  3. Recalculate team gameweek points
 *  4. Update team + user total_points
 *  5. Emit a socket.io broadcast so the app updates in real-time
 *
 * Cron schedules (all free, no external service needed):
 *   Every 30 min during WC group stage:  '* /30 * * * *'   (remove the space)
 *   Every hour outside matches:          '0 * * * *'
 *   Once per day (maintenance):          '0 3 * * *'
 *
 * IMPORTANT: football-data.org free tier = 10 req/min.
 * The footballData service already throttles to 1 req / 6s.
 */

const cron = require('node-cron');
const { pool }        = require('../config/db');
const { getIO }       = require('../socket/socket');
const footballData    = require('../services/footballData.service');
const { sumTeamGwPoints, chipForGameweek } = require('../utils/scoring');

// ─── Points system (mirrors gameweek.controller.js) ─────────────────────────
const POINTS = {
  GK:  { goal: 10, assist: 6, clean_sheet: 6, yellow: -1, red: -3 },
  DEF: { goal: 6,  assist: 3, clean_sheet: 4, yellow: -1, red: -3 },
  MID: { goal: 5,  assist: 3, clean_sheet: 1, yellow: -1, red: -3 },
  FWD: { goal: 4,  assist: 3, clean_sheet: 0, yellow: -1, red: -3 },
  playing_60plus_min: 2,
  playing_1_to_59min: 1,
  hat_trick_bonus: 5,
  own_goal: -2,
  penalty_save: 5,
  penalty_miss: -2,
};

function calcPoints(score, position) {
  const pts = POINTS[position] || POINTS.MID;
  let total = 0;
  if (score.minutes_played >= 60)     total += POINTS.playing_60plus_min;
  else if (score.minutes_played > 0)  total += POINTS.playing_1_to_59min;
  total += score.goals   * pts.goal;
  if (score.goals >= 3)              total += POINTS.hat_trick_bonus;
  total += score.assists * pts.assist;
  if (score.clean_sheet) total += pts.clean_sheet;
  total += score.yellow_cards * pts.yellow;
  total += score.red_cards    * pts.red;
  if (score.own_goals)        total += score.own_goals        * POINTS.own_goal;
  if (score.penalties_saved)  total += score.penalties_saved  * POINTS.penalty_save;
  if (score.penalties_missed) total += score.penalties_missed * POINTS.penalty_miss;
  total += score.bonus || 0;
  return Math.max(total, 0);
}

// ─── Core sync logic ─────────────────────────────────────────────────────────

/**
 * Sync top-scorer totals from football-data.org into player_scores.
 * The free API provides season totals, so we:
 *   1. Find the active gameweek
 *   2. Match scorers by name to our players table
 *   3. Upsert player_scores for that gameweek
 *   4. Recalculate team points
 */
async function syncScores() {
  console.log('[ScoreSync] Starting score sync…');

  const client = await pool.connect();
  try {
    // 0. Refresh persisted fixtures from finished match results (independent of GW state).
    await upsertFinishedMatches(client);

    // 1. Find active gameweek
    const gwResult = await client.query(
      `SELECT * FROM gameweeks WHERE status = 'active' ORDER BY number ASC LIMIT 1`
    );
    if (gwResult.rows.length === 0) {
      // No active GW — kick off the next one whose deadline has passed.
      await autoStartDueGameweek(client);
      console.log('[ScoreSync] No active gameweek.');
      return;
    }
    const gameweek = gwResult.rows[0];

    // 2. Fetch scorers (best-effort) → upsert goals/assists.
    let synced = 0;
    try {
      const scorers = await footballData.getTopScorers(200);
      if (scorers.length) {
        const playersResult = await client.query('SELECT id, name, position FROM players');
        const playerMap = {};
        for (const p of playersResult.rows) playerMap[p.name.toLowerCase()] = p;

        for (const scorer of scorers) {
          const stats = footballData.mapScorerToStats(scorer);
          const player = playerMap[stats.playerName.toLowerCase()];
          if (!player) continue;

          const totalPoints = calcPoints({
            goals: stats.goals, assists: stats.assists, minutes_played: 90,
            clean_sheet: false, yellow_cards: 0, red_cards: 0, own_goals: 0,
            penalties_saved: 0, penalties_missed: stats.penalties || 0, bonus: 0,
          }, player.position);

          await client.query(`
            INSERT INTO player_scores
              (player_id, gameweek_id, goals, assists, minutes_played, total_points)
            VALUES ($1, $2, $3, $4, 90, $5)
            ON CONFLICT (player_id, gameweek_id) DO UPDATE SET
              goals = EXCLUDED.goals, assists = EXCLUDED.assists,
              minutes_played = EXCLUDED.minutes_played, total_points = EXCLUDED.total_points
          `, [player.id, gameweek.id, stats.goals, stats.assists, totalPoints]);
          synced++;
        }
      }
    } catch (apiErr) {
      console.error('[ScoreSync] Scorer fetch error:', apiErr.message);
    }
    console.log(`[ScoreSync] Synced ${synced} player scores for GW ${gameweek.number}.`);

    // 3. Best-effort clean sheets from finished match results.
    await applyCleanSheets(client, gameweek.id);

    // 4. Recalculate team_gameweek_scores (captain + chips applied).
    await recalcTeamPoints(client, gameweek.id);

    // 5. Auto-advance this gameweek if its matchday is fully finished.
    await autoAdvanceIfComplete(client, gameweek);

    // 6. Notify connected clients via socket.io
    try {
      getIO().emit('scores:updated', { gameweekId: gameweek.id, gameweekNumber: gameweek.number });
    } catch (_) { /* socket may not be ready */ }

    console.log('[ScoreSync] Done.');
  } catch (err) {
    console.error('[ScoreSync] Unexpected error:', err.message);
  } finally {
    client.release();
  }
}

/** Upsert finished match scorelines into the matches table (keeps fixtures fresh). */
async function upsertFinishedMatches(client) {
  let finished;
  try {
    finished = await footballData.getAllMatches('FINISHED');
  } catch (err) {
    console.error('[ScoreSync] Match fetch error:', err.message);
    return;
  }
  for (const m of finished) {
    const r = footballData.mapMatchResult(m);
    // Update existing rows only (seeded by seed-gameweeks); leave matchday/gw link intact.
    await client.query(
      `UPDATE matches SET home_goals = $1, away_goals = $2, status = $3, updated_at = NOW()
       WHERE fd_match_id = $4`,
      [r.homeGoals, r.awayGoals, m.status, r.matchId]
    );
  }
}

/**
 * Award clean sheets (best-effort) by enriching EXISTING player_scores rows for
 * players whose nation conceded 0 in a finished match this gameweek. Idempotent:
 * only credits rows where clean_sheet is still false.
 */
async function applyCleanSheets(client, gameweekId) {
  const matches = await client.query(
    `SELECT home_team, away_team, home_goals, away_goals
     FROM matches WHERE gameweek_id = $1 AND status = 'FINISHED'
       AND home_goals IS NOT NULL AND away_goals IS NOT NULL`,
    [gameweekId]
  );

  const cleanSheetNations = new Set();
  for (const m of matches.rows) {
    if (m.away_goals === 0) cleanSheetNations.add(m.home_team);
    if (m.home_goals === 0) cleanSheetNations.add(m.away_team);
  }

  for (const nation of cleanSheetNations) {
    if (!nation) continue;
    await client.query(
      `UPDATE player_scores ps
       SET clean_sheet = true,
           total_points = total_points + (CASE p.position
             WHEN 'GK' THEN 6 WHEN 'DEF' THEN 4 WHEN 'MID' THEN 1 ELSE 0 END)
       FROM players p
       WHERE ps.player_id = p.id AND ps.gameweek_id = $1
         AND p.nationality = $2 AND ps.clean_sheet = false
         AND p.position IN ('GK','DEF','MID')`,
      [gameweekId, nation]
    );
  }
}

/** Activate the next upcoming gameweek whose deadline has passed (no GW currently active). */
async function autoStartDueGameweek(client) {
  const r = await client.query(
    `UPDATE gameweeks SET status = 'active', started_at = NOW()
     WHERE id = (SELECT id FROM gameweeks WHERE status = 'upcoming' AND deadline <= NOW()
                 ORDER BY number ASC LIMIT 1)
     RETURNING *`
  );
  if (r.rows[0]) {
    try { getIO().emit('gameweek:started', r.rows[0]); } catch (_) { /* socket */ }
    console.log(`[ScoreSync] Auto-started GW ${r.rows[0].number}.`);
  }
}

/** Finish the active gameweek + activate the next when all its matches are FINISHED. */
async function autoAdvanceIfComplete(client, gameweek) {
  const cnt = await client.query(
    `SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE status = 'FINISHED') AS done
     FROM matches WHERE gameweek_id = $1`,
    [gameweek.id]
  );
  const total = parseInt(cnt.rows[0].total, 10);
  const done = parseInt(cnt.rows[0].done, 10);
  if (total === 0 || done < total) return; // not complete yet

  await client.query(
    `UPDATE gameweeks SET status = 'finished', finished_at = NOW() WHERE id = $1`,
    [gameweek.id]
  );
  // Consume chips armed for this gameweek.
  await client.query(
    `UPDATE teams
     SET chips_used = chips_used || jsonb_build_object('chip', active_chip, 'gameweek', active_chip_gw),
         active_chip = NULL, active_chip_gw = NULL, boost_player_id = NULL
     WHERE active_chip IS NOT NULL AND active_chip_gw = $1`,
    [gameweek.number]
  );
  // Activate the next upcoming gameweek.
  const next = await client.query(
    `UPDATE gameweeks SET status = 'active', started_at = NOW()
     WHERE id = (SELECT id FROM gameweeks WHERE status = 'upcoming' ORDER BY number ASC LIMIT 1)
     RETURNING *`
  );
  try {
    const io = getIO();
    io.emit('gameweek:finished', gameweek);
    if (next.rows[0]) io.emit('gameweek:started', next.rows[0]);
  } catch (_) { /* socket */ }
  console.log(`[ScoreSync] Auto-advanced: finished GW ${gameweek.number}${next.rows[0] ? `, started GW ${next.rows[0].number}` : ''}.`);
}

/**
 * Recalculate team_gameweek_scores for all teams in an active gameweek,
 * then update teams.total_points and users.total_points.
 */
async function recalcTeamPoints(client, gameweekId) {
  // Gameweek number — needed to know which teams have a chip armed for it.
  const gwNumRes = await client.query('SELECT number FROM gameweeks WHERE id = $1', [gameweekId]);
  const gwNumber = gwNumRes.rows[0]?.number;

  // Get all teams with their player JSON + armed chip
  const teamsResult = await client.query(
    'SELECT id, players, captain_id, active_chip, active_chip_gw, boost_player_id FROM teams'
  );

  for (const team of teamsResult.rows) {
    let teamPlayers = team.players;
    if (typeof teamPlayers === 'string') {
      try { teamPlayers = JSON.parse(teamPlayers); } catch { teamPlayers = []; }
    }
    if (!Array.isArray(teamPlayers) || !teamPlayers.length) continue;

    const playerIds = teamPlayers.map(p => (typeof p === 'string' ? p : p.id)).filter(Boolean);
    if (!playerIds.length) continue;

    // Sum points for each player in the team this gameweek
    const scoresResult = await client.query(`
      SELECT ps.player_id, ps.total_points
      FROM player_scores ps
      WHERE ps.gameweek_id = $1 AND ps.player_id = ANY($2)
    `, [gameweekId, playerIds]);

    const totalPoints = sumTeamGwPoints(scoresResult.rows, {
      captainId: team.captain_id,
      chip: chipForGameweek(team, gwNumber),
      boostPlayerId: team.boost_player_id,
    });

    // Upsert team_gameweek_scores
    await client.query(`
      INSERT INTO team_gameweek_scores (team_id, gameweek_id, points, captain_id)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (team_id, gameweek_id)
      DO UPDATE SET points = EXCLUDED.points
    `, [team.id, gameweekId, totalPoints, team.captain_id || null]);

    // Update running total on teams table
    await client.query(`
      UPDATE teams SET total_points = (
        SELECT COALESCE(SUM(points), 0) FROM team_gameweek_scores WHERE team_id = $1
      ) WHERE id = $1
    `, [team.id]);
  }

  // Update user total_points = max points across their teams
  await client.query(`
    UPDATE users SET total_points = (
      SELECT COALESCE(SUM(total_points), 0)
      FROM teams WHERE user_id = users.id
    )
  `);

  // Refresh user ranks
  await client.query(`
    UPDATE users u
    SET rank = sub.rn
    FROM (
      SELECT id, ROW_NUMBER() OVER (ORDER BY total_points DESC) AS rn
      FROM users
    ) sub
    WHERE u.id = sub.id
  `);
}

// ─── Cron schedules ──────────────────────────────────────────────────────────

let _jobs = [];

/**
 * Start all cron jobs.
 * Call this from server.js after DB is ready.
 */
function startJobs() {
  if (!process.env.FOOTBALL_DATA_API_KEY) {
    console.warn('[ScoreSync] FOOTBALL_DATA_API_KEY not set — auto-sync disabled.');
    console.warn('[ScoreSync] Register for free at https://www.football-data.org/client/register');
    return;
  }

  // Run every 30 minutes (free cron — no external service)
  const syncJob = cron.schedule('*/30 * * * *', async () => {
    await syncScores();
  }, { timezone: 'Africa/Algiers' });

  // Daily maintenance at 03:00 — mark finished gameweeks
  const maintenanceJob = cron.schedule('0 3 * * *', async () => {
    console.log('[Maintenance] Checking for completed gameweeks…');
    try {
      await pool.query(`
        UPDATE gameweeks
        SET status = 'finished', finished_at = NOW()
        WHERE status = 'active'
          AND deadline < NOW() - INTERVAL '2 days'
      `);
    } catch (err) {
      console.error('[Maintenance] Error:', err.message);
    }
  }, { timezone: 'Africa/Algiers' });

  _jobs = [syncJob, maintenanceJob];
  console.log('⏰ Score sync cron started (every 30 min)');
  console.log('⏰ Maintenance cron started (daily 03:00)');
}

function stopJobs() {
  _jobs.forEach(j => j.stop());
  _jobs = [];
}

// Allow triggering a manual sync from an admin endpoint
module.exports = { startJobs, stopJobs, syncScores, recalcTeamPoints };
