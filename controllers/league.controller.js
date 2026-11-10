const { pool } = require('../config/db');
const { cacheGet, cacheSet, cacheDel } = require('../config/cache');
const { v4: uuidv4 } = require('uuid');

async function getLeagues(req, res, next) {
  try {
    const cacheKey = `leagues:user:${req.user.id}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const result = await pool.query(
      `SELECT l.*, lm.points as my_points,
        (SELECT COUNT(*) FROM league_members WHERE league_id = l.id) as member_count
       FROM leagues l
       JOIN league_members lm ON l.id = lm.league_id
       WHERE lm.user_id = $1
       ORDER BY l.created_at DESC`,
      [req.user.id]
    );

    await cacheSet(cacheKey, result.rows, 300);
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
}

async function createLeague(req, res, next) {
  try {
    const { name, max_members, is_private, season } = req.body;
    const inviteCode = uuidv4().split('-')[0].toUpperCase();

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const leagueResult = await client.query(
        `INSERT INTO leagues (name, owner_id, max_members, is_private, invite_code, season)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING *`,
        [name, req.user.id, max_members || 10, is_private || false, inviteCode, season]
      );

      const league = leagueResult.rows[0];
      await client.query(
        'INSERT INTO league_members (league_id, user_id) VALUES ($1, $2)',
        [league.id, req.user.id]
      );

      await client.query('COMMIT');
      await cacheDel(`leagues:user:${req.user.id}`);
      res.status(201).json(league);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    next(err);
  }
}

async function getLeague(req, res, next) {
  try {
    const { leagueId } = req.params;
    const cacheKey = `league:${leagueId}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const result = await pool.query(
      `SELECT l.*,
        json_agg(json_build_object(
          'user_id', u.id, 'username', u.username,
          'avatar_url', u.avatar_url, 'points', lm.points
        ) ORDER BY lm.points DESC) as members
       FROM leagues l
       JOIN league_members lm ON l.id = lm.league_id
       JOIN users u ON lm.user_id = u.id
       WHERE l.id = $1
       GROUP BY l.id`,
      [leagueId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'League not found' });
    }

    await cacheSet(cacheKey, result.rows[0], 120);
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

async function joinLeague(req, res, next) {
  try {
    // Accept both camelCase and snake_case from clients, and normalize the code
    // (codes are stored UPPERCASE) so case/whitespace never cause false misses.
    const raw = req.body.inviteCode ?? req.body.invite_code ?? '';
    const inviteCode = String(raw).trim().toUpperCase();
    if (!inviteCode) {
      return res.status(400).json({ error: 'Invite code required' });
    }

    const leagueResult = await pool.query(
      'SELECT * FROM leagues WHERE UPPER(invite_code) = $1 AND status = $2',
      [inviteCode, 'active']
    );

    if (leagueResult.rows.length === 0) {
      return res.status(404).json({ error: 'Invalid invite code' });
    }

    const league = leagueResult.rows[0];
    const memberCount = await pool.query(
      'SELECT COUNT(*) FROM league_members WHERE league_id = $1',
      [league.id]
    );

    if (parseInt(memberCount.rows[0].count) >= league.max_members) {
      return res.status(400).json({ error: 'League is full' });
    }

    await pool.query(
      'INSERT INTO league_members (league_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [league.id, req.user.id]
    );

    await cacheDel(`leagues:user:${req.user.id}`);
    await cacheDel(`league:${league.id}`);
    res.json({ message: 'Joined league successfully', league });
  } catch (err) {
    next(err);
  }
}

async function getLeaderboard(req, res, next) {
  try {
    const { leagueId } = req.params;
    const cacheKey = `leaderboard:${leagueId}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const result = await pool.query(
      `SELECT u.id, u.username, u.avatar_url, lm.points,
        RANK() OVER (ORDER BY lm.points DESC) as rank
       FROM league_members lm
       JOIN users u ON lm.user_id = u.id
       WHERE lm.league_id = $1`,
      [leagueId]
    );

    await cacheSet(cacheKey, result.rows, 60);
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
}

// DELETE /api/leagues/:leagueId/leave — leave a league (owner must delete instead)
async function leaveLeague(req, res, next) {
  try {
    const { leagueId } = req.params;
    const league = await pool.query('SELECT owner_id FROM leagues WHERE id = $1', [leagueId]);
    if (league.rows.length === 0) return res.status(404).json({ error: 'League not found' });
    if (league.rows[0].owner_id === req.user.id) {
      return res.status(400).json({ error: 'Owner cannot leave — delete the league instead' });
    }
    await pool.query('DELETE FROM league_members WHERE league_id = $1 AND user_id = $2', [leagueId, req.user.id]);
    await pool.query('DELETE FROM teams WHERE league_id = $1 AND user_id = $2', [leagueId, req.user.id]);
    await cacheDel(`leagues:user:${req.user.id}`);
    await cacheDel(`league:${leagueId}`);
    res.json({ message: 'Left league' });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/leagues/:leagueId — owner-only: rename / resize / privacy
async function updateLeague(req, res, next) {
  try {
    const { leagueId } = req.params;
    const { name, max_members, is_private } = req.body;
    const result = await pool.query(
      `UPDATE leagues SET
         name = COALESCE($1, name),
         max_members = COALESCE($2, max_members),
         is_private = COALESCE($3, is_private)
       WHERE id = $4 RETURNING *`,
      [name || null, max_members || null, is_private, leagueId]
    );
    await cacheDel(`league:${leagueId}`);
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

// DELETE /api/leagues/:leagueId — owner-only: delete league (cascades)
async function deleteLeague(req, res, next) {
  try {
    const { leagueId } = req.params;
    await pool.query('DELETE FROM leagues WHERE id = $1', [leagueId]);
    await cacheDel(`leagues:user:${req.user.id}`);
    await cacheDel(`league:${leagueId}`);
    res.json({ message: 'League deleted' });
  } catch (err) {
    next(err);
  }
}

// DELETE /api/leagues/:leagueId/members/:userId — owner-only kick
async function kickMember(req, res, next) {
  try {
    const { leagueId, userId } = req.params;
    if (userId === req.user.id) return res.status(400).json({ error: 'Use leave instead' });
    await pool.query('DELETE FROM league_members WHERE league_id = $1 AND user_id = $2', [leagueId, userId]);
    await pool.query('DELETE FROM teams WHERE league_id = $1 AND user_id = $2', [leagueId, userId]);
    await cacheDel(`league:${leagueId}`);
    res.json({ message: 'Member removed' });
  } catch (err) {
    next(err);
  }
}

// GET /api/leagues/public — discover joinable public leagues
async function getPublicLeagues(req, res, next) {
  try {
    const result = await pool.query(
      `SELECT l.id, l.name, l.season, l.max_members, l.invite_code,
              (SELECT COUNT(*) FROM league_members WHERE league_id = l.id) AS member_count
       FROM leagues l
       WHERE l.is_private = false AND l.status = 'active'
         AND NOT EXISTS (SELECT 1 FROM league_members m WHERE m.league_id = l.id AND m.user_id = $1)
       ORDER BY l.created_at DESC
       LIMIT 50`,
      [req.user.id]
    );
    // Filter out full leagues in JS (HAVING on the subquery count is awkward).
    const open = result.rows.filter(r => parseInt(r.member_count, 10) < r.max_members);
    res.json(open);
  } catch (err) {
    next(err);
  }
}

// POST /api/leagues/:leagueId/join-public — join a public league directly
async function joinPublicLeague(req, res, next) {
  try {
    const { leagueId } = req.params;
    const leagueRes = await pool.query(
      "SELECT * FROM leagues WHERE id = $1 AND is_private = false AND status = 'active'",
      [leagueId]
    );
    if (leagueRes.rows.length === 0) return res.status(404).json({ error: 'Public league not found' });
    const league = leagueRes.rows[0];

    const countRes = await pool.query('SELECT COUNT(*) FROM league_members WHERE league_id = $1', [leagueId]);
    if (parseInt(countRes.rows[0].count, 10) >= league.max_members) {
      return res.status(400).json({ error: 'League is full' });
    }

    await pool.query(
      'INSERT INTO league_members (league_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [leagueId, req.user.id]
    );
    await cacheDel(`leagues:user:${req.user.id}`);
    await cacheDel(`league:${leagueId}`);
    res.json({ message: 'Joined league', league });
  } catch (err) {
    next(err);
  }
}

// GET /api/leagues/:leagueId/members/:userId/team — a member's team in this league (read-only)
async function getMemberTeam(req, res, next) {
  try {
    const { leagueId, userId } = req.params;
    const result = await pool.query(
      `SELECT t.id, t.name, t.formation, t.players, t.total_points, t.captain_id,
              u.username, u.avatar_url
       FROM teams t JOIN users u ON t.user_id = u.id
       WHERE t.league_id = $1 AND t.user_id = $2`,
      [leagueId, userId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Team not found' });
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getLeagues, createLeague, getLeague, joinLeague, getLeaderboard, getMemberTeam,
  leaveLeague, updateLeague, deleteLeague, kickMember, getPublicLeagues, joinPublicLeague,
};
