/**
 * Seed a "perfect" demo account: Ayoub BK.
 *
 * Creates a star user who is #1 overall, tops every league he's in, owns a
 * stacked best-players squad, and has won lots of H2H battles — plus enough
 * predictions / XP / chat to unlock the profile achievements.
 *
 * Self-contained + idempotent: this user and his supporting cast use the
 * "@star.demo" email tag, so the regular `seed-demo-data.js` (which only touches
 * "@fanwc.demo") never disturbs him, and re-running this script replaces his
 * data cleanly.
 *
 *   node scripts/seed-star-user.js
 *
 * LOGIN →  email: ayoub.bk@star.demo   password: Ayoub1234!
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { connectDB, pool } = require('../config/db');

const STAR_EMAIL = 'ayoub.bk@star.demo';
const STAR_PASSWORD = 'Ayoub1234!';
const STAR_TAG = '%@star.demo';

const MATE_FIRST = ['Omar', 'Khalid', 'Yassine', 'Hamza', 'Bilal', 'Anas', 'Reda', 'Mehdi', 'Tariq', 'Sami'];
const MATE_LAST = ['Benali', 'El-Fassi', 'Haddad', 'Cherkaoui', 'Alaoui', 'Bennani', 'Saidi', 'Naciri', 'Tazi', 'Berrada'];
const LEAGUE_NAMES = ['Atlas Elite', 'Champions Arena', 'Desert Kings'];
const CHALLENGE_CATALOG = [
  { key: 'login_daily', type: 'daily', xp: 5 }, { key: 'view_news', type: 'daily', xp: 5 },
  { key: 'make_prediction', type: 'daily', xp: 15 }, { key: 'check_team', type: 'daily', xp: 5 },
  { key: 'browse_players', type: 'daily', xp: 5 }, { key: 'set_captain', type: 'weekly', xp: 20 },
  { key: 'join_league', type: 'weekly', xp: 30 }, { key: 'chat_message', type: 'weekly', xp: 10 },
  { key: 'win_battle', type: 'weekly', xp: 50 }, { key: 'top3_leaderboard', type: 'weekly', xp: 40 },
];
const ACHIEVEMENT_KEYS = ['first_draft', 'league_creator', 'first_win', 'hat_trick_wins', 'oracle', 'xp_rookie', 'xp_pro', 'social_butterfly', 'multi_league'];
const CHAT_LINES = ['Yallah on gagne 🔥', 'GG', 'Capitaine = Mbappé', 'Bonne GW', 'Trop facile 😎', 'Allez les gars', 'Top du classement 🏆', 'Belle équipe', 'On lâche rien', 'Inchallah la victoire', 'Mon attaque est létale', 'Respect à tous'];
const PRED_NATIONS = ['Morocco', 'France', 'Brazil', 'Argentina', 'Spain'];

const randInt = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
const pick = (a) => a[Math.floor(Math.random() * a.length)];
function shuffle(a) { const r = [...a]; for (let i = r.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [r[i], r[j]] = [r[j], r[i]]; } return r; }

async function seed() {
  console.log('⭐ Seeding the perfect demo account (Ayoub BK)...\n');
  await connectDB();
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // 1) Clean prior star data (battles first — no FK cascade on team refs).
    await client.query(
      `DELETE FROM battles
        WHERE home_team_id IN (SELECT t.id FROM teams t JOIN users u ON u.id=t.user_id WHERE u.email LIKE $1)
           OR away_team_id IN (SELECT t.id FROM teams t JOIN users u ON u.id=t.user_id WHERE u.email LIKE $1)
           OR league_id    IN (SELECT l.id FROM leagues l JOIN users u ON u.id=l.owner_id WHERE u.email LIKE $1)`,
      [STAR_TAG]
    );
    await client.query(`DELETE FROM users WHERE email LIKE $1`, [STAR_TAG]);

    // 2) Best squad: prefer recognizable superstars (matched by name), then top
    //    the best players we actually have, kept WITHIN the 100 budget.
    const need = { GK: 2, DEF: 5, MID: 5, FWD: 3 };
    const BUDGET = 100;
    const allByPos = { GK: [], DEF: [], MID: [], FWD: [] };
    for (const p of (await client.query(`SELECT id, name, position, price::float AS price, photo_url, club, points FROM players`)).rows) {
      if (allByPos[p.position]) allByPos[p.position].push(p);
    }
    const snap = (p) => ({ id: p.id, name: p.name, position: p.position, price: p.price, photo_url: p.photo_url, club: p.club });

    // Strongest legal squad ≤ budget: start from the cheapest valid XV, then
    // greedily swap in the biggest points upgrade that still fits the budget.
    const picks = {};
    let spent = 0;
    for (const [pos, n] of Object.entries(need)) {
      picks[pos] = [...allByPos[pos]].sort((a, b) => a.price - b.price).slice(0, n);
      spent += picks[pos].reduce((s, p) => s + p.price, 0);
    }
    for (let guard = 0, improved = true; improved && guard < 1000; ) {
      improved = false;
      let best = null;
      for (const [pos, arr] of Object.entries(picks)) {
        const chosen = new Set(arr.map((p) => p.id));
        for (const cand of allByPos[pos]) {
          if (chosen.has(cand.id)) continue;
          for (let i = 0; i < arr.length; i++) {
            const extra = cand.price - arr[i].price;
            const gain = cand.points - arr[i].points;
            if (gain > 0 && spent + extra <= BUDGET && (!best || gain > best.gain)) {
              best = { pos, i, cand, extra, gain };
            }
          }
        }
      }
      if (best) { picks[best.pos][best.i] = best.cand; spent += best.extra; improved = true; guard++; }
    }
    const bestSquad = [...picks.GK, ...picks.DEF, ...picks.MID, ...picks.FWD];
    const captain = bestSquad.slice().sort((a, b) => b.points - a.points)[0];

    const randomSquad = () => {
      const s = [];
      for (const [pos, n] of Object.entries(need)) for (const p of shuffle(allByPos[pos]).slice(0, n)) s.push(p);
      return s;
    };

    const hash = await bcrypt.hash(STAR_PASSWORD, 12);

    // 3) Ayoub — #1 overall.
    const ayoub = (await client.query(
      `INSERT INTO users (username, email, password_hash, total_points, created_at, updated_at)
       VALUES ('Ayoub BK', $1, $2, 2600, NOW() - make_interval(days => 13), NOW()) RETURNING id`,
      [STAR_EMAIL, hash]
    )).rows[0];

    // 4) Supporting cast (8 teammates).
    const mates = [];
    for (let i = 0; i < 8; i++) {
      const email = `mate${i}.${Date.now().toString(36)}@star.demo`;
      const m = (await client.query(
        `INSERT INTO users (username, email, password_hash, total_points, created_at, updated_at)
         VALUES ($1, $2, $3, $4, NOW() - make_interval(days => $5), NOW()) RETURNING id`,
        [`${pick(MATE_FIRST)} ${pick(MATE_LAST)} ${i}`, email, hash, randInt(300, 1400), randInt(0, 13)]
      )).rows[0];
      mates.push(m.id);
    }

    // 5) Three leagues owned by Ayoub — he's top member in each.
    const usedCodes = new Set();
    const code = () => { let c; do { c = crypto.randomBytes(4).toString('hex').toUpperCase(); } while (usedCodes.has(c)); usedCodes.add(c); return c; };
    let totalWins = 0, battleCount = 0, teamCount = 0;

    for (let li = 0; li < LEAGUE_NAMES.length; li++) {
      const league = (await client.query(
        `INSERT INTO leagues (name, owner_id, max_members, is_private, invite_code, season, status, created_at)
         VALUES ($1, $2, 20, false, $3, 'WC2026', 'active', NOW() - make_interval(days => 12)) RETURNING id`,
        [LEAGUE_NAMES[li], ayoub.id, code()]
      )).rows[0];

      // Ayoub's team — the stacked squad, highest points.
      const aSpent = bestSquad.reduce((s, p) => s + (p.price || 0), 0);
      const ayoubTeam = (await client.query(
        `INSERT INTO teams (user_id, league_id, name, budget, formation, captain_id, players, total_points)
         VALUES ($1, $2, 'Atlas Galacticos', $3, '4-3-3', $4, $5, $6) RETURNING id`,
        [ayoub.id, league.id, Math.max(0, Math.round((100 - aSpent) * 10) / 10), captain.id, JSON.stringify(bestSquad.map(snap)), randInt(1400, 1800)]
      )).rows[0];
      teamCount++;
      await client.query(
        `INSERT INTO league_members (league_id, user_id, points) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
        [league.id, ayoub.id, randInt(1400, 1700)] // top of the table
      );

      // Teammates (6 random of the 8) with weaker teams + lower points.
      const roster = shuffle(mates).slice(0, 6);
      const oppTeams = [];
      for (const mid of roster) {
        await client.query(
          `INSERT INTO league_members (league_id, user_id, points) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
          [league.id, mid, randInt(100, 900)]
        );
        const sq = randomSquad();
        const ot = (await client.query(
          `INSERT INTO teams (user_id, league_id, name, budget, formation, captain_id, players, total_points)
           VALUES ($1, $2, $3, 5, '4-3-3', $4, $5, $6) RETURNING id`,
          [mid, league.id, `${pick(MATE_LAST)} FC`, sq.length ? pick(sq).id : null, JSON.stringify(sq.map(snap)), randInt(200, 1000)]
        )).rows[0];
        oppTeams.push(ot.id);
        teamCount++;
      }

      // Battles: Ayoub (home) vs each teammate over 2 gameweeks — wins almost all.
      for (let gw = 1; gw <= 2; gw++) {
        for (const ot of oppTeams) {
          const ayoubWins = Math.random() < 0.85;
          const hs = ayoubWins ? randInt(70, 120) : randInt(30, 50);
          const as = ayoubWins ? randInt(20, 55) : randInt(60, 95);
          await client.query(
            `INSERT INTO battles (league_id, home_team_id, away_team_id, home_score, away_score, status, gameweek, played_at)
             VALUES ($1, $2, $3, $4, $5, 'completed', $6, NOW() - make_interval(days => $7))`,
            [league.id, ayoubTeam.id, ot, hs, as, gw, randInt(1, 12)]
          );
          if (hs > as) totalWins++;
          battleCount++;
        }
      }
    }

    // 6) Predictions (oracle: >=3 correct), challenges (xp_pro: >=350 XP), chat (social_butterfly: >=10).
    const gws = (await client.query('SELECT id FROM gameweeks ORDER BY number LIMIT 6')).rows;
    const topFwd = bestSquad.find((p) => p.position === 'FWD') || bestSquad[0];
    let predCount = 0;
    for (const g of gws) {
      await client.query(
        `INSERT INTO predictions (user_id, gameweek_id, predicted_top_scorer, predicted_winner_nation, predicted_goals, bonus_points, resolved)
         VALUES ($1, $2, $3, $4, $5, $6, true) ON CONFLICT DO NOTHING`,
        [ayoub.id, g.id, topFwd.id, pick(PRED_NATIONS), randInt(2, 5), randInt(5, 15)]
      );
      predCount++;
    }
    // Challenges twice over → ~370 XP (>350 for xp_pro).
    for (let rep = 0; rep < 2; rep++) {
      for (const c of CHALLENGE_CATALOG) {
        await client.query(
          `INSERT INTO user_challenges (user_id, challenge_key, challenge_type, xp_earned, completed_at)
           VALUES ($1, $2, $3, $4, NOW() - make_interval(days => $5))`,
          [ayoub.id, c.key, c.type, c.xp, randInt(0, 10)]
        );
      }
    }
    for (const k of ACHIEVEMENT_KEYS) {
      await client.query(
        `INSERT INTO user_achievements (user_id, achievement_key, unlocked_at) VALUES ($1, $2, NOW()) ON CONFLICT DO NOTHING`,
        [ayoub.id, k]
      );
    }
    let chatCount = 0;
    const myLeagues = (await client.query('SELECT id FROM leagues WHERE owner_id = $1', [ayoub.id])).rows;
    for (let i = 0; i < 14; i++) {
      await client.query(
        `INSERT INTO chat_messages (league_id, user_id, message, created_at)
         VALUES ($1, $2, $3, NOW() - make_interval(days => $4, secs => $5))`,
        [pick(myLeagues).id, ayoub.id, pick(CHAT_LINES), randInt(0, 10), randInt(0, 86399)]
      );
      chatCount++;
    }

    // 7) Recompute global ranks (Ayoub at 2600 lands #1).
    await client.query(
      `UPDATE users u SET rank = s.r FROM (SELECT id, RANK() OVER (ORDER BY total_points DESC) AS r FROM users) s WHERE u.id = s.id`
    );

    await client.query('COMMIT');

    const rank = (await pool.query('SELECT rank FROM users WHERE id = $1', [ayoub.id])).rows[0].rank;
    console.log('✅ Created Ayoub BK');
    console.log('─'.repeat(46));
    console.log(`  global rank      : #${rank}  (2600 pts)`);
    console.log(`  leagues (top of) : ${LEAGUE_NAMES.length}`);
    console.log(`  teams            : ${teamCount} (his: stacked best-XI)`);
    console.log(`  battles          : ${battleCount}  |  WON: ${totalWins}`);
    console.log(`  predictions      : ${predCount} (all correct → Oracle)`);
    console.log(`  XP               : ~370 (challenges ×2 → XP Pro)`);
    console.log(`  chat messages    : ${chatCount} (→ Social Butterfly)`);
    console.log('─'.repeat(46));
    console.log(`\n  ⭐ LOGIN  email: ${STAR_EMAIL}   password: ${STAR_PASSWORD}\n`);
    process.exit(0);
  } catch (err) {
    await client.query('ROLLBACK');
    client.release();
    console.error('\n❌ Failed (rolled back):', err.message);
    process.exit(1);
  }
}

seed();
