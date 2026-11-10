/**
 * Backfill player photos + bio (age/height/weight) from TheSportsDB.
 *
 * For every player missing data, looks the name up on TheSportsDB and stores
 * photo_url, date_of_birth, height_cm, weight_kg. Free API → throttled and
 * idempotent (skips already-filled rows), so it is safe to re-run / resume.
 *
 * Usage:
 *   npm run backfill:players            # only rows missing photo or DOB
 *   npm run backfill:players -- --force # re-fetch every player
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const axios = require('axios');
const { connectDB, pool } = require('../config/db');

const KEY = process.env.THESPORTSDB_KEY || '3';
const BASE = `https://www.thesportsdb.com/api/v1/json/${KEY}/searchplayers.php`;
const DELAY_MS = 1500; // be gentle with the free tier
const FORCE = process.argv.includes('--force');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// "1.85 m (6 ft 1 in)" | "1.85m" | "185 cm" | "6 ft 1 in" → cm
function parseHeightCm(raw) {
  if (!raw) return null;
  const m = String(raw).match(/(\d\.\d{1,2})\s*m/); // metres
  if (m) return Math.round(parseFloat(m[1]) * 100);
  const cm = String(raw).match(/(\d{3})\s*cm/);
  if (cm) return parseInt(cm[1], 10);
  const ft = String(raw).match(/(\d)\s*ft\s*(\d{1,2})\s*in/); // imperial fallback
  if (ft) return Math.round((parseInt(ft[1], 10) * 12 + parseInt(ft[2], 10)) * 2.54);
  return null;
}

// "78 kg (172 lbs)" | "78kg" → kg
function parseWeightKg(raw) {
  if (!raw) return null;
  const kg = String(raw).match(/(\d{2,3})\s*kg/);
  if (kg) return parseInt(kg[1], 10);
  return null;
}

function parseDob(raw) {
  if (!raw) return null;
  const m = String(raw).match(/^(\d{4}-\d{2}-\d{2})/);
  return m ? m[1] : null;
}

async function lookup(name) {
  const res = await axios.get(BASE, {
    params: { p: name },
    timeout: 10000,
  });
  const players = res.data && res.data.player;
  if (!Array.isArray(players) || players.length === 0) return null;
  // Prefer a soccer match; otherwise first result.
  return players.find((p) => p.strSport === 'Soccer') || players[0];
}

async function main() {
  await connectDB();

  const filter = FORCE ? '' : 'WHERE photo_url IS NULL OR date_of_birth IS NULL';
  const { rows } = await pool.query(
    `SELECT id, name FROM players ${filter} ORDER BY points DESC`
  );

  console.log(`[backfill] ${rows.length} player(s) to process${FORCE ? ' (--force)' : ''}.`);

  let updated = 0;
  let missed = 0;

  for (let i = 0; i < rows.length; i++) {
    const { id, name } = rows[i];
    try {
      const p = await lookup(name);
      if (!p) {
        missed++;
        console.log(`  [${i + 1}/${rows.length}] ✗ ${name} — no match`);
      } else {
        const photo = (p.strThumb || p.strCutout || '').trim() || null;
        const dob = parseDob(p.dateBorn);
        const height = parseHeightCm(p.strHeight);
        const weight = parseWeightKg(p.strWeight);

        // COALESCE keeps any value already present unless --force overwrites.
        await pool.query(
          `UPDATE players SET
             photo_url     = COALESCE($2, photo_url),
             date_of_birth = COALESCE($3::date, date_of_birth),
             height_cm     = COALESCE($4::int, height_cm),
             weight_kg     = COALESCE($5::int, weight_kg),
             updated_at    = NOW()
           WHERE id = $1`,
          [id, photo, dob, height, weight]
        );
        updated++;
        console.log(
          `  [${i + 1}/${rows.length}] ✓ ${name} — photo:${photo ? 'y' : 'n'} dob:${dob || '-'} h:${height || '-'} w:${weight || '-'}`
        );
      }
    } catch (err) {
      missed++;
      console.log(`  [${i + 1}/${rows.length}] ! ${name} — ${err.message}`);
    }
    await sleep(DELAY_MS);
  }

  console.log(`[backfill] done. updated=${updated} missed=${missed}`);
  await pool.end();
  process.exit(0);
}

main().catch((err) => {
  console.error('[backfill] fatal:', err);
  process.exit(1);
});
