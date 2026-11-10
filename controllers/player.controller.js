const { pool } = require('../config/db');
const { cacheGet, cacheSet } = require('../config/cache');

async function getPlayers(req, res, next) {
  try {
    const { position, club, search, nationality, sort, page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const conditions = [];
    const values = [];
    let idx = 1;

    if (position) { conditions.push(`position = $${idx++}`); values.push(position); }
    if (club) { conditions.push(`club ILIKE $${idx++}`); values.push(`%${club}%`); }
    if (search) { conditions.push(`name ILIKE $${idx++}`); values.push(`%${search}%`); }
    if (nationality) { conditions.push(`nationality = $${idx++}`); values.push(nationality); }

    const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    // Whitelisted sort columns (never interpolate raw user input into SQL).
    const SORTS = { points: 'points DESC', price: 'price DESC', form: 'form DESC', name: 'name ASC' };
    const orderBy = SORTS[sort] || SORTS.points;

    values.push(parseInt(limit), offset);

    const result = await pool.query(
      `SELECT id, name, position, club, nationality,
              price::float AS price, points, form::float AS form,
              injury_status, stats, photo_url, date_of_birth, height_cm, weight_kg
       FROM players ${where}
       ORDER BY ${orderBy}
       LIMIT $${idx} OFFSET $${idx + 1}`,
      values
    );

    const countResult = await pool.query(
      `SELECT COUNT(*) FROM players ${where}`,
      values.slice(0, -2)
    );

    res.json({
      players: result.rows,
      total: parseInt(countResult.rows[0].count),
      page: parseInt(page),
      limit: parseInt(limit),
    });
  } catch (err) {
    next(err);
  }
}

async function getPlayer(req, res, next) {
  try {
    const { playerId } = req.params;
    const cacheKey = `player:${playerId}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const result = await pool.query(
      `SELECT id, name, position, club, nationality,
              price::float AS price, points, form::float AS form,
              injury_status, stats, photo_url, date_of_birth, height_cm, weight_kg
       FROM players WHERE id = $1`,
      [playerId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Player not found' });
    }

    await cacheSet(cacheKey, result.rows[0], 600);
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

async function getTopPlayers(req, res, next) {
  try {
    const { position, limit = 10 } = req.query;
    const cacheKey = `top-players:${position || 'all'}:${limit}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const where = position ? 'WHERE position = $2' : '';
    const values = position ? [parseInt(limit), position] : [parseInt(limit)];
    const orderLimit = position ? '$1' : '$1';

    const result = await pool.query(
      `SELECT id, name, position, club, nationality,
              price::float AS price, points, form::float AS form,
              injury_status, photo_url
       FROM players ${position ? 'WHERE position = $2' : ''}
       ORDER BY points DESC LIMIT $1`,
      values
    );

    await cacheSet(cacheKey, result.rows, 300);
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
}

async function getNationalities(req, res, next) {
  try {
    const cacheKey = 'player-nationalities';
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const result = await pool.query(
      `SELECT nationality, COUNT(*)::int AS count
       FROM players
       WHERE nationality IS NOT NULL AND nationality <> ''
       GROUP BY nationality
       ORDER BY nationality`
    );
    await cacheSet(cacheKey, result.rows, 600);
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
}

module.exports = { getPlayers, getPlayer, getTopPlayers, getNationalities };
