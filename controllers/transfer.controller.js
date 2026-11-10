const { pool } = require('../config/db');
const axios = require('axios');

async function getTransferSuggestions(req, res, next) {
  try {
    const { leagueId } = req.params;

    const teamResult = await pool.query(
      'SELECT * FROM teams WHERE user_id = $1 AND league_id = $2',
      [req.user.id, leagueId]
    );

    if (teamResult.rows.length === 0) {
      return res.status(404).json({ error: 'Team not found' });
    }

    const team = teamResult.rows[0];

    try {
      const aiResponse = await axios.post(`${process.env.AI_SERVICE_URL}/transfer-suggestion`, {
        team_players: team.players,
        budget: team.budget,
        formation: team.formation,
      });
      res.json(aiResponse.data);
    } catch (aiErr) {
      if (aiErr.code === 'ECONNREFUSED') {
        return res.status(503).json({ error: 'AI service unavailable' });
      }
      throw aiErr;
    }
  } catch (err) {
    next(err);
  }
}

async function getRiskScore(req, res, next) {
  try {
    const { playerId } = req.params;

    const playerResult = await pool.query(
      'SELECT * FROM players WHERE id = $1',
      [playerId]
    );

    if (playerResult.rows.length === 0) {
      return res.status(404).json({ error: 'Player not found' });
    }

    const player = playerResult.rows[0];

    try {
      const aiResponse = await axios.post(`${process.env.AI_SERVICE_URL}/risk-score`, {
        player_id: player.id,
        player_stats: player.stats,
        injury_status: player.injury_status,
        form: player.form,
      });
      res.json({ player, risk: aiResponse.data });
    } catch (aiErr) {
      if (aiErr.code === 'ECONNREFUSED') {
        return res.status(503).json({ error: 'AI service unavailable' });
      }
      throw aiErr;
    }
  } catch (err) {
    next(err);
  }
}

async function makeTransfer(req, res, next) {
  try {
    const { leagueId } = req.params;
    const { playerOutId, playerInId } = req.body;

    const [teamResult, playerOutResult, playerInResult] = await Promise.all([
      pool.query('SELECT * FROM teams WHERE user_id = $1 AND league_id = $2', [req.user.id, leagueId]),
      pool.query('SELECT * FROM players WHERE id = $1', [playerOutId]),
      pool.query('SELECT * FROM players WHERE id = $1', [playerInId]),
    ]);

    if (teamResult.rows.length === 0) return res.status(404).json({ error: 'Team not found' });
    if (playerOutResult.rows.length === 0) return res.status(404).json({ error: 'Player out not found' });
    if (playerInResult.rows.length === 0) return res.status(404).json({ error: 'Player in not found' });

    const team = teamResult.rows[0];
    const playerOut = playerOutResult.rows[0];
    const playerIn = playerInResult.rows[0];

    const hasPlayerOut = (team.players || []).some((p) => p.id === playerOutId);
    if (!hasPlayerOut) return res.status(400).json({ error: 'Player not in team' });

    const newBudget = parseFloat(team.budget) + parseFloat(playerOut.price) - parseFloat(playerIn.price);
    if (newBudget < 0) {
      const shortfall = Math.abs(newBudget).toFixed(1);
      return res.status(400).json({ error: `Insufficient budget — you need ${shortfall} M€ more` });
    }

    // Rich snapshot so the pitch builder renders photo + price without refetch (matches pickPlayer).
    const updatedPlayers = (team.players || [])
      .filter((p) => p.id !== playerOutId)
      .concat({
        id: playerIn.id, name: playerIn.name, position: playerIn.position,
        price: playerIn.price, photo_url: playerIn.photo_url, club: playerIn.club,
      });

    const result = await pool.query(
      'UPDATE teams SET players = $1, budget = $2, updated_at = NOW() WHERE id = $3 RETURNING *',
      [JSON.stringify(updatedPlayers), newBudget, team.id]
    );

    res.json({ team: result.rows[0], transfer: { out: playerOut, in: playerIn } });
  } catch (err) {
    next(err);
  }
}

module.exports = { getTransferSuggestions, getRiskScore, makeTransfer };
