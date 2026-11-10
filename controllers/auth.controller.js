const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');
const { cacheDel } = require('../config/cache');
const { sendPasswordResetEmail } = require('../services/emailService');

const AVATAR_DIR = path.join(__dirname, '..', 'uploads', 'avatars');
const AVATAR_EXTS = ['jpg', 'jpeg', 'png', 'webp'];

function generateTokens(userId) {
  const accessToken = jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
  const refreshToken = jwt.sign({ userId }, process.env.JWT_REFRESH_SECRET, {
    expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  });
  return { accessToken, refreshToken };
}

async function register(req, res, next) {
  try {
    const { username, email, password, date_of_birth, country, favorite_nation, favorite_club, favorite_player, bio } = req.body;

    const existing = await pool.query(
      'SELECT id FROM users WHERE email = $1 OR username = $2',
      [email, username]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email or username already taken' });
    }

    const passwordHash = await bcrypt.hash(password, 12);
    const result = await pool.query(
      `INSERT INTO users (username, email, password_hash, date_of_birth, country, favorite_nation, favorite_club, favorite_player, bio)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, username, email, avatar_url, total_points, date_of_birth, country, favorite_nation, favorite_club, favorite_player, bio, created_at`,
      [username, email, passwordHash, date_of_birth || null, country || null, favorite_nation || null, favorite_club || null, favorite_player || null, bio || null]
    );

    const user = result.rows[0];
    const { accessToken, refreshToken } = generateTokens(user.id);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);
    await pool.query(
      'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
      [user.id, refreshToken, expiresAt]
    );

    res.status(201).json({ user, accessToken, refreshToken });
  } catch (err) {
    next(err);
  }
}

async function login(req, res, next) {
  try {
    const { email, password } = req.body;

    const result = await pool.query(
      `SELECT id, username, email, password_hash, avatar_url, total_points, role,
              date_of_birth, country, favorite_nation, favorite_club, favorite_player, bio
       FROM users WHERE email = $1`,
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const user = result.rows[0];
    const isValid = await bcrypt.compare(password, user.password_hash);
    if (!isValid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const { accessToken, refreshToken } = generateTokens(user.id);
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);
    await pool.query(
      'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
      [user.id, refreshToken, expiresAt]
    );

    delete user.password_hash;
    res.json({ user, accessToken, refreshToken });
  } catch (err) {
    next(err);
  }
}

async function refresh(req, res, next) {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ error: 'Refresh token required' });

    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);

    const result = await pool.query(
      'SELECT id FROM refresh_tokens WHERE token = $1 AND user_id = $2 AND expires_at > NOW()',
      [refreshToken, decoded.userId]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid or expired refresh token' });
    }

    const tokens = generateTokens(decoded.userId);
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);

    await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [refreshToken]);
    await pool.query(
      'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
      [decoded.userId, tokens.refreshToken, expiresAt]
    );

    res.json(tokens);
  } catch (err) {
    if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }
    next(err);
  }
}

async function logout(req, res, next) {
  try {
    const { refreshToken } = req.body;
    if (refreshToken) {
      await pool.query('DELETE FROM refresh_tokens WHERE token = $1', [refreshToken]);
    }
    res.json({ message: 'Logged out successfully' });
  } catch (err) {
    next(err);
  }
}

async function getProfile(req, res) {
  res.json({ user: req.user });
}

