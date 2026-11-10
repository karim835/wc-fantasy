/**
 * Daily Challenges — WC 2026
 * Défis quotidiens/hebdomadaires pour booster l'engagement.
 * Les défis sont automatiquement réinitialisés chaque jour à minuit UTC.
 */

const { pool } = require('../config/db');
const { cacheGet, cacheSet, cacheDel } = require('../config/cache');

// Catalogue de défis (statiques)
const CHALLENGE_CATALOG = [
  // Daily
  { key: 'login_daily',      type: 'daily',   title: 'Connexion du jour',       description: 'Connecte-toi à l\'app',                     xp: 5,  icon: 'login' },
  { key: 'view_news',        type: 'daily',   title: 'Lire les news',           description: 'Consulte la section actualités',            xp: 5,  icon: 'newspaper' },
  { key: 'make_prediction',  type: 'daily',   title: 'Prédis le résultat',      description: 'Soumets une prédiction pour la GW',         xp: 15, icon: 'lightbulb' },
  { key: 'check_team',       type: 'daily',   title: 'Vérifie ton équipe',      description: 'Consulte ta composition d\'équipe',         xp: 5,  icon: 'people' },
  { key: 'browse_players',   type: 'daily',   title: 'Explore les joueurs',     description: 'Consulte la liste des joueurs WC',          xp: 5,  icon: 'sports_soccer' },
  // Weekly
  { key: 'set_captain',      type: 'weekly',  title: 'Choisis ton capitaine',   description: 'Définis un capitaine pour la semaine',      xp: 20, icon: 'star' },
  { key: 'join_league',      type: 'weekly',  title: 'Rejoins une ligue',       description: 'Rejoins ou crée une nouvelle ligue',        xp: 30, icon: 'emoji_events' },
  { key: 'chat_message',     type: 'weekly',  title: 'Participe au chat',       description: 'Envoie un message dans ta ligue',          xp: 10, icon: 'chat' },
  { key: 'win_battle',       type: 'weekly',  title: 'Gagne un battle',         description: 'Termine une semaine avec plus de points que ton adversaire', xp: 50, icon: 'military_tech' },
  { key: 'top3_leaderboard', type: 'weekly',  title: 'Top 3 du classement',     description: 'Finit dans le top 3 d\'une ligue sur la GW', xp: 40, icon: 'leaderboard' },
];

// GET /api/challenges — défis du jour + statut de complétion
async function getChallenges(req, res, next) {
  try {
    const userId = req.user.id;
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    const weekStart = _getWeekStart();

    // Get user's completed challenges
    const completedRes = await pool.query(
      `SELECT challenge_key, completed_at FROM user_challenges
       WHERE user_id = $1 AND (
         (challenge_type = 'daily'  AND DATE(completed_at) = $2) OR
         (challenge_type = 'weekly' AND completed_at >= $3)
       )`,
      [userId, today, weekStart]
    );

    const completedMap = {};
    for (const row of completedRes.rows) {
      completedMap[row.challenge_key] = row.completed_at;
    }

    // Get total XP
    const xpRes = await pool.query(
      'SELECT COALESCE(SUM(xp_earned), 0) as total_xp FROM user_challenges WHERE user_id = $1',
      [userId]
    );

    const challenges = CHALLENGE_CATALOG.map(c => ({
      ...c,
      completed: !!completedMap[c.key],
      completedAt: completedMap[c.key] || null,
    }));

    const daily = challenges.filter(c => c.type === 'daily');
    const weekly = challenges.filter(c => c.type === 'weekly');

    const dailyDone = daily.filter(c => c.completed).length;
    const weeklyDone = weekly.filter(c => c.completed).length;

    res.json({
      daily,
      weekly,
      summary: {
        daily_done: dailyDone,
        daily_total: daily.length,
        weekly_done: weeklyDone,
        weekly_total: weekly.length,
        total_xp: parseInt(xpRes.rows[0].total_xp),
        level: _calcLevel(parseInt(xpRes.rows[0].total_xp)),
      },
    });
  } catch (err) {
    next(err);
  }
}

// POST /api/challenges/complete — marquer un défi comme complété
async function completeChallenge(req, res, next) {
  try {
    const { challengeKey } = req.body;
    const userId = req.user.id;

    const challenge = CHALLENGE_CATALOG.find(c => c.key === challengeKey);
    if (!challenge) return res.status(404).json({ error: 'Challenge not found' });

    const today = new Date().toISOString().split('T')[0];
    const weekStart = _getWeekStart();

    // Check already completed
    const existingRes = await pool.query(
      `SELECT id FROM user_challenges
       WHERE user_id = $1 AND challenge_key = $2 AND (
         (challenge_type = 'daily'  AND DATE(completed_at) = $3) OR
         (challenge_type = 'weekly' AND completed_at >= $4)
       )`,
      [userId, challengeKey, today, weekStart]
    );

    if (existingRes.rows.length > 0) {
      return res.status(409).json({ error: 'Already completed', alreadyDone: true });
    }

    // Insert completion
    await pool.query(
      `INSERT INTO user_challenges (user_id, challenge_key, challenge_type, xp_earned)
       VALUES ($1, $2, $3, $4)`,
      [userId, challengeKey, challenge.type, challenge.xp]
    );

    // Award XP as bonus points to user
    await pool.query(
      'UPDATE users SET total_points = total_points + $1 WHERE id = $2',
      [challenge.xp, userId]
    );

    const xpRes = await pool.query(
      'SELECT COALESCE(SUM(xp_earned), 0) as total_xp FROM user_challenges WHERE user_id = $1',
      [userId]
    );
    const totalXp = parseInt(xpRes.rows[0].total_xp);

    res.json({
      message: `Défi "${challenge.title}" complété ! +${challenge.xp} XP`,
      xp_earned: challenge.xp,
      total_xp: totalXp,
      level: _calcLevel(totalXp),
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/challenges/leaderboard — top joueurs par XP
async function getChallengeLeaderboard(req, res, next) {
  try {
    const result = await pool.query(
      `SELECT u.id, u.username, u.avatar_url,
              COALESCE(SUM(uc.xp_earned), 0) as total_xp,
              COUNT(uc.id) as challenges_done
       FROM users u
       LEFT JOIN user_challenges uc ON uc.user_id = u.id
       GROUP BY u.id, u.username, u.avatar_url
       ORDER BY total_xp DESC
       LIMIT 20`
    );
    res.json(result.rows.map((r, i) => ({
      ...r,
      total_xp: parseInt(r.total_xp),
      challenges_done: parseInt(r.challenges_done),
      rank: i + 1,
      level: _calcLevel(parseInt(r.total_xp)),
    })));
  } catch (err) {
    next(err);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function _getWeekStart() {
  const now = new Date();
  const day = now.getDay(); // 0=Sun
  const diff = now.getDate() - day + (day === 0 ? -6 : 1); // Monday
  const monday = new Date(now.setDate(diff));
  monday.setHours(0, 0, 0, 0);
  return monday.toISOString();
}

function _calcLevel(xp) {
  if (xp < 50)  return { number: 1, title: 'Rookie',     next: 50 };
  if (xp < 150) return { number: 2, title: 'Amateur',    next: 150 };
  if (xp < 350) return { number: 3, title: 'Semi-Pro',   next: 350 };
  if (xp < 700) return { number: 4, title: 'Pro',        next: 700 };
  if (xp < 1200) return { number: 5, title: 'Expert',    next: 1200 };
  return         { number: 6, title: 'Légende WC',        next: null };
}

module.exports = { getChallenges, completeChallenge, getChallengeLeaderboard };
