const { pool } = require('../config/db');
const { cacheGet, cacheSet, cacheDel } = require('../config/cache');
const { getIO } = require('../socket/socket');
const { sumTeamGwPoints, chipForGameweek } = require('../utils/scoring');

// ─── Points system — WC 2026 Edition ─────────────────────────────────────────
const POINTS = {
  GK:  { goal: 10, assist: 6, clean_sheet: 6, yellow: -1, red: -3 },
  DEF: { goal: 6,  assist: 3, clean_sheet: 4, yellow: -1, red: -3 },
  MID: { goal: 5,  assist: 3, clean_sheet: 1, yellow: -1, red: -3 },
  FWD: { goal: 4,  assist: 3, clean_sheet: 0, yellow: -1, red: -3 },
  playing_1_to_59min: 1,
  playing_60plus_min: 2,
  // WC Special bonuses
  hat_trick_bonus: 5,       // 3+ goals in one match
  own_goal: -2,             // per own goal
  penalty_save: 5,          // GK saves a penalty
  penalty_miss: -2,         // misses a penalty
  saves_per_3: 1,           // GK: +1 per 3 saves
};

function calcPlayerPoints(score, position) {
  const pts = POINTS[position] || POINTS.MID;
  let total = 0;

  // Playing time
  if (score.minutes_played >= 60) total += POINTS.playing_60plus_min;
  else if (score.minutes_played > 0) total += POINTS.playing_1_to_59min;

  // Goals
  total += score.goals * pts.goal;

  // Hat-trick bonus (3+ goals)
  if (score.goals >= 3) total += POINTS.hat_trick_bonus;

  // Assists
  total += score.assists * pts.assist;

  // Clean sheet
  if (score.clean_sheet && (position === 'GK' || position === 'DEF')) total += pts.clean_sheet;
  if (score.clean_sheet && position === 'MID') total += pts.clean_sheet;

  // Cards
  total += score.yellow_cards * pts.yellow;
  total += score.red_cards * pts.red;

  // WC Specials
  if (score.own_goals)        total += score.own_goals * POINTS.own_goal;
  if (score.penalties_saved)  total += score.penalties_saved * POINTS.penalty_save;
  if (score.penalties_missed) total += score.penalties_missed * POINTS.penalty_miss;

  // GK saves bonus
  if (position === 'GK' && score.saves) {
    total += Math.floor(score.saves / 3) * POINTS.saves_per_3;
  }

  // Manual bonus
  total += score.bonus || 0;

  return Math.max(total, 0);
}