// GET /api/auth/stats — full profile stats for profile screen
async function getProfileStats(req, res, next) {
  try {
    const userId = req.user.id;

    const [leaguesRes, teamsRes, predictionsRes, gwHistoryRes] = await Promise.all([
      // Number of leagues joined
      pool.query(
        'SELECT COUNT(*) FROM league_members WHERE user_id = $1',
        [userId]
      ),
      // Teams & their stats
      pool.query(
        `SELECT t.id, t.name, t.formation, t.total_points, t.captain_id,
                l.name as league_name,
                p.name as captain_name
         FROM teams t
         JOIN leagues l ON t.league_id = l.id
         LEFT JOIN players p ON t.captain_id = p.id
         WHERE t.user_id = $1`,
        [userId]
      ),
      // Prediction accuracy
      pool.query(
        `SELECT COUNT(*) as total,
                COUNT(*) FILTER (WHERE resolved = true AND bonus_points > 0) as correct,
                COALESCE(SUM(bonus_points), 0) as total_bonus
         FROM predictions WHERE user_id = $1`,
        [userId]
      ),
      // Last 5 gameweek scores
      pool.query(
        `SELECT gw.number, gw.season, tgs.points as gw_points, tgs.captain_id
         FROM team_gameweek_scores tgs
         JOIN teams t ON tgs.team_id = t.id
         JOIN gameweeks gw ON tgs.gameweek_id = gw.id
         WHERE t.user_id = $1
         ORDER BY gw.number DESC
         LIMIT 5`,
        [userId]
      ),
    ]);

    res.json({
      user: req.user,
      stats: {
        leagues_count: parseInt(leaguesRes.rows[0].count),
        teams: teamsRes.rows,
        predictions: {
          total: parseInt(predictionsRes.rows[0].total),
          correct: parseInt(predictionsRes.rows[0].correct),
          bonus_pts: parseInt(predictionsRes.rows[0].total_bonus),
        },
        gw_history: gwHistoryRes.rows,
      },
    });
  } catch (err) {
    next(err);
  }
}

async function updateProfile(req, res, next) {
  try {
    const { username, email, avatar_url, date_of_birth, country, favorite_nation, favorite_club, favorite_player, bio } = req.body;
    const result = await pool.query(
      `UPDATE users SET
         username = COALESCE($1, username),
         email = COALESCE($2, email),
         avatar_url = COALESCE($3, avatar_url),
         date_of_birth = COALESCE($4, date_of_birth),
         country = COALESCE($5, country),
         favorite_nation = COALESCE($6, favorite_nation),
         favorite_club = COALESCE($7, favorite_club),
         favorite_player = COALESCE($8, favorite_player),
         bio = COALESCE($9, bio),
         updated_at = NOW()
       WHERE id = $10
       RETURNING id, username, email, avatar_url, total_points, date_of_birth, country, favorite_nation, favorite_club, favorite_player, bio`,
      [username, email || null, avatar_url, date_of_birth || null, country || null, favorite_nation || null, favorite_club || null, favorite_player || null, bio || null, req.user.id]
    );
    await cacheDel(`user:${req.user.id}`);
    res.json({ user: result.rows[0] });
  } catch (err) {
    // Unique violation on email or username
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Email or username already taken' });
    }
    next(err);
  }
}

// POST /api/auth/avatar — upload a profile photo (base64 JSON, no extra deps)
async function uploadAvatar(req, res, next) {
  try {
    const { image, ext } = req.body;
    if (!image || typeof image !== 'string') {
      return res.status(400).json({ error: 'image (base64) required' });
    }
    const safeExt = AVATAR_EXTS.includes((ext || 'jpg').toLowerCase()) ? (ext || 'jpg').toLowerCase() : 'jpg';
    const b64 = image.replace(/^data:image\/[a-zA-Z]+;base64,/, '');
    const buf = Buffer.from(b64, 'base64');
    if (buf.length === 0) return res.status(400).json({ error: 'Invalid image data' });
    if (buf.length > 3 * 1024 * 1024) return res.status(413).json({ error: 'Image too large (max 3 MB)' });

    fs.mkdirSync(AVATAR_DIR, { recursive: true });
    // Remove any prior avatar (possibly a different extension) so we don't orphan files.
    for (const e of AVATAR_EXTS) {
      const f = path.join(AVATAR_DIR, `${req.user.id}.${e}`);
      if (fs.existsSync(f)) { try { fs.unlinkSync(f); } catch (_) { /* ignore */ } }
    }
    fs.writeFileSync(path.join(AVATAR_DIR, `${req.user.id}.${safeExt}`), buf);

    const avatarUrl = `/api/photos/avatar/${req.user.id}`;
    await pool.query('UPDATE users SET avatar_url = $1, updated_at = NOW() WHERE id = $2', [avatarUrl, req.user.id]);
    await cacheDel(`user:${req.user.id}`);
    res.json({ avatar_url: avatarUrl });
  } catch (err) {
    next(err);
  }
}

