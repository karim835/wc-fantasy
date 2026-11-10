/**
 * Import real, current national-team squads from TheSportsDB → players table.
 * Replaces the stale hardcoded 2022 seed with live players + photos + bio
 * (age/height/weight/club/number). Fantasy price/points/form are synthesized
 * (TheSportsDB has no fantasy data).
 *
 * Free TheSportsDB tier returns ~10 players per national team.
 *
 * Usage:
 *   npm run import:squads            # insert/upsert imported players (keeps others)
 *   npm run import:squads -- --replace   # wipe player pool + reset teams, then insert
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const axios = require('axios');
const { connectDB, pool } = require('../config/db');

const KEY = process.env.THESPORTSDB_KEY || '3';
const API = `https://www.thesportsdb.com/api/v1/json/${KEY}`;
const DELAY_MS = 2800;
const REPLACE = process.argv.includes('--replace');

// Exponential backoff (ms) when TheSportsDB rate-limits us (HTTP 429) or a
// transient network error occurs — one entry per retry attempt.
const BACKOFF_MS = [5000, 15000, 40000, 80000];

// The 48 FIFA World Cup 2026 participants (hosts + qualified). Editable.
const NATIONS = [
  'USA', 'Canada', 'Mexico',
  'Argentina', 'Brazil', 'Uruguay', 'Colombia', 'Ecuador', 'Paraguay',
  'France', 'England', 'Spain', 'Portugal', 'Germany', 'Netherlands', 'Belgium',
  'Croatia', 'Italy', 'Switzerland', 'Austria', 'Denmark', 'Norway', 'Scotland', 'Serbia',
  'Morocco', 'Senegal', 'Egypt', 'Algeria', 'Tunisia', 'Ghana', 'Ivory Coast',
  'Nigeria', 'Cameroon', 'South Africa',
  'Japan', 'South Korea', 'Iran', 'Australia', 'Saudi Arabia', 'Qatar', 'Uzbekistan', 'Jordan',
  'New Zealand', 'Panama', 'Costa Rica', 'Honduras', 'Jamaica', 'Curaçao',
];

// TheSportsDB search-name overrides (when the DB nation name != search term).
const SEARCH_NAME = { /* e.g. 'USA': 'United States' — USA works as-is */ };

// Manual fallback squads for nations the free TheSportsDB tier can't resolve
// (it only indexes their club teams, not the national side). Real current
// players; photos resolve at render time via the by-name lookup. Keep ~10.
const MANUAL_SQUADS = {
  Jordan: [
    { name: 'Yazeed Abulaila', position: 'GK', club: 'Al-Wehdat' },
    { name: 'Ehsan Haddad', position: 'DEF', club: 'Al-Hussein' },
    { name: 'Yazan Al-Arab', position: 'DEF', club: 'Al-Faisaly' },
    { name: 'Abdallah Nasib', position: 'DEF', club: 'Al-Wehdat' },
    { name: 'Salem Al-Ajalin', position: 'DEF', club: 'Al-Wehdat' },
    { name: 'Nizar Al-Rashdan', position: 'MID', club: 'Al-Wehdat' },
    { name: 'Noor Al-Rawabdeh', position: 'MID', club: 'Al-Wehdat' },
    { name: 'Mahmoud Al-Mardi', position: 'MID', club: 'Al-Hussein' },
    { name: 'Musa Al-Taamari', position: 'FWD', club: 'Montpellier' },
    { name: 'Yazan Al-Naimat', position: 'FWD', club: 'Al-Ahli' },
    { name: 'Ali Olwan', position: 'FWD', club: 'Zakho' },
  ],
};

