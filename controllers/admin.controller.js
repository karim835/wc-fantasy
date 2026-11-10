/**
 * Admin controller — dashboard analytics + full management.
 * All routes are gated by `authenticate` + `requireAdmin` (see routes/admin.routes.js).
 */

const { pool } = require('../config/db');

// Tables surfaced in the System/DB panel (read-only row counts).
const DB_TABLES = [
  'users', 'leagues', 'league_members', 'teams', 'players', 'player_scores',
  'team_gameweek_scores', 'gameweeks', 'matches', 'battles', 'friendships',
  'predictions', 'chat_messages', 'user_challenges', 'user_achievements',
];

// GET /api/admin/overview — aggregated dashboard payload
async function getOverview(req, res, next) {
  try {
    const [counts, gwByStatus, recentUsers, signups, dbVersion] = await Promise.all([
      pool.query(`
        SELECT
          (SELECT COUNT(*) FROM users)                         AS users,
          (SELECT COUNT(*) FROM leagues)                       AS leagues,
          (SELECT COUNT(*) FROM leagues WHERE status='active') AS active_leagues,
          (SELECT COUNT(*) FROM teams)                         AS teams,
          (SELECT COUNT(*) FROM players)                       AS players,
          (SELECT COUNT(*) FROM gameweeks)                     AS gameweeks,
          (SELECT COUNT(*) FROM matches)                       AS matches,
          (SELECT COUNT(*) FROM battles)                       AS battles,
          (SELECT COUNT(*) FROM friendships WHERE status='accepted') AS friendships
      `),
      pool.query(`SELECT status, COUNT(*)::int AS count FROM gameweeks GROUP BY status`),
      pool.query(`
        SELECT id, username, email, role, total_points, created_at
        FROM users ORDER BY created_at DESC LIMIT 10
      `),
      pool.query(`
        SELECT date_trunc('day', created_at)::date AS day, COUNT(*)::int AS count
        FROM users
        WHERE created_at >= NOW() - INTERVAL '14 days'
        GROUP BY 1 ORDER BY 1 ASC
      `),
      pool.query('SELECT version() AS v'),
    ]);

    // Per-table row counts (sequential is fine — small table list).
    const tableCounts = {};
    for (const t of DB_TABLES) {
      try {
        const r = await pool.query(`SELECT COUNT(*)::int AS c FROM ${t}`);
        tableCounts[t] = r.rows[0].c;
      } catch (_) {
        tableCounts[t] = null;
      }
    }

    const mem = process.memoryUsage();
    res.json({
      counts: counts.rows[0],
      gameweeksByStatus: gwByStatus.rows,
      recentUsers: recentUsers.rows,
      signupsByDay: signups.rows,
      system: {
        uptimeSeconds: Math.round(process.uptime()),
        memoryRssMb: Math.round(mem.rss / 1024 / 1024),
        nodeVersion: process.version,
        env: process.env.NODE_ENV || 'development',
        dbVersion: dbVersion.rows[0].v,
        tableCounts,
      },
    });
  } catch (err) {
    next(err);
  }
}

// GET /api/admin/users?search=&limit=&offset=
async function listUsers(req, res, next) {
  try {
    const search = (req.query.search || '').trim();
    const limit = Math.min(parseInt(req.query.limit) || 50, 200);
    const offset = parseInt(req.query.offset) || 0;

    const where = search ? `WHERE u.username ILIKE $3 OR u.email ILIKE $3` : '';
    const params = [limit, offset];
    if (search) params.push(`%${search}%`);

    const result = await pool.query(
      `SELECT u.id, u.username, u.email, u.role, u.total_points, u.rank, u.created_at,
              (SELECT COUNT(*)::int FROM league_members lm WHERE lm.user_id = u.id) AS league_count
       FROM users u
       ${where}
       ORDER BY u.created_at DESC
       LIMIT $1 OFFSET $2`,
      params
    );

    const totalRes = await pool.query(
      `SELECT COUNT(*)::int AS total FROM users u ${search ? 'WHERE u.username ILIKE $1 OR u.email ILIKE $1' : ''}`,
      search ? [`%${search}%`] : []
    );

    res.json({ users: result.rows, total: totalRes.rows[0].total });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/admin/users/:id/role  { role }
async function setUserRole(req, res, next) {
  try {
    const { id } = req.params;
    const { role } = req.body;
    if (!['admin', 'user'].includes(role)) {
      return res.status(400).json({ error: 'role must be "admin" or "user"' });
    }
    if (id === req.user.id && role !== 'admin') {
      return res.status(400).json({ error: 'You cannot demote your own account' });
    }
    const result = await pool.query(
      'UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2 RETURNING id, username, email, role',
      [role, id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ user: result.rows[0] });
  } catch (err) {
    next(err);
  }
}

// DELETE /api/admin/users/:id
async function deleteUser(req, res, next) {
  try {
    const { id } = req.params;
    if (id === req.user.id) {
      return res.status(400).json({ error: 'You cannot delete your own account here' });
    }
    const result = await pool.query('DELETE FROM users WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json({ message: 'User deleted', id });
  } catch (err) {
    next(err);
  }
}

// GET /api/admin/leagues?search=
async function listLeagues(req, res, next) {
  try {
    const search = (req.query.search || '').trim();
    const where = search ? `WHERE l.name ILIKE $1` : '';
    const result = await pool.query(
      `SELECT l.id, l.name, l.is_private, l.status, l.max_members, l.invite_code, l.created_at,
              u.username AS owner_username,
              (SELECT COUNT(*)::int FROM league_members lm WHERE lm.league_id = l.id) AS member_count
       FROM leagues l
       LEFT JOIN users u ON u.id = l.owner_id
       ${where}
       ORDER BY l.created_at DESC
       LIMIT 200`,
      search ? [`%${search}%`] : []
    );
    res.json({ leagues: result.rows });
  } catch (err) {
    next(err);
  }
}

// DELETE /api/admin/leagues/:id
async function deleteLeague(req, res, next) {
  try {
    const { id } = req.params;
    const result = await pool.query('DELETE FROM leagues WHERE id = $1 RETURNING id', [id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'League not found' });
    res.json({ message: 'League deleted', id });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/admin/players/:id  { price?, injury_status?, points?, form? }
async function updatePlayer(req, res, next) {
  try {
    const { id } = req.params;
    const { price, injury_status, points, form } = req.body;
    const result = await pool.query(
      `UPDATE players SET
         price         = COALESCE($1, price),
         injury_status = COALESCE($2, injury_status),
         points        = COALESCE($3, points),
         form          = COALESCE($4, form),
         updated_at    = NOW()
       WHERE id = $5
       RETURNING id, name, position, club, nationality, price, points, form, injury_status, photo_url`,
      [
        price !== undefined ? price : null,
        injury_status !== undefined ? injury_status : null,
        points !== undefined ? points : null,
        form !== undefined ? form : null,
        id,
      ]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Player not found' });
    res.json({ player: result.rows[0] });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getOverview,
  listUsers,
  setUserRole,
  deleteUser,
  listLeagues,
  deleteLeague,
  updatePlayer,
};