// DELETE /api/auth/account — permanently delete the user (cascades to teams/leagues/etc.)
async function deleteAccount(req, res, next) {
  try {
    await pool.query('DELETE FROM users WHERE id = $1', [req.user.id]);
    for (const e of AVATAR_EXTS) {
      const f = path.join(AVATAR_DIR, `${req.user.id}.${e}`);
      if (fs.existsSync(f)) { try { fs.unlinkSync(f); } catch (_) { /* ignore */ } }
    }
    await cacheDel(`user:${req.user.id}`);
    res.json({ message: 'Account deleted' });
  } catch (err) {
    next(err);
  }
}

// GET /api/auth/settings
async function getSettings(req, res, next) {
  try {
    const userId = req.user.id;
    let result = await pool.query('SELECT * FROM user_settings WHERE user_id = $1', [userId]);
    if (result.rows.length === 0) {
      // Create default settings
      result = await pool.query(
        `INSERT INTO user_settings (user_id) VALUES ($1) RETURNING *`,
        [userId]
      );
    }
    res.json({ settings: result.rows[0] });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/auth/settings
async function updateSettings(req, res, next) {
  try {
    const { notifications_battles, notifications_chat, notifications_news } = req.body;
    const result = await pool.query(
      `INSERT INTO user_settings (user_id, notifications_battles, notifications_chat, notifications_news, updated_at)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (user_id) DO UPDATE SET
         notifications_battles = COALESCE($2, user_settings.notifications_battles),
         notifications_chat = COALESCE($3, user_settings.notifications_chat),
         notifications_news = COALESCE($4, user_settings.notifications_news),
         updated_at = NOW()
       RETURNING *`,
      [req.user.id, notifications_battles, notifications_chat, notifications_news]
    );
    res.json({ settings: result.rows[0] });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/auth/profile/password
async function changePassword(req, res, next) {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'currentPassword and newPassword required' });
    }
    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters' });
    }

    const result = await pool.query(
      'SELECT password_hash FROM users WHERE id = $1',
      [req.user.id]
    );
    const isValid = await bcrypt.compare(currentPassword, result.rows[0].password_hash);
    if (!isValid) return res.status(401).json({ error: 'Current password is incorrect' });

    const newHash = await bcrypt.hash(newPassword, 12);
    await pool.query(
      'UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2',
      [newHash, req.user.id]
    );

    res.json({ message: 'Password changed successfully' });
  } catch (err) {
    next(err);
  }
}

// GET /api/auth/achievements
async function getAchievements(req, res, next) {
  try {
    const userId = req.user.id;

    const [leaguesRes, teamsRes, battlesWonRes, predictionsRes, challengesRes, chatRes] = await Promise.all([
      pool.query('SELECT COUNT(*) FROM league_members WHERE user_id = $1', [userId]),
      pool.query('SELECT COUNT(*) FROM teams WHERE user_id = $1', [userId]),
      pool.query(
        `SELECT COUNT(*) FROM battles b
         JOIN teams t ON (b.home_team_id = t.id OR b.away_team_id = t.id)
         WHERE t.user_id = $1 AND b.status = 'completed' AND (
           (b.home_team_id = t.id AND b.home_score > b.away_score) OR
           (b.away_team_id = t.id AND b.away_score > b.home_score)
         )`,
        [userId]
      ),
      pool.query(
        'SELECT COUNT(*) FILTER (WHERE bonus_points > 0) as correct FROM predictions WHERE user_id = $1',
        [userId]
      ),
      pool.query('SELECT COALESCE(SUM(xp_earned),0) as total_xp FROM user_challenges WHERE user_id = $1', [userId]),
      pool.query('SELECT COUNT(*) FROM chat_messages WHERE user_id = $1', [userId]),
    ]);

    const leagues = parseInt(leaguesRes.rows[0].count);
    const teams = parseInt(teamsRes.rows[0].count);
    const battlesWon = parseInt(battlesWonRes.rows[0].count);
    const predictionsCorrect = parseInt(predictionsRes.rows[0].correct);
    const totalXp = parseInt(challengesRes.rows[0].total_xp);
    const chatMessages = parseInt(chatRes.rows[0].count);

    const ACHIEVEMENTS = [
      { key: 'first_draft',      title: 'Premier Draft',        description: 'Créé ta première équipe',            icon: 'sports_soccer', unlocked: teams >= 1 },
      { key: 'league_creator',   title: 'Fondateur de Ligue',   description: 'Rejoint ou créé une ligue',          icon: 'emoji_events',  unlocked: leagues >= 1 },
      { key: 'first_win',        title: 'Première Victoire',    description: 'Gagné un battle H2H',                icon: 'military_tech', unlocked: battlesWon >= 1 },
      { key: 'hat_trick_wins',   title: 'Hat-Trick de Victoires', description: 'Gagné 3 battles',                     icon: 'stars',         unlocked: battlesWon >= 3 },
      { key: 'oracle',           title: 'Oracle',               description: 'Réussi 3 prédictions correctes',     icon: 'psychology',    unlocked: predictionsCorrect >= 3 },
      { key: 'xp_rookie',       title: 'Rookie XP',            description: 'Gagné 50 XP via les défis',          icon: 'grade',         unlocked: totalXp >= 50 },
      { key: 'xp_pro',          title: 'Pro XP',               description: 'Gagné 350 XP via les défis',         icon: 'workspace_premium', unlocked: totalXp >= 350 },
      { key: 'social_butterfly', title: 'Social Butterfly',     description: 'Envoyé 10 messages dans le chat',    icon: 'chat',          unlocked: chatMessages >= 10 },
      { key: 'multi_league',    title: 'Multitâche',           description: 'Participé à 3 ligues simultanément', icon: 'account_tree',  unlocked: leagues >= 3 },
      { key: 'champion',        title: 'Champion WC 2026',     description: 'Terminé 1er dans une ligue',         icon: 'workspace_premium', unlocked: false },
    ];

    res.json({ achievements: ACHIEVEMENTS });
  } catch (err) {
    next(err);
  }
}

