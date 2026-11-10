const { pool } = require('../config/db');

// GET /api/users/:userId/profile — public read-only profile of any manager.
async function getPublicProfile(req, res, next) {
  try {
    const { userId } = req.params;
    const result = await pool.query(
      `SELECT id, username, avatar_url, total_points, rank, created_at,
              favorite_nation, favorite_club, favorite_player, bio
       FROM users WHERE id = $1`,
      [userId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ user: result.rows[0] });
  } catch (err) {
    next(err);
  }
}

module.exports = { getPublicProfile };
