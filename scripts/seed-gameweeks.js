/**
 * Seed gameweeks (and fixtures) for FIFA World Cup 2026.
 *
 * Usage: npm run seed:gameweeks
 *
 * Strategy:
 *  1. Try to pull the real WC fixture list from football-data.org. If matches
 *     come back, upsert them into `matches` and derive one gameweek per matchday
 *     (deadline = earliest kickoff of that matchday − 1h).
 *  2. If the API has nothing (no key, or the free tier doesn't expose WC 2026),
 *     fall back to a synthetic WC 2026 round calendar so the app still has
 *     working gameweeks + deadlines for the demo.
 *
 * Status rule (both modes): the FIRST round whose deadline is still in the
 * future becomes `active` (so the countdown ticks toward a real lock); earlier
 * rounds are `finished`, later rounds `upcoming`.
 *
 * Idempotent: re-runnable (upserts on (number, season) and fd_match_id).
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const { connectDB, pool } = require('../config/db');
const footballData = require('../services/footballData.service');

const SEASON = '2026';

// Synthetic WC 2026 round calendar (used only when the live API returns nothing).
// Dates follow the real tournament window (Jun 11 – Jul 19, 2026); deadlines at
// 17:00 UTC on the day the round kicks off.
const SYNTHETIC_ROUNDS = [
  { number: 1, label: 'Group Matchday 1',  deadline: '2026-06-11T17:00:00Z' },
  { number: 2, label: 'Group Matchday 2',  deadline: '2026-06-17T17:00:00Z' },
  { number: 3, label: 'Group Matchday 3',  deadline: '2026-06-23T17:00:00Z' },
  { number: 4, label: 'Round of 32',       deadline: '2026-06-28T17:00:00Z' },
  { number: 5, label: 'Round of 16',       deadline: '2026-07-04T17:00:00Z' },
  { number: 6, label: 'Quarter-finals',    deadline: '2026-07-09T17:00:00Z' },
  { number: 7, label: 'Semi-finals',       deadline: '2026-07-14T17:00:00Z' },
  { number: 8, label: 'Final',             deadline: '2026-07-19T17:00:00Z' },
];

// Knockout matches have no `matchday`; map their `stage` onto round numbers so
// the full tournament becomes 8 gameweeks (group MD1-3 + knockout rounds).
const STAGE_TO_ROUND = {
  GROUP_STAGE: null,        // use the match's own matchday (1..3)
  LAST_32: 4,
  ROUND_OF_32: 4,
  LAST_16: 5,
  ROUND_OF_16: 5,
  QUARTER_FINALS: 6,
  QUARTER_FINAL: 6,
  SEMI_FINALS: 7,
  SEMI_FINAL: 7,
  THIRD_PLACE: 8,
  FINAL: 8,
};

function effectiveMatchday(m) {
  const mapped = STAGE_TO_ROUND[m.stage];
  if (mapped) return mapped;
  return m.matchday || 1; // group stage (or unknown) → real matchday
}

/** Pull real WC matches; returns [] on any failure (no key / not on free tier). */
async function loadRealMatches() {
  if (!process.env.FOOTBALL_DATA_API_KEY) {
    console.log('ℹ️  FOOTBALL_DATA_API_KEY not set — using synthetic calendar.');
    return [];
  }
  try {
    const matches = await footballData.getAllMatches();
    console.log(`✓ football-data.org returned ${matches.length} WC matches.`);
    return matches;
  } catch (err) {
    const code = err.response?.status;
    console.log(`ℹ️  Could not load live WC fixtures (${code || err.message}) — using synthetic calendar.`);
    return [];
  }
}

/** Compute status for each round given its deadline: first future round = active. */
function assignStatuses(rounds) {
  const now = Date.now();
  const firstFutureIdx = rounds.findIndex((r) => new Date(r.deadline).getTime() >= now);
  return rounds.map((r, i) => ({
    ...r,
    status: firstFutureIdx === -1
      ? (i === rounds.length - 1 ? 'active' : 'finished')   // tournament over → last is active
      : i < firstFutureIdx ? 'finished'
      : i === firstFutureIdx ? 'active'
      : 'upcoming',
  }));
}

async function upsertGameweek(client, round) {
  const { rows } = await client.query(
    `INSERT INTO gameweeks (number, season, deadline, status)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (number, season)
     DO UPDATE SET deadline = EXCLUDED.deadline, status = EXCLUDED.status
     RETURNING id`,
    [round.number, SEASON, round.deadline, round.status]
  );
  return rows[0].id;
}

async function upsertMatch(client, m, gameweekId) {
  const r = footballData.mapMatchResult(m);
  await client.query(
    `INSERT INTO matches
       (fd_match_id, matchday, home_team, away_team, home_goals, away_goals, status, kickoff, gameweek_id, updated_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9, NOW())
     ON CONFLICT (fd_match_id) DO UPDATE SET
       matchday = EXCLUDED.matchday,
       home_team = EXCLUDED.home_team,
       away_team = EXCLUDED.away_team,
       home_goals = EXCLUDED.home_goals,
       away_goals = EXCLUDED.away_goals,
       status = EXCLUDED.status,
       kickoff = EXCLUDED.kickoff,
       gameweek_id = EXCLUDED.gameweek_id,
       updated_at = NOW()`,
    [r.matchId, r.matchday, r.homeTeam, r.awayTeam, r.homeGoals, r.awayGoals, m.status, m.utcDate || null, gameweekId]
  );
}

async function run() {
  await connectDB();
  const client = await pool.connect();
  try {
    const matches = await loadRealMatches();

    let rounds;
    let byMatchday = {};

    if (matches.length) {
      // Group by matchday, deadline = earliest kickoff − 1h.
      for (const m of matches) {
        const md = effectiveMatchday(m);
        (byMatchday[md] ||= []).push(m);
      }
      rounds = Object.keys(byMatchday)
        .map(Number)
        .sort((a, b) => a - b)
        .map((md) => {
          const kickoffs = byMatchday[md]
            .map((m) => new Date(m.utcDate).getTime())
            .filter((t) => !Number.isNaN(t));
          const earliest = kickoffs.length ? Math.min(...kickoffs) : Date.now();
          return { number: md, deadline: new Date(earliest - 3600 * 1000).toISOString() };
        });
    } else {
      rounds = SYNTHETIC_ROUNDS.map((r) => ({ number: r.number, deadline: r.deadline }));
    }

    rounds = assignStatuses(rounds);

    await client.query('BEGIN');
    let gwCount = 0;
    let matchCount = 0;
    for (const round of rounds) {
      const gwId = await upsertGameweek(client, round);
      gwCount++;
      for (const m of (byMatchday[round.number] || [])) {
        await upsertMatch(client, m, gwId);
        matchCount++;
      }
    }
    await client.query('COMMIT');

    const active = rounds.find((r) => r.status === 'active');
    console.log(`\n✅ Seeded ${gwCount} gameweeks, ${matchCount} matches (season ${SEASON}).`);
    if (active) {
      console.log(`   Active: GW${active.number} — deadline ${active.deadline}`);
    }
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    console.error('❌ seed-gameweeks failed:', err.message);
    process.exitCode = 1;
  } finally {
    client.release();
    await pool.end();
  }
}

run();
