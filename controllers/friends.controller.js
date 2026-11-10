const { pool } = require('../config/db');

// GET /api/friends — accepted friends (either direction), with rank/points.
async function getFriends(req, res, next) {
  try {
    const me = req.user.id;
    const { rows } = await pool.query(
      `SELECT u.id, u.username, u.avatar_url, u.total_points, u.rank
       FROM friendships f
       JOIN users u ON u.id = CASE WHEN f.user_id = $1 THEN f.friend_id ELSE f.user_id END
       WHERE (f.user_id = $1 OR f.friend_id = $1) AND f.status = 'accepted'
       ORDER BY u.total_points DESC`,
      [me]
    );
    res.json(rows);
  } catch (err) {
    next(err);
  }
}

// GET /api/friends/requests — incoming pending requests.
async function getRequests(req, res, next) {
  try {
    const me = req.user.id;
    const { rows } = await pool.query(
      `SELECT u.id, u.username, u.avatar_url, u.total_points, f.created_at
       FROM friendships f
       JOIN users u ON u.id = f.user_id
       WHERE f.friend_id = $1 AND f.status = 'pending'
       ORDER BY f.created_at DESC`,
      [me]
    );
    res.json(rows);
  } catch (err) {
    next(err);
  }
}

// POST /api/friends/request { username }
async function sendRequest(req, res, next) {
  try {
    const me = req.user.id;
    const { username } = req.body;
    if (!username) return res.status(400).json({ error: 'username required' });

    const userRes = await pool.query('SELECT id FROM users WHERE username = $1', [username]);
    if (userRes.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    const targetId = userRes.rows[0].id;
    if (targetId === me) return res.status(400).json({ error: 'Cannot add yourself' });

    // Already linked (either direction, any status)?
    const existing = await pool.query(
      `SELECT status FROM friendships
       WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)`,
      [me, targetId]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Already friends or request pending' });
    }

    await pool.query(
      `INSERT INTO friendships (user_id, friend_id, status) VALUES ($1, $2, 'pending')`,
      [me, targetId]
    );
    res.status(201).json({ message: 'Friend request sent' });
  } catch (err) {
    next(err);
  }
}

// POST /api/friends/:userId/accept — accept an incoming request from :userId.
async function acceptRequest(req, res, next) {
  try {
    const me = req.user.id;
    const { userId } = req.params;
    const result = await pool.query(
      `UPDATE friendships SET status = 'accepted'
       WHERE user_id = $1 AND friend_id = $2 AND status = 'pending'
       RETURNING *`,
      [userId, me]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'No pending request from this user' });
    res.json({ message: 'Friend added' });
  } catch (err) {
    next(err);
  }
}

// DELETE /api/friends/:userId — remove friend or decline request (either direction).
async function removeFriend(req, res, next) {
  try {
    const me = req.user.id;
    const { userId } = req.params;
    await pool.query(
      `DELETE FROM friendships
       WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)`,
      [me, userId]
    );
    res.json({ message: 'Removed' });
  } catch (err) {
    next(err);
  }
}

// GET /api/friends/search?q= — find users by username (for adding).
async function searchUsers(req, res, next) {
  try {
    const me = req.user.id;
    const q = (req.query.q || '').trim();
    if (q.length < 2) return res.json([]);
    const { rows } = await pool.query(
      `SELECT id, username, avatar_url, total_points, rank
       FROM users
       WHERE username ILIKE $1 AND id != $2
       ORDER BY total_points DESC
       LIMIT 20`,
      [`%${q}%`, me]
    );
    res.json(rows);
  } catch (err) {
    next(err);
  }
}

module.exports = { getFriends, getRequests, sendRequest, acceptRequest, removeFriend, searchUsers };
