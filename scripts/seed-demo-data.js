/**
 * Seed realistic DEMO data so the Admin dashboard looks populated.
 *
 * Creates ~70 users with transliterated Arabic names, ~15 randomly-named
 * leagues they belong to, a team (real 15-player squad) per membership, plus
 * H2H battles and accepted friendships so every admin KPI is non-zero.
 *
 * Safe + idempotent: every demo user has an email ending in "@fanwc.demo" and
 * re-running first removes the previous demo data (real accounts are untouched).
 *
 *   node scripts/seed-demo-data.js
 *
 * All demo accounts share the password "Demo1234!".
 */

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const { connectDB, pool } = require('../config/db');

// ─── Tunables ────────────────────────────────────────────────────────────────
const USERS = 70;
const LEAGUES = 15;
const FRIENDSHIPS = 60;
const DEMO_DOMAIN = '@fanwc.demo';
const DEMO_PASSWORD = 'Demo1234!';

// ─── Name banks (transliterated Arabic) ──────────────────────────────────────
const FIRST_NAMES = [
  'Mohammed', 'Ahmed', 'Youssef', 'Omar', 'Khalid', 'Ali', 'Hassan', 'Hussein',
  'Ibrahim', 'Yassine', 'Karim', 'Bilal', 'Tariq', 'Anas', 'Zakaria', 'Mehdi',
  'Sami', 'Rachid', 'Nabil', 'Walid', 'Ayoub', 'Hamza', 'Adam', 'Ismail', 'Reda',
  'Salma', 'Yasmine', 'Fatima', 'Aicha', 'Layla', 'Nour', 'Sara', 'Imane', 'Houda',
  'Khadija', 'Maryam', 'Amina', 'Rim', 'Sofia', 'Lina', 'Ghita', 'Hiba',
];
const SURNAMES = [
  'Al-Rashid', 'Al-Fassi', 'Benali', 'El-Idrissi', 'Haddad', 'Belkacem', 'Bennani',
  'El-Amrani', 'Cherkaoui', 'Ouazzani', 'El-Khattabi', 'Bourkadi', 'Tazi', 'Saidi',
  'El-Maghrabi', 'Bensalah', 'Alaoui', 'Berrada', 'El-Ghazali', 'Naciri', 'Sabri',
  'Lahlou', 'Bouazza', 'Hamdi', 'Karimi', 'Mansouri', 'Zniber', 'El-Yousfi', 'Skalli',
  'Tahiri',
];
const LEAGUE_PREFIX = [
  'Atlas Lions', 'Casablanca', 'Marrakech', 'Rabat', 'Riyadh', 'Cairo', 'Doha',
  'Desert Eagles', 'Sahara', 'Maghreb', 'Carthage', 'Pharaohs', 'Falcons',
  'Andalus', 'Medina', 'Oasis', 'Nile', 'Phoenix', 'Amazigh', 'Cedar',
];
const LEAGUE_SUFFIX = [
  'League', 'Champions', 'Cup', 'Stars', 'United', 'Premier', 'Arena', 'Masters',
  'Division', 'Club',
];
const TEAM_ADJ = [
  'Royal', 'Golden', 'Mighty', 'Invincible', 'Rising', 'Thunder', 'Crimson',
  'Emerald', 'Imperial', 'Savage', 'Cosmic', 'Phantom',
];
const TEAM_NOUN = [
  'Eagles', 'Lions', 'Falcons', 'Warriors', 'Titans', 'Wolves', 'Knights',
  'Scorpions', 'Vipers', 'Hawks', 'Stallions', 'Dragons',
];
// Mirrors controllers/challenge.controller.js CHALLENGE_CATALOG (key/type/xp).
const CHALLENGE_CATALOG = [
  { key: 'login_daily', type: 'daily', xp: 5 },
  { key: 'view_news', type: 'daily', xp: 5 },
  { key: 'make_prediction', type: 'daily', xp: 15 },
  { key: 'check_team', type: 'daily', xp: 5 },
  { key: 'browse_players', type: 'daily', xp: 5 },
  { key: 'set_captain', type: 'weekly', xp: 20 },
  { key: 'join_league', type: 'weekly', xp: 30 },
  { key: 'chat_message', type: 'weekly', xp: 10 },
  { key: 'win_battle', type: 'weekly', xp: 50 },
  { key: 'top3_leaderboard', type: 'weekly', xp: 40 },
];
// Mirrors the achievement keys in controllers/auth.controller.js.
const ACHIEVEMENT_KEYS = [
  'first_draft', 'league_creator', 'first_win', 'hat_trick_wins', 'oracle',
  'xp_rookie', 'xp_pro', 'social_butterfly', 'multi_league', 'champion',
];
const PRED_NATIONS = [
  'Morocco', 'France', 'Brazil', 'Argentina', 'Spain', 'Portugal', 'England',
  'Germany', 'Netherlands', 'Belgium',
];
const CHAT_LINES = [
  'Yallah!', 'Bonne chance à tous 🔥', 'Mon équipe est prête', 'Qui prend Haaland cette semaine ?',
  'GG les gars', 'On gagne ce battle inchallah', 'Capitaine = Mbappé', 'Allez !',
  'Belle victoire 👏', 'Faut renforcer la défense', 'Trop fort ce joueur', 'Bonne GW à tous',
];