// POST /api/auth/forgot-password
async function forgotPassword(req, res, next) {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email required' });

    // Always return 200 to prevent email enumeration
    const result = await pool.query(
      'SELECT id, username, email FROM users WHERE email = $1',
      [email.toLowerCase().trim()]
    );

    if (result.rows.length === 0) {
      return res.json({ message: 'If this email exists, a reset link was sent.' });
    }

    const user = result.rows[0];

    // Generate a secure random token
    const rawToken  = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    // Store hashed token in DB (never store raw tokens)
    await pool.query(
      `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
       VALUES ($1, $2, $3)
       ON CONFLICT (user_id) DO UPDATE
         SET token_hash = EXCLUDED.token_hash,
             expires_at = EXCLUDED.expires_at,
             created_at = NOW()`,
      [user.id, tokenHash, expiresAt]
    );

    // Send email with raw token in the link
    try {
      await sendPasswordResetEmail(user.email, rawToken, user.username);
    } catch (mailErr) {
      console.error('Failed to send reset email:', mailErr.message);
      // Don't expose the error to the client
    }

    res.json({ message: 'If this email exists, a reset link was sent.' });
  } catch (err) {
    next(err);
  }
}

// POST /api/auth/reset-password
async function resetPassword(req, res, next) {
  try {
    const { token, newPassword } = req.body;
    if (!token || !newPassword) {
      return res.status(400).json({ error: 'token and newPassword are required' });
    }
    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    // Hash the incoming token to compare with stored hash
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

    const result = await pool.query(
      `SELECT prt.user_id, u.email, u.username
       FROM password_reset_tokens prt
       JOIN users u ON prt.user_id = u.id
       WHERE prt.token_hash = $1 AND prt.expires_at > NOW()`,
      [tokenHash]
    );

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid or expired reset token' });
    }

    const { user_id } = result.rows[0];

    // Update password
    const newHash = await bcrypt.hash(newPassword, 12);
    await pool.query(
      'UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2',
      [newHash, user_id]
    );

    // Invalidate the reset token
    await pool.query(
      'DELETE FROM password_reset_tokens WHERE user_id = $1',
      [user_id]
    );

    // Invalidate all existing refresh tokens for security
    await pool.query(
      'DELETE FROM refresh_tokens WHERE user_id = $1',
      [user_id]
    );

    res.json({ message: 'Password reset successfully. Please log in.' });
  } catch (err) {
    next(err);
  }
}

module.exports = { register, login, refresh, logout, getProfile, updateProfile, uploadAvatar, deleteAccount, getProfileStats, getSettings, updateSettings, changePassword, getAchievements, forgotPassword, resetPassword };
