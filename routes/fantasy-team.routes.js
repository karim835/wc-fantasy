const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth');
const { pool } = require('../config/db');
const { cacheDel } = require('../config/cache');

// GET /api/fantasy-team/my-team
router.get('/my-team', authenticate, async (req, res, next) => {
  try {
    const result = await pool.query(
      `SELECT t.*, l.name AS league_name
       FROM teams t
       LEFT JOIN leagues l ON t.league_id = l.id
       WHERE t.user_id = $1
       ORDER BY t.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
});

// GET /api/fantasy-team/my-team/:leagueId
router.get('/my-team/:leagueId', authenticate, async (req, res, next) => {
  try {
    const { leagueId } = req.params;
    const result = await pool.query(
      'SELECT * FROM teams WHERE user_id = $1 AND league_id = $2',
      [req.user.id, leagueId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Team not found in this league' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
});

// POST /api/fantasy-team/my-team/players — Add a player to the team
router.post('/my-team/players', authenticate, async (req, res, next) => {
  const client = await pool.connect();
  try {
    const { leagueId, playerId } = req.body;

    await client.query('BEGIN');

    const teamResult = await client.query(
      'SELECT * FROM teams WHERE user_id = $1 AND league_id = $2 FOR UPDATE',
      [req.user.id, leagueId]
    );

    if (teamResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Team not found' });
    }

    const team = teamResult.rows[0];
    let players = team.players || [];
    if (typeof players === 'string') players = JSON.parse(players);

    if (players.length >= 15) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Maximum 15 players per team' });
    }

    if (players.some(p => (typeof p === 'string' ? p : p.id) === playerId)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Player already in team' });
    }

    const playerResult = await client.query(
      'SELECT id, name, position, price, club FROM players WHERE id = $1',
      [playerId]
    );

    if (playerResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Player not found' });
    }

    const player = playerResult.rows[0];

    if (parseFloat(team.budget) < parseFloat(player.price)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Insufficient budget' });
    }

    // Max 3 players from same club
    const sameClub = players.filter(p => p.club === player.club).length;
    if (sameClub >= 3) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Maximum 3 players from the same club' });
    }

    players.push({ id: player.id, name: player.name, position: player.position, club: player.club, price: player.price });
    const newBudget = parseFloat(team.budget) - parseFloat(player.price);

    await client.query(
      'UPDATE teams SET players = $1, budget = $2, updated_at = NOW() WHERE id = $3',
      [JSON.stringify(players), newBudget, team.id]
    );

    await client.query('COMMIT');
    await cacheDel(`team:${team.id}`);

    res.json({ message: 'Player added', budget: newBudget, players });
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

// DELETE /api/fantasy-team/my-team/players/:playerId — Remove a player
router.delete('/my-team/players/:playerId', authenticate, async (req, res, next) => {
  const client = await pool.connect();
  try {
    const { playerId } = req.params;
    const { leagueId } = req.query;

    await client.query('BEGIN');

    const teamResult = await client.query(
      'SELECT * FROM teams WHERE user_id = $1 AND league_id = $2 FOR UPDATE',
      [req.user.id, leagueId]
    );

    if (teamResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Team not found' });
    }

    const team = teamResult.rows[0];
    let players = team.players || [];
    if (typeof players === 'string') players = JSON.parse(players);

    const playerIndex = players.findIndex(p => (typeof p === 'string' ? p : p.id) === playerId);
    if (playerIndex === -1) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Player not in team' });
    }

    const removed = players.splice(playerIndex, 1)[0];
    const refund = typeof removed === 'object' ? parseFloat(removed.price) || 0 : 0;
    const newBudget = parseFloat(team.budget) + refund;

    await client.query(
      'UPDATE teams SET players = $1, budget = $2, updated_at = NOW() WHERE id = $3',
      [JSON.stringify(players), newBudget, team.id]
    );

    await client.query('COMMIT');
    await cacheDel(`team:${team.id}`);

    res.json({ message: 'Player removed', budget: newBudget, players });
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
});

module.exports = router;