// ─── Small helpers ───────────────────────────────────────────────────────────
const randInt = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];
function shuffle(a) {
  const r = [...a];
  for (let i = r.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [r[i], r[j]] = [r[j], r[i]];
  }
  return r;
}
const slugify = (s) =>
  s.toLowerCase().replace(/[^a-z0-9]+/g, '.').replace(/\.+/g, '.').replace(/^\.|\.$/g, '');

async function seed() {
  console.log('🌱 Seeding demo data for the admin dashboard...\n');
  await connectDB();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // 1) Remove any prior demo data (battles first — no FK cascade on team refs).
    const like = `%${DEMO_DOMAIN}`;
    await client.query(
      `DELETE FROM battles
        WHERE home_team_id IN (SELECT t.id FROM teams t JOIN users u ON u.id = t.user_id WHERE u.email LIKE $1)
           OR away_team_id IN (SELECT t.id FROM teams t JOIN users u ON u.id = t.user_id WHERE u.email LIKE $1)
           OR league_id    IN (SELECT l.id FROM leagues l JOIN users u ON u.id = l.owner_id WHERE u.email LIKE $1)`,
      [like]
    );
    const cleaned = await client.query(`DELETE FROM users WHERE email LIKE $1`, [like]);
    if (cleaned.rowCount) console.log(`🧹 Removed ${cleaned.rowCount} prior demo users (cascaded their data).`);

    // 2) Load players grouped by position (real IDs reused in squads).
    const pr = await client.query(
      `SELECT id, name, position, price::float AS price, photo_url, club FROM players`
    );
    const byPos = { GK: [], DEF: [], MID: [], FWD: [] };
    for (const p of pr.rows) if (byPos[p.position]) byPos[p.position].push(p);

    const buildSquad = () => {
      const need = { GK: 2, DEF: 5, MID: 5, FWD: 3 };
      const squad = [];
      for (const [pos, n] of Object.entries(need)) {
        for (const p of shuffle(byPos[pos]).slice(0, Math.min(n, byPos[pos].length))) {
          squad.push({ id: p.id, name: p.name, position: p.position, price: p.price, photo_url: p.photo_url, club: p.club });
        }
      }
      return squad;
    };

    // 3) Users — names + points + created_at spread across the last 14 days.
    const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 12);
    const usedUsernames = new Set();
    const users = [];
    for (let i = 0; i < USERS; i++) {
      const fn = pick(FIRST_NAMES);
      const sn = pick(SURNAMES);
      let username = `${fn} ${sn}`;
      if (usedUsernames.has(username.toLowerCase())) username = `${fn} ${sn} ${i}`;
      username = username.slice(0, 50);
      usedUsernames.add(username.toLowerCase());
      const email = `${slugify(`${fn}.${sn}`)}${i}${DEMO_DOMAIN}`;
      const res = await client.query(
        `INSERT INTO users (username, email, password_hash, total_points, created_at, updated_at)
         VALUES ($1, $2, $3, $4, NOW() - make_interval(days => $5, secs => $6), NOW())
         RETURNING id, username`,
        [username, email, passwordHash, randInt(0, 1600), randInt(0, 13), randInt(0, 86399)]
      );
      users.push(res.rows[0]);
    }
    console.log(`👤 Created ${users.length} users.`);

    // Recompute global ranks by total_points.
    await client.query(
      `UPDATE users u SET rank = s.r
         FROM (SELECT id, RANK() OVER (ORDER BY total_points DESC) AS r FROM users) s
        WHERE u.id = s.id`
    );

    // 4+5) Leagues, memberships, teams.
    const usedCodes = new Set();
    const inviteCode = () => {
      let c;
      do { c = crypto.randomBytes(4).toString('hex').toUpperCase(); } while (usedCodes.has(c));
      usedCodes.add(c);
      return c;
    };
    const leagues = [];
    let teamCount = 0;
    for (let i = 0; i < LEAGUES; i++) {
      const owner = pick(users);
      const name = `${pick(LEAGUE_PREFIX)} ${pick(LEAGUE_SUFFIX)}`;
      const maxMembers = randInt(8, 20);
      const lres = await client.query(
        `INSERT INTO leagues (name, owner_id, max_members, is_private, invite_code, season, status, created_at)
         VALUES ($1, $2, $3, $4, $5, 'WC2026', 'active', NOW() - make_interval(days => $6))
         RETURNING id`,
        [name, owner.id, maxMembers, Math.random() < 0.3, inviteCode(), randInt(0, 13)]
      );
      const leagueId = lres.rows[0].id;

      const others = shuffle(users.filter((u) => u.id !== owner.id)).slice(0, randInt(3, Math.min(maxMembers - 1, 12)));
      const members = [owner, ...others];
      const teamIds = [];
      for (const m of members) {
        await client.query(
          `INSERT INTO league_members (league_id, user_id, points) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
          [leagueId, m.id, randInt(0, 500)]
        );
        const squad = buildSquad();
        const spent = squad.reduce((s, p) => s + (p.price || 0), 0);
        const budget = Math.max(0, Math.min(100, Math.round((100 - spent) * 10) / 10));
        const captain = squad.length ? pick(squad).id : null;
        const tres = await client.query(
          `INSERT INTO teams (user_id, league_id, name, budget, formation, captain_id, players, total_points)
           VALUES ($1, $2, $3, $4, '4-3-3', $5, $6, $7) RETURNING id`,
          [m.id, leagueId, `${pick(TEAM_ADJ)} ${pick(TEAM_NOUN)}`, budget, captain, JSON.stringify(squad), randInt(0, 900)]
        );
        teamIds.push(tres.rows[0].id);
        teamCount++;
      }
      leagues.push({ id: leagueId, teamIds, memberIds: members.map((m) => m.id) });
    }
    console.log(`🏆 Created ${leagues.length} leagues and ${teamCount} teams.`);

    // 6) Battles — round-robin-ish pairings across 2–3 fake gameweeks.
    let battleCount = 0;
    for (const lg of leagues) {
      if (lg.teamIds.length < 2) continue;
      const gws = randInt(2, 3);
      for (let gw = 1; gw <= gws; gw++) {
        const order = shuffle(lg.teamIds);
        for (let k = 0; k + 1 < order.length; k += 2) {
          await client.query(
            `INSERT INTO battles (league_id, home_team_id, away_team_id, home_score, away_score, status, gameweek, played_at)
             VALUES ($1, $2, $3, $4, $5, 'completed', $6, NOW() - make_interval(days => $7))`,
            [lg.id, order[k], order[k + 1], randInt(0, 120), randInt(0, 120), gw, randInt(1, 13)]
          );
          battleCount++;
        }
      }
    }
    console.log(`⚔️  Created ${battleCount} battles.`);

    // 7) Friendships — unique accepted pairs.
    let friendCount = 0;
    const seen = new Set();
    for (let attempt = 0; friendCount < FRIENDSHIPS && attempt < FRIENDSHIPS * 6; attempt++) {
      const a = pick(users);
      const b = pick(users);
      if (a.id === b.id) continue;
      const key = [a.id, b.id].sort().join(':');
      if (seen.has(key)) continue;
      seen.add(key);
      await client.query(
        `INSERT INTO friendships (user_id, friend_id, status) VALUES ($1, $2, 'accepted') ON CONFLICT DO NOTHING`,
        [a.id, b.id]
      );
      friendCount++;
    }
    console.log(`🤝 Created ${friendCount} friendships.`);

    // 8) Predictions — 1–3 per user across real gameweeks.
    const gws = (await client.query('SELECT id FROM gameweeks ORDER BY number')).rows;
    const scorers = shuffle([...byPos.FWD, ...byPos.MID]);
    let predCount = 0;
    if (gws.length) {
      for (const u of users) {
        for (const g of shuffle(gws).slice(0, randInt(1, Math.min(3, gws.length)))) {
          const scorer = pick(scorers);
          await client.query(
            `INSERT INTO predictions (user_id, gameweek_id, predicted_top_scorer, predicted_winner_nation, predicted_goals, bonus_points, resolved)
             VALUES ($1, $2, $3, $4, $5, $6, $7) ON CONFLICT DO NOTHING`,
            [u.id, g.id, scorer ? scorer.id : null, pick(PRED_NATIONS), randInt(0, 5), randInt(0, 15), Math.random() < 0.4]
          );
          predCount++;
        }
      }
    }
    console.log(`🔮 Created ${predCount} predictions.`);

    // 9) Challenge completions — 1–5 per user.
    let chalCount = 0;
    for (const u of users) {
      for (const c of shuffle(CHALLENGE_CATALOG).slice(0, randInt(1, 5))) {
        await client.query(
          `INSERT INTO user_challenges (user_id, challenge_key, challenge_type, xp_earned, completed_at)
           VALUES ($1, $2, $3, $4, NOW() - make_interval(days => $5))`,
          [u.id, c.key, c.type, c.xp, randInt(0, 10)]
        );
        chalCount++;
      }
    }
    console.log(`🎯 Created ${chalCount} challenge completions.`);

    // 10) Achievements — 1–4 unique per user.
    let achCount = 0;
    for (const u of users) {
      for (const k of shuffle(ACHIEVEMENT_KEYS).slice(0, randInt(1, 4))) {
        await client.query(
          `INSERT INTO user_achievements (user_id, achievement_key, unlocked_at)
           VALUES ($1, $2, NOW() - make_interval(days => $3)) ON CONFLICT DO NOTHING`,
          [u.id, k, randInt(0, 13)]
        );
        achCount++;
      }
    }
    console.log(`🏅 Created ${achCount} achievements.`);

    // 11) Chat messages — a few per league from its members.
    let chatCount = 0;
    for (const lg of leagues) {
      if (!lg.memberIds.length) continue;
      for (let i = 0, n = randInt(2, 8); i < n; i++) {
        await client.query(
          `INSERT INTO chat_messages (league_id, user_id, message, created_at)
           VALUES ($1, $2, $3, NOW() - make_interval(days => $4, secs => $5))`,
          [lg.id, pick(lg.memberIds), pick(CHAT_LINES), randInt(0, 10), randInt(0, 86399)]
        );
        chatCount++;
      }
    }
    console.log(`💬 Created ${chatCount} chat messages.`);

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    client.release();
    console.error('\n❌ Seed failed (rolled back):', err.message);
    process.exit(1);
  }
  client.release();

  // Summary straight from the DB.
  const totals = await pool.query(`
    SELECT
      (SELECT COUNT(*) FROM users)    AS users,
      (SELECT COUNT(*) FROM leagues)  AS leagues,
      (SELECT COUNT(*) FROM teams)    AS teams,
      (SELECT COUNT(*) FROM battles)  AS battles,
      (SELECT COUNT(*) FROM friendships WHERE status='accepted') AS friendships,
      (SELECT COUNT(*) FROM predictions)        AS predictions,
      (SELECT COUNT(*) FROM user_challenges)    AS challenges,
      (SELECT COUNT(*) FROM user_achievements)  AS achievements,
      (SELECT COUNT(*) FROM chat_messages)      AS chat_messages
  `);
  const t = totals.rows[0];
  console.log('\n📊 Database totals now:');
  console.log('─'.repeat(40));
  console.log(`  users        : ${t.users}`);
  console.log(`  leagues      : ${t.leagues}`);
  console.log(`  teams        : ${t.teams}`);
  console.log(`  battles      : ${t.battles}`);
  console.log(`  friendships  : ${t.friendships}`);
  console.log(`  predictions  : ${t.predictions}`);
  console.log(`  challenges   : ${t.challenges}`);
  console.log(`  achievements : ${t.achievements}`);
  console.log(`  chat_messages: ${t.chat_messages}`);
  console.log('─'.repeat(40));
  console.log(`\n✅ Done. Demo logins: any "*${DEMO_DOMAIN}" / ${DEMO_PASSWORD}\n`);
  process.exit(0);
}

seed();