// GET /api/gameweeks
async function getGameweeks(req, res, next) {
  try {
    const result = await pool.query(
      'SELECT * FROM gameweeks ORDER BY number DESC'
    );
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
}

// GET /api/gameweeks/current
async function getCurrentGameweek(req, res, next) {
  try {
    const cacheKey = 'gameweek:current';
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const result = await pool.query(
      `SELECT * FROM gameweeks WHERE status IN ('active', 'upcoming')
       ORDER BY CASE status WHEN 'active' THEN 0 ELSE 1 END, number ASC
       LIMIT 1`
    );

    const gw = result.rows[0] || null;
    if (gw) await cacheSet(cacheKey, gw, 60);
    res.json(gw);
  } catch (err) {
    next(err);
  }
}

// GET /api/gameweeks/:gwId
async function getGameweek(req, res, next) {
  try {
    const { gwId } = req.params;
    const result = await pool.query(
      'SELECT * FROM gameweeks WHERE id = $1',
      [gwId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Gameweek not found' });
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

// POST /api/gameweeks  (admin)
async function createGameweek(req, res, next) {
  try {
    const { number, season, deadline } = req.body;

    const result = await pool.query(
      `INSERT INTO gameweeks (number, season, deadline, status)
       VALUES ($1, $2, $3, 'upcoming') RETURNING *`,
      [number, season || '2025-26', deadline]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

// PATCH /api/gameweeks/:gwId/start
async function startGameweek(req, res, next) {
  try {
    const { gwId } = req.params;

    // Set previous active GW to finished
    await pool.query(
      "UPDATE gameweeks SET status = 'finished', finished_at = NOW() WHERE status = 'active'"
    );

    const result = await pool.query(
      `UPDATE gameweeks SET status = 'active', started_at = NOW()
       WHERE id = $1 RETURNING *`,
      [gwId]
    );

    if (result.rows.length === 0) return res.status(404).json({ error: 'Gameweek not found' });

    await cacheDel('gameweek:current');

    const io = getIO();
    io.emit('gameweek:started', result.rows[0]);

    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

// GET /api/gameweeks/:gwId/scores
async function getGameweekScores(req, res, next) {
  try {
    const { gwId } = req.params;
    const cacheKey = `gw:scores:${gwId}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const result = await pool.query(
      `SELECT ps.*, p.name, p.position, p.club
       FROM player_scores ps
       JOIN players p ON ps.player_id = p.id
       WHERE ps.gameweek_id = $1
       ORDER BY ps.total_points DESC`,
      [gwId]
    );

    await cacheSet(cacheKey, result.rows, 120);
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
}

// POST /api/gameweeks/:gwId/scores  — submit player scores for a GW
async function submitPlayerScores(req, res, next) {
  try {
    const { gwId } = req.params;
    const { scores } = req.body; // [{ playerId, goals, assists, cleanSheet, yellowCards, redCards, minutesPlayed, bonus }]

    if (!Array.isArray(scores) || scores.length === 0) {
      return res.status(400).json({ error: 'scores array required' });
    }

    // Verify gameweek exists and is active
    const gwResult = await pool.query('SELECT * FROM gameweeks WHERE id = $1', [gwId]);
    if (gwResult.rows.length === 0) return res.status(404).json({ error: 'Gameweek not found' });
    if (gwResult.rows[0].status !== 'active') {
      return res.status(400).json({ error: 'Gameweek is not active' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const processed = [];
      for (const s of scores) {
        // Get player position for point calculation
        const playerRes = await client.query('SELECT position FROM players WHERE id = $1', [s.playerId]);
        if (playerRes.rows.length === 0) continue;
        const { position } = playerRes.rows[0];

        const scoreData = {
          goals: s.goals || 0,
          assists: s.assists || 0,
          clean_sheet: s.cleanSheet || false,
          yellow_cards: s.yellowCards || 0,
          red_cards: s.redCards || 0,
          minutes_played: s.minutesPlayed || 0,
          bonus: s.bonus || 0,
          own_goals: s.ownGoals || 0,
          penalties_saved: s.penaltiesSaved || 0,
          penalties_missed: s.penaltiesMissed || 0,
          saves: s.saves || 0,
        };

        const totalPoints = calcPlayerPoints(scoreData, position);

        const inserted = await client.query(
          `INSERT INTO player_scores
             (player_id, gameweek_id, goals, assists, clean_sheet,
              yellow_cards, red_cards, minutes_played, bonus, total_points,
              own_goals, penalties_saved, penalties_missed, saves)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
           ON CONFLICT (player_id, gameweek_id) DO UPDATE SET
             goals=$3, assists=$4, clean_sheet=$5, yellow_cards=$6,
             red_cards=$7, minutes_played=$8, bonus=$9, total_points=$10,
             own_goals=$11, penalties_saved=$12, penalties_missed=$13, saves=$14
           RETURNING *`,
          [s.playerId, gwId, scoreData.goals, scoreData.assists,
           scoreData.clean_sheet, scoreData.yellow_cards, scoreData.red_cards,
           scoreData.minutes_played, scoreData.bonus, totalPoints,
           scoreData.own_goals, scoreData.penalties_saved, scoreData.penalties_missed,
           scoreData.saves]
        );

        // Update player global points & form
        await client.query(
          `UPDATE players SET
             points = points + $1,
             form = ROUND(((form * 4 + $1) / 5)::numeric, 2)
           WHERE id = $2`,
          [totalPoints, s.playerId]
        );

        processed.push(inserted.rows[0]);
      }

      await client.query('COMMIT');
      await cacheDel(`gw:scores:${gwId}`);

      // Emit socket event
      const io = getIO();
      io.emit('gameweek:scores_updated', { gameweekId: gwId, count: processed.length });

      // Trigger team points recalculation
      await recalcTeamPoints(gwId);

      res.status(201).json({
        message: `${processed.length} player scores submitted`,
        scores: processed,
      });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    next(err);
  }
}

// Internal: recalculate all teams' points for a given GW (captain x2/x3 + chips)
async function recalcTeamPoints(gwId) {
  const client = await pool.connect();
  try {
    // Gameweek number — needed to know which teams have a chip armed for it.
    const gwNumRes = await client.query('SELECT number FROM gameweeks WHERE id = $1', [gwId]);
    const gwNumber = gwNumRes.rows[0]?.number;

    // Get all teams with their captain + armed chip
    const teams = await client.query(
      'SELECT id, players, user_id, league_id, captain_id, active_chip, active_chip_gw, boost_player_id FROM teams'
    );

    for (const team of teams.rows) {
      const playerIds = (team.players || []).map(p => p.id);
      if (playerIds.length === 0) continue;

      // Sum points of all team players for this GW
      const scoreRes = await client.query(
        `SELECT player_id, total_points
         FROM player_scores
         WHERE gameweek_id = $1 AND player_id = ANY($2::uuid[])`,
        [gwId, playerIds]
      );

      const gwPoints = sumTeamGwPoints(scoreRes.rows, {
        captainId: team.captain_id,
        chip: chipForGameweek(team, gwNumber),
        boostPlayerId: team.boost_player_id,
      });

      // Upsert team_gameweek_scores
      await client.query(
        `INSERT INTO team_gameweek_scores (team_id, gameweek_id, points, captain_id)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (team_id, gameweek_id) DO UPDATE SET points = $3, captain_id = $4`,
        [team.id, gwId, gwPoints, team.captain_id || null]
      );

      // Update team total points
      await client.query(
        'UPDATE teams SET total_points = total_points + $1 WHERE id = $2',
        [gwPoints, team.id]
      );

      // Update league member points
      await client.query(
        `UPDATE league_members SET points = points + $1
         WHERE league_id = $2 AND user_id = $3`,
        [gwPoints, team.league_id, team.user_id]
      );

      // Update user total_points
      await client.query(
        'UPDATE users SET total_points = total_points + $1 WHERE id = $2',
        [gwPoints, team.user_id]
      );
    }

    // Invalidate leaderboard caches
    await cacheDel('gameweek:current');

    const io = getIO();
    io.emit('gameweek:points_updated', { gameweekId: gwId });
  } catch (err) {
    console.error('Error recalculating team points:', err.message);
  } finally {
    client.release();
  }
}

// GET /api/gameweeks/:gwId/team-scores — classement équipes sur une GW
async function getGameweekTeamScores(req, res, next) {
  try {
    const { gwId } = req.params;

    const result = await pool.query(
      `SELECT tgs.*, t.name as team_name, u.username, u.avatar_url,
        RANK() OVER (ORDER BY tgs.points DESC) as rank
       FROM team_gameweek_scores tgs
       JOIN teams t ON tgs.team_id = t.id
       JOIN users u ON t.user_id = u.id
       WHERE tgs.gameweek_id = $1
       ORDER BY tgs.points DESC`,
      [gwId]
    );

    res.json(result.rows);
  } catch (err) {
    next(err);
  }
}

// GET /api/gameweeks/:gwId/my-breakdown?leagueId= — the caller's own per-player points
async function getMyBreakdown(req, res, next) {
  try {
    const { gwId } = req.params;
    const { leagueId } = req.query;

    const teamRes = await pool.query(
      leagueId
        ? 'SELECT * FROM teams WHERE user_id = $1 AND league_id = $2'
        : 'SELECT * FROM teams WHERE user_id = $1 ORDER BY updated_at DESC LIMIT 1',
      leagueId ? [req.user.id, leagueId] : [req.user.id]
    );
    if (teamRes.rows.length === 0) return res.status(404).json({ error: 'Team not found' });
    const team = teamRes.rows[0];
    const squad = team.players || [];
    if (squad.length === 0) return res.json({ players: [], total: 0, captainId: team.captain_id });

    const playerIds = squad.map((p) => p.id);
    const scoresRes = await pool.query(
      `SELECT ps.player_id, ps.goals, ps.assists, ps.clean_sheet, ps.minutes_played, ps.total_points,
              p.name, p.position, p.photo_url
       FROM player_scores ps JOIN players p ON ps.player_id = p.id
       WHERE ps.gameweek_id = $1 AND ps.player_id = ANY($2::uuid[])`,
      [gwId, playerIds]
    );

    const gwNumRes = await pool.query('SELECT number FROM gameweeks WHERE id = $1', [gwId]);
    const chip = chipForGameweek(team, gwNumRes.rows[0]?.number);

    const scoreMap = {};
    for (const r of scoresRes.rows) scoreMap[r.player_id] = r;

    const players = squad.map((p) => {
      const s = scoreMap[p.id];
      const base = s ? s.total_points : 0;
      const isCaptain = team.captain_id === p.id;
      const isBoost = chip === 'super_sub' && team.boost_player_id === p.id;
      let applied = base;
      if (chip === 'shield' && applied < 0) applied = 0;
      if (isCaptain) applied *= (chip === 'triple_captain' ? 3 : 2);
      else if (isBoost) applied *= 2;
      return {
        id: p.id,
        name: p.name || s?.name,
        position: p.position || s?.position,
        photo_url: p.photo_url || s?.photo_url,
        goals: s?.goals || 0,
        assists: s?.assists || 0,
        clean_sheet: s?.clean_sheet || false,
        minutes_played: s?.minutes_played || 0,
        base_points: base,
        applied_points: applied,
        is_captain: isCaptain,
        is_boost: isBoost,
      };
    });

    const total = sumTeamGwPoints(scoresRes.rows, {
      captainId: team.captain_id, chip, boostPlayerId: team.boost_player_id,
    });

    res.json({ players, total, chip, captainId: team.captain_id });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/gameweeks/:gwId/finish — finalize GW, recalc points, resolve battles
async function finishGameweek(req, res, next) {
  try {
    const { gwId } = req.params;

    const gwRes = await pool.query(
      `UPDATE gameweeks SET status = 'finished', finished_at = NOW()
       WHERE id = $1 AND status = 'active' RETURNING *`,
      [gwId]
    );
    if (gwRes.rows.length === 0) {
      return res.status(400).json({ error: 'Gameweek not found or not active' });
    }
    const gw = gwRes.rows[0];

    // Recalculate all team points for this GW
    await recalcTeamPoints(gwId);

    // Consume chips armed for this gameweek: record them as used and disarm.
    await pool.query(
      `UPDATE teams
       SET chips_used = chips_used || jsonb_build_object('chip', active_chip, 'gameweek', active_chip_gw),
           active_chip = NULL, active_chip_gw = NULL, boost_player_id = NULL
       WHERE active_chip IS NOT NULL AND active_chip_gw = $1`,
      [gw.number]
    );

    // Resolve all battles for this GW number with actual team scores
    const battlesRes = await pool.query(
      `SELECT b.id, b.league_id, b.home_team_id, b.away_team_id
       FROM battles b WHERE b.gameweek = $1 AND b.status != 'completed'`,
      [gw.number]
    );

    const io = getIO();
    for (const battle of battlesRes.rows) {
      const scoresRes = await pool.query(
        `SELECT team_id, points FROM team_gameweek_scores
         WHERE gameweek_id = $1 AND team_id = ANY($2::uuid[])`,
        [gwId, [battle.home_team_id, battle.away_team_id]]
      );

      const ptsMap = {};
      for (const row of scoresRes.rows) ptsMap[row.team_id] = row.points;

      const homeScore = ptsMap[battle.home_team_id] || 0;
      const awayScore = ptsMap[battle.away_team_id] || 0;

      await pool.query(
        `UPDATE battles SET home_score = $1, away_score = $2, status = 'completed', played_at = NOW()
         WHERE id = $3`,
        [homeScore, awayScore, battle.id]
      );

      io.to(`league:${battle.league_id}`).emit('battle:score_update', {
        id: battle.id,
        home_score: homeScore,
        away_score: awayScore,
        status: 'completed',
      });
    }

    await cacheDel('gameweek:current');
    io.emit('gameweek:finished', gw);

    res.json({
      gameweek: gw,
      battlesResolved: battlesRes.rows.length,
    });
  } catch (err) {
    next(err);
  }
}

// POST /api/gameweeks/generate-battles — smart round-robin matchmaking
async function generateBattles(req, res, next) {
  try {
    const { gwId, leagueId } = req.body;
    if (!gwId || !leagueId) return res.status(400).json({ error: 'gwId and leagueId required' });

    // Permission: site admins can generate for any league; otherwise the caller
    // must be the owner of this specific league.
    if (req.user.role !== 'admin') {
      const ownerRes = await pool.query('SELECT owner_id FROM leagues WHERE id = $1', [leagueId]);
      if (ownerRes.rows.length === 0) return res.status(404).json({ error: 'League not found' });
      if (ownerRes.rows[0].owner_id !== req.user.id) {
        return res.status(403).json({ error: 'Only the league owner or an admin can generate battles' });
      }
    }

    const teamsRes = await pool.query(
      'SELECT id FROM teams WHERE league_id = $1',
      [leagueId]
    );
    const teams = teamsRes.rows;
    if (teams.length < 2) return res.status(400).json({ error: 'Need at least 2 teams' });

    const gwRes = await pool.query('SELECT number FROM gameweeks WHERE id = $1', [gwId]);
    const gameweek = gwRes.rows[0]?.number;

    // Get past matchups to avoid repeats when possible
    const pastRes = await pool.query(
      `SELECT home_team_id, away_team_id FROM battles WHERE league_id = $1`,
      [leagueId]
    );
    const played = new Set(pastRes.rows.map(r => [r.home_team_id, r.away_team_id].sort().join(':')));

    // Round-robin rotation: offset by gameweek number
    const n = teams.length;
    const fixed = teams[0];
    const rotating = teams.slice(1);
    const offset = (gameweek - 1) % Math.max(rotating.length, 1);
    const rotated = [...rotating.slice(offset), ...rotating.slice(0, offset)];
    const ordered = [fixed, ...rotated];

    const pairs = [];
    for (let i = 0; i < Math.floor(n / 2); i++) {
      pairs.push([ordered[i], ordered[n - 1 - i]]);
    }

    // If all pairs were already played, fall back to random shuffle
    const allPlayed = pairs.every(([a, b]) => played.has([a.id, b.id].sort().join(':')));
    if (allPlayed) {
      pairs.length = 0;
      const shuffled = [...teams].sort(() => Math.random() - 0.5);
      for (let i = 0; i + 1 < shuffled.length; i += 2) {
        pairs.push([shuffled[i], shuffled[i + 1]]);
      }
    }

    const battles = [];
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      for (const [home, away] of pairs) {
        const battle = await client.query(
          `INSERT INTO battles (league_id, home_team_id, away_team_id, gameweek)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT DO NOTHING
           RETURNING *`,
          [leagueId, home.id, away.id, gameweek]
        );
        if (battle.rows.length > 0) battles.push(battle.rows[0]);
      }
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    const io = getIO();
    io.to(`league:${leagueId}`).emit('battles:generated', { gameweekId: gwId, battles });

    res.status(201).json({ battles, count: battles.length });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getGameweeks,
  getCurrentGameweek,
  getGameweek,
  createGameweek,
  startGameweek,
  finishGameweek,
  getGameweekScores,
  submitPlayerScores,
  getGameweekTeamScores,
  generateBattles,
  recalcTeamPoints,
  getMyBreakdown,
};
