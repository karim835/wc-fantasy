/**
 * Simule une gameweek complète:
 * 1. Crée la GW (ou utilise l'existante)
 * 2. Active la GW
 * 3. Génère des scores aléatoires pour tous les joueurs
 * 4. Calcule les points de chaque équipe
 * 5. Génère les battles H2H
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { connectDB, pool } = require('../config/db');

function rand(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function simulatePlayerScore(position) {
  const minutesPlayed = Math.random() > 0.15 ? rand(60, 90) : rand(0, 59);
  if (minutesPlayed === 0) return { goals: 0, assists: 0, cleanSheet: false, yellowCards: 0, redCards: 0, minutesPlayed: 0, bonus: 0 };

  const goals = position === 'GK'  ? 0
              : position === 'DEF' ? (Math.random() > 0.92 ? rand(1, 2) : 0)
              : position === 'MID' ? (Math.random() > 0.75 ? rand(1, 2) : 0)
              : /* FWD */            (Math.random() > 0.5  ? rand(1, 3) : 0);

  const assists = Math.random() > 0.7 ? rand(1, 2) : 0;
  const cleanSheet = (position === 'GK' || position === 'DEF') && Math.random() > 0.6;
  const yellowCards = Math.random() > 0.85 ? 1 : 0;
  const redCards = Math.random() > 0.97 ? 1 : 0;
  const bonus = Math.random() > 0.8 ? rand(1, 3) : 0;

  return { goals, assists, cleanSheet, yellowCards, redCards, minutesPlayed, bonus };
}

function calcPoints(score, position) {
  let pts = 0;
  if (score.minutesPlayed >= 60) pts += 2;
  else if (score.minutesPlayed > 0) pts += 1;

  const goalPts = { GK: 10, DEF: 6, MID: 5, FWD: 4 };
  pts += score.goals * (goalPts[position] || 4);
  pts += score.assists * 3;
  if (score.cleanSheet && (position === 'GK' || position === 'DEF')) pts += position === 'GK' ? 6 : 4;
  if (score.cleanSheet && position === 'MID') pts += 1;
  pts += score.yellowCards * -1;
  pts += score.redCards * -3;
  pts += score.bonus;
  return Math.max(pts, 0);
}

