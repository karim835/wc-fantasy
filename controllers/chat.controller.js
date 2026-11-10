const { pool } = require('../config/db');
const { getIO } = require('../socket/socket');

async function getMessages(req, res, next) {
  try {
    const { leagueId } = req.params;

    const result = await pool.query(
      `SELECT cm.id, cm.league_id, cm.user_id, cm.message, cm.created_at,
              u.username
       FROM chat_messages cm
       JOIN users u ON cm.user_id = u.id
       WHERE cm.league_id = $1
       ORDER BY cm.created_at DESC
       LIMIT 50`,
      [leagueId]
    );

    // Return in chronological order (oldest first) for easier client rendering
    res.json(result.rows.reverse());
  } catch (err) {
    next(err);
  }
}

async function sendMessage(req, res, next) {
  try {
    const { leagueId } = req.params;
    const { message } = req.body;
    const userId = req.user?.id;

    if (!message || typeof message !== 'string' || message.trim().length === 0) {
      return res.status(400).json({ error: 'Message cannot be empty' });
    }

    if (message.trim().length > 1000) {
      return res.status(400).json({ error: 'Message too long (max 1000 characters)' });
    }

    const result = await pool.query(
      `INSERT INTO chat_messages (league_id, user_id, message)
       VALUES ($1, $2, $3)
       RETURNING id, league_id, user_id, message, created_at`,
      [leagueId, userId, message.trim()]
    );

    const newMessage = result.rows[0];

    // Fetch the username to attach to the emitted event
    const userResult = await pool.query('SELECT username FROM users WHERE id = $1', [userId]);
    const username = userResult.rows[0]?.username ?? null;

    const payload = { ...newMessage, username };

    const io = getIO();
    io.to(`league:${leagueId}`).emit('chat:message', payload);

    res.status(201).json(payload);
  } catch (err) {
    next(err);
  }
}

module.exports = { getMessages, sendMessage };