// Build a player record from a manual {name,position,club} entry.
function buildManualRecord(p, nation) {
  const { price, points, form } = synthFantasy(null, p.position);
  return {
    name: p.name,
    position: p.position,
    club: p.club || null,
    nationality: nation,
    price, points, form,
    injury_status: null,
    photo_url: null, // resolved at render time by name
    date_of_birth: null,
    height_cm: null,
    weight_kg: null,
    stats: {
      goals: Math.floor(points / 14),
      assists: Math.floor(points / 20),
      clean_sheets: (p.position === 'GK' || p.position === 'DEF') ? Math.floor(points / 22) : 0,
      minutes_played: form > 6 ? 850 : 620,
    },
  };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Run an async TheSportsDB call, retrying with exponential backoff when the
// free tier rate-limits us (429) or a transient network error occurs.
async function withRetry(label, fn) {
  for (let attempt = 0; ; attempt++) {
    try {
      return await fn();
    } catch (err) {
      const status = err.response && err.response.status;
      const retryable = status === 429 || status === 503 || !err.response;
      if (!retryable || attempt >= BACKOFF_MS.length) throw err;
      const wait = BACKOFF_MS[attempt];
      console.log(`      ⏳ ${label} — ${status || err.code || 'network'}; backing off ${wait / 1000}s (retry ${attempt + 1}/${BACKOFF_MS.length})`);
      await sleep(wait);
    }
  }
}

function mapPosition(strPosition) {
  const s = (strPosition || '').toLowerCase();
  if (s.includes('keeper') || s === 'gk') return 'GK';
  if (s.includes('back') || s.includes('defend') || s.includes('centre-back')) return 'DEF';
  if (s.includes('midfield')) return 'MID';
  if (s.includes('wing') || s.includes('forward') || s.includes('striker') || s.includes('attack')) return 'FWD';
  return 'MID';
}

function parseHeightCm(raw) {
  if (!raw) return null;
  const m = String(raw).match(/(\d\.\d{1,2})\s*m/);
  if (m) return Math.round(parseFloat(m[1]) * 100);
  const cm = String(raw).match(/(\d{3})\s*cm/);
  if (cm) return parseInt(cm[1], 10);
  return null;
}
function parseWeightKg(raw) {
  if (!raw) return null;
  const m = String(raw).match(/(\d{2,3})\s*kg/);
  return m ? parseInt(m[1], 10) : null;
}
function parseDob(raw) {
  const m = raw && String(raw).match(/^(\d{4}-\d{2}-\d{2})/);
  return m ? m[1] : null;
}
// "€7.50m" | "€120m" | "Free Transfer" → market value in millions
function parseMarketM(raw) {
  if (!raw) return null;
  const m = String(raw).match(/([\d.]+)\s*m/i);
  return m ? parseFloat(m[1]) : null;
}

function round05(x) { return Math.round(x * 2) / 2; }
function jitter(n) { return Math.floor((Math.random() - 0.5) * 2 * n); }

// Synthesize fantasy values from market value + position.
function synthFantasy(marketM, position) {
  let price;
  if (marketM != null) {
    price = round05(Math.min(13.5, Math.max(4.5, 4.5 + (marketM / 200) * 9)));
  } else {
    const base = position === 'GK' ? 4.5 : position === 'DEF' ? 5.0 : position === 'MID' ? 5.5 : 6.0;
    price = round05(Math.min(11.0, Math.max(4.5, base + Math.random() * 3)));
  }
  const points = Math.min(300, Math.max(70, Math.round(price * 22 + jitter(18))));
  const form = Math.min(9.5, Math.max(5.0, Math.round((5.0 + ((price - 4.5) / 9) * 4.0 + (jitter(8) / 10)) * 10) / 10));
  return { price, points, form };
}

async function findTeamId(nation) {
  const term = SEARCH_NAME[nation] || nation;
  const res = await withRetry(`searchteams ${nation}`, () =>
    axios.get(`${API}/searchteams.php`, { params: { t: term }, timeout: 12000 }));
  const teams = (res.data && res.data.teams) || [];
  const soccer = teams.filter((t) => t.strSport === 'Soccer');
  if (soccer.length === 0) return null;
  const national = soccer.find((t) => /world cup|national/i.test(`${t.strLeague} ${t.strLeague2}`));
  return (national || soccer[0]).idTeam;
}

async function fetchSquad(idTeam) {
  const res = await withRetry(`lookup_all_players ${idTeam}`, () =>
    axios.get(`${API}/lookup_all_players.php`, { params: { id: idTeam }, timeout: 15000 }));
  return (res.data && res.data.player) || [];
}

function buildRecord(p, nation) {
  const position = mapPosition(p.strPosition);
  const { price, points, form } = synthFantasy(parseMarketM(p.strSigning), position);
  return {
    name: p.strPlayer,
    position,
    club: p.strTeam || null,
    nationality: nation,
    price, points, form,
    injury_status: null,
    photo_url: (p.strThumb || p.strCutout || '').trim() || null,
    date_of_birth: parseDob(p.dateBorn),
    height_cm: parseHeightCm(p.strHeight),
    weight_kg: parseWeightKg(p.strWeight),
    stats: {
      goals: Math.floor(points / 14),
      assists: Math.floor(points / 20),
      clean_sheets: (position === 'GK' || position === 'DEF') ? Math.floor(points / 22) : 0,
      minutes_played: form > 6 ? 850 : 620,
    },
  };
}

async function insertPlayer(q, r) {
  await q(
    `INSERT INTO players (name, position, club, nationality, price, points, form, injury_status, stats, photo_url, date_of_birth, height_cm, weight_kg)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
    [r.name, r.position, r.club, r.nationality, r.price, r.points, r.form, r.injury_status,
     JSON.stringify(r.stats), r.photo_url, r.date_of_birth, r.height_cm, r.weight_kg],
  );
}

async function main() {
  await connectDB();

  // In fill mode (no --replace), skip nations that already have players so
  // re-running tops up only the missing ones (resumable after a rate-limit run).
  let targets = NATIONS;
  if (!REPLACE) {
    const existing = await pool.query(
      `SELECT DISTINCT nationality FROM players WHERE nationality IS NOT NULL`);
    const have = new Set(existing.rows.map((r) => r.nationality));
    targets = NATIONS.filter((n) => !have.has(n));
    const skipped = NATIONS.length - targets.length;
    console.log(`[import] fill mode — ${have.size} nations already present, ${skipped} skipped, ${targets.length} to fetch.`);
    if (targets.length === 0) {
      console.log('[import] all nations already present. Nothing to do.');
      await pool.end();
      process.exit(0);
    }
  }

  // 1. Collect squads
  const all = [];
  for (let i = 0; i < targets.length; i++) {
    const nation = targets[i];
    try {
      const idTeam = await findTeamId(nation);
      await sleep(DELAY_MS);
      if (!idTeam) {
        if (MANUAL_SQUADS[nation]) {
          MANUAL_SQUADS[nation].forEach((p) => all.push(buildManualRecord(p, nation)));
          console.log(`  [${i + 1}/${targets.length}] ✓ ${nation} — ${MANUAL_SQUADS[nation].length} players (manual fallback)`);
        } else {
          console.log(`  [${i + 1}/${targets.length}] ✗ ${nation} — no team`);
        }
        continue;
      }
      const squad = await fetchSquad(idTeam);
      await sleep(DELAY_MS);
      const active = squad.filter((p) => p.strPlayer && (!p.strStatus || p.strStatus === 'Active'));
      active.forEach((p) => all.push(buildRecord(p, nation)));
      console.log(`  [${i + 1}/${targets.length}] ✓ ${nation} — ${active.length} players`);
    } catch (err) {
      console.log(`  [${i + 1}/${targets.length}] ! ${nation} — ${err.message}`);
    }
  }

  console.log(`\n[import] collected ${all.length} players from ${targets.length} nations.`);
  if (all.length === 0) { console.log('Nothing imported — aborting.'); await pool.end(); process.exit(1); }

  // 2. Write
  if (REPLACE) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('DELETE FROM player_scores');
      await client.query("UPDATE teams SET players = '[]'::jsonb, captain_id = NULL");
      await client.query('UPDATE predictions SET predicted_top_scorer = NULL').catch(() => {});
      await client.query('DELETE FROM players');
      for (const r of all) await insertPlayer((t, v) => client.query(t, v), r);
      await client.query('COMMIT');
      console.log(`[import] REPLACED player pool with ${all.length} players (teams reset).`);
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  } else {
    let added = 0;
    for (const r of all) {
      const exists = await pool.query('SELECT id FROM players WHERE name = $1', [r.name]);
      if (exists.rows.length === 0) { await insertPlayer((t, v) => pool.query(t, v), r); added++; }
    }
    console.log(`[import] inserted ${added} new players (existing kept; use --replace to rebuild).`);
  }

  const total = await pool.query('SELECT COUNT(*) FROM players');
  console.log(`[import] done. total players in DB: ${total.rows[0].count}`);
  await pool.end();
  process.exit(0);
}

main().catch((err) => { console.error('[import] fatal:', err); process.exit(1); });