async function run() {
  console.log('\n⚽ Fantasy Sports — Gameweek Simulator\n');
  await connectDB();

  // ── 1. Find or create a gameweek ──────────────────────────────────────
  let gw = null;
  const activeGW = await pool.query("SELECT * FROM gameweeks WHERE status = 'active' LIMIT 1");

  if (activeGW.rows.length > 0) {
    gw = activeGW.rows[0];
    console.log(`📅 Using active GW ${gw.number}`);
  } else {
    // Find next GW number
    const lastGW = await pool.query('SELECT MAX(number) as max FROM gameweeks');
    const nextNumber = (parseInt(lastGW.rows[0].max) || 0) + 1;

    // Set previous GWs to finished
    await pool.query("UPDATE gameweeks SET status = 'finished', finished_at = NOW() WHERE status = 'active'");

    const created = await pool.query(
      `INSERT INTO gameweeks (number, season, status, started_at)
       VALUES ($1, '2025-26', 'active', NOW()) RETURNING *`,
      [nextNumber]
    );
    gw = created.rows[0];
    console.log(`✅ Gameweek ${gw.number} created & activated`);
  }

  // ── 2. Simulate player scores ─────────────────────────────────────────
  const players = await pool.query('SELECT id, position FROM players');
  console.log(`\n🎲 Simulating scores for ${players.rows.length} players...`);

  const client = await pool.connect();
  let processed = 0;
  try {
    await client.query('BEGIN');

    for (const p of players.rows) {
      const score = simulatePlayerScore(p.position);
      const totalPoints = calcPoints(score, p.position);

      await client.query(
        `INSERT INTO player_scores
           (player_id, gameweek_id, goals, assists, clean_sheet,
            yellow_cards, red_cards, minutes_played, bonus, total_points)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
         ON CONFLICT (player_id, gameweek_id) DO UPDATE SET
           goals=$3, assists=$4, clean_sheet=$5, yellow_cards=$6,
           red_cards=$7, minutes_played=$8, bonus=$9, total_points=$10`,
        [p.id, gw.id, score.goals, score.assists, score.cleanSheet,
         score.yellowCards, score.redCards, score.minutesPlayed, score.bonus, totalPoints]
      );

      // Update player form (rolling average)
      await client.query(
        `UPDATE players SET
           form = ROUND(((form * 4 + $1) / 5)::numeric, 2)
         WHERE id = $2`,
        [totalPoints, p.id]
      );

      processed++;
    }

    await client.query('COMMIT');
    console.log(`✅ ${processed} player scores simulated`);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  // ── 3. Recalculate team points ────────────────────────────────────────
  const teams = await pool.query('SELECT id, players, user_id, league_id, name FROM teams');
  console.log(`\n🏆 Calculating points for ${teams.rows.length} teams...`);

  for (const team of teams.rows) {
    const playerIds = (team.players || []).map(p => p.id);
    if (playerIds.length === 0) continue;

    const scoreRes = await pool.query(
      `SELECT COALESCE(SUM(total_points), 0) as gw_points
       FROM player_scores
       WHERE gameweek_id = $1 AND player_id = ANY($2::uuid[])`,
      [gw.id, playerIds]
    );

    const gwPoints = parseInt(scoreRes.rows[0].gw_points);

    await pool.query(
      `INSERT INTO team_gameweek_scores (team_id, gameweek_id, points)
       VALUES ($1, $2, $3)
       ON CONFLICT (team_id, gameweek_id) DO UPDATE SET points = $3`,
      [team.id, gw.id, gwPoints]
    );

    await pool.query(
      'UPDATE teams SET total_points = total_points + $1 WHERE id = $2',
      [gwPoints, team.id]
    );

    await pool.query(
      `UPDATE league_members SET points = points + $1
       WHERE league_id = $2 AND user_id = $3`,
      [gwPoints, team.league_id, team.user_id]
    );

    await pool.query(
      'UPDATE users SET total_points = total_points + $1 WHERE id = $2',
      [gwPoints, team.user_id]
    );

    console.log(`  📊 ${team.name}: +${gwPoints} pts this GW`);
  }

  // ── 4. Generate H2H battles per league ───────────────────────────────
  const leagues = await pool.query("SELECT id, name FROM leagues WHERE status = 'active'");

  if (leagues.rows.length > 0) {
    console.log(`\n⚔️  Generating battles for ${leagues.rows.length} leagues...`);

    for (const league of leagues.rows) {
      const leagueTeams = await pool.query(
        'SELECT id FROM teams WHERE league_id = $1 ORDER BY RANDOM()',
        [league.id]
      );

      const t = leagueTeams.rows;
      const battlesCreated = [];

      for (let i = 0; i + 1 < t.length; i += 2) {
        const existing = await pool.query(
          'SELECT id FROM battles WHERE home_team_id=$1 AND away_team_id=$2 AND gameweek=$3',
          [t[i].id, t[i+1].id, gw.number]
        );
        if (existing.rows.length > 0) continue;

        // Get team GW scores for battle result
        const [homeScore, awayScore] = await Promise.all([
          pool.query('SELECT points FROM team_gameweek_scores WHERE team_id=$1 AND gameweek_id=$2', [t[i].id, gw.id]),
          pool.query('SELECT points FROM team_gameweek_scores WHERE team_id=$1 AND gameweek_id=$2', [t[i+1].id, gw.id]),
        ]);

        const homePoints = homeScore.rows[0]?.points || 0;
        const awayPoints = awayScore.rows[0]?.points || 0;

        const battle = await pool.query(
          `INSERT INTO battles (league_id, home_team_id, away_team_id, gameweek, home_score, away_score, status, played_at)
           VALUES ($1,$2,$3,$4,$5,$6,'finished', NOW()) RETURNING *`,
          [league.id, t[i].id, t[i+1].id, gw.number, homePoints, awayPoints]
        );
        battlesCreated.push(battle.rows[0]);
      }

      if (battlesCreated.length > 0)
        console.log(`  ⚔️  ${league.name}: ${battlesCreated.length} battles generated`);
    }
  }

  // ── 5. Summary ────────────────────────────────────────────────────────
  const topScorers = await pool.query(
    `SELECT p.name, p.position, ps.goals, ps.assists, ps.total_points
     FROM player_scores ps
     JOIN players p ON ps.player_id = p.id
     WHERE ps.gameweek_id = $1
     ORDER BY ps.total_points DESC LIMIT 5`,
    [gw.id]
  );

  console.log(`\n🌟 Top 5 Performers — GW ${gw.number}:`);
  console.log('─'.repeat(55));
  topScorers.rows.forEach((p, i) => {
    const goals = p.goals > 0 ? ` ⚽×${p.goals}` : '';
    const assists = p.assists > 0 ? ` 🎯×${p.assists}` : '';
    console.log(`  ${i + 1}. ${p.name} (${p.position})${goals}${assists} → ${p.total_points} pts`);
  });

  console.log(`\n✅ GW ${gw.number} simulation complete!\n`);
  process.exit(0);
}

run().catch(err => {
  console.error('\n❌ Simulation failed:', err.message);
  process.exit(1);
});
