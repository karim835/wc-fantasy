const { pool } = require('../config/db');
const { cacheGet, cacheSet, cacheDel } = require('../config/cache');

async function getMyTeam(req, res, next) {
  try {
    const { leagueId } = req.params;
    const result = await pool.query(
      'SELECT * FROM teams WHERE user_id = $1 AND league_id = $2',
      [req.user.id, leagueId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Team not found' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

async function createTeam(req, res, next) {
  try {
    const { leagueId } = req.params;
    const { name, formation } = req.body;

    const existing = await pool.query(
      'SELECT id FROM teams WHERE user_id = $1 AND league_id = $2',
      [req.user.id, leagueId]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Team already exists for this league' });
    }

    const result = await pool.query(
      `INSERT INTO teams (user_id, league_id, name, formation)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [req.user.id, leagueId, name, formation || '4-3-3']
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

// PATCH /api/drafts/leagues/:leagueId/team — rename and/or change formation
async function updateTeam(req, res, next) {
  try {
    const { leagueId } = req.params;
    const { name, formation } = req.body;
    const result = await pool.query(
      `UPDATE teams SET
         name = COALESCE($1, name),
         formation = COALESCE($2, formation),
         updated_at = NOW()
       WHERE user_id = $3 AND league_id = $4
       RETURNING *`,
      [name || null, formation || null, req.user.id, leagueId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Team not found' });
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

// DELETE /api/drafts/leagues/:leagueId/team/players — clear the whole squad, refund budget
async function clearTeamPlayers(req, res, next) {
  try {
    const { leagueId } = req.params;
    const result = await pool.query(
      `UPDATE teams SET players = '[]', budget = 100.0, captain_id = NULL, updated_at = NOW()
       WHERE user_id = $1 AND league_id = $2
       RETURNING *`,
      [req.user.id, leagueId]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Team not found' });
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

async function pickPlayer(req, res, next) {
  try {
    const { leagueId } = req.params;
    const { playerId } = req.body;

    const [teamResult, playerResult] = await Promise.all([
      pool.query('SELECT * FROM teams WHERE user_id = $1 AND league_id = $2', [req.user.id, leagueId]),
      pool.query('SELECT * FROM players WHERE id = $1', [playerId]),
    ]);

    if (teamResult.rows.length === 0) return res.status(404).json({ error: 'Team not found' });
    if (playerResult.rows.length === 0) return res.status(404).json({ error: 'Player not found' });

    const team = teamResult.rows[0];
    const player = playerResult.rows[0];
    const currentPlayers = team.players || [];

    // Position limits: 2 GK, 5 DEF, 5 MID, 3 FWD
    const POSITION_LIMITS = { GK: 2, DEF: 5, MID: 5, FWD: 3 };
    const positionCount = currentPlayers.filter(p => p.position === player.position).length;
    const positionLimit = POSITION_LIMITS[player.position] || 5;

    if (currentPlayers.length >= 15) {
      return res.status(400).json({ error: 'Team is full (max 15 players)' });
    }
    if (currentPlayers.some((p) => p.id === playerId)) {
      return res.status(400).json({ error: 'Player already in team' });
    }
    if (positionCount >= positionLimit) {
      return res.status(400).json({
        error: `Max ${positionLimit} ${player.position} players allowed`,
      });
    }
    if (team.budget < player.price) {
      return res.status(400).json({ error: 'Insufficient budget' });
    }

    // Store a richer snapshot so the pitch builder can render photo + price
    // straight from the team without re-fetching each player.
    const updatedPlayers = [...currentPlayers, {
      id: player.id,
      name: player.name,
      position: player.position,
      price: player.price,
      photo_url: player.photo_url,
      club: player.club,
    }];
    const result = await pool.query(
      'UPDATE teams SET players = $1, budget = budget - $2, updated_at = NOW() WHERE id = $3 RETURNING *',
      [JSON.stringify(updatedPlayers), player.price, team.id]
    );

    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

async function removePlayer(req, res, next) {
  try {
    const { leagueId, playerId } = req.params;

    const teamResult = await pool.query(
      'SELECT * FROM teams WHERE user_id = $1 AND league_id = $2',
      [req.user.id, leagueId]
    );
    if (teamResult.rows.length === 0) return res.status(404).json({ error: 'Team not found' });

    const team = teamResult.rows[0];
    const player = await pool.query('SELECT price FROM players WHERE id = $1', [playerId]);
    const playerPrice = player.rows[0]?.price || 0;

    const updatedPlayers = (team.players || []).filter((p) => p.id !== playerId);
    const result = await pool.query(
      'UPDATE teams SET players = $1, budget = budget + $2, updated_at = NOW() WHERE id = $3 RETURNING *',
      [JSON.stringify(updatedPlayers), playerPrice, team.id]
    );

    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

// Position limits mirrored from pickPlayer: 2 GK, 5 DEF, 5 MID, 3 FWD (15-man squad)
const AUTO_PICK_LIMITS = { GK: 2, DEF: 5, MID: 5, FWD: 3 };

// Builds a budget-constrained squad suggestion locally — fills each position's
// remaining slots with the best points-per-price players still affordable.
// No external AI service involved; this is a deterministic greedy heuristic.
async function autoPick(req, res, next) {
  try {
    const { leagueId } = req.params;
    const { budget, formation } = req.body;

    const teamResult = await pool.query(
      'SELECT * FROM teams WHERE user_id = $1 AND league_id = $2',
      [req.user.id, leagueId]
    );
    if (teamResult.rows.length === 0) return res.status(404).json({ error: 'Team not found' });

    const team = teamResult.rows[0];
    const ownedPlayers = team.players || [];
    const ownedIds = ownedPlayers.map((p) => p.id);
    let remainingBudget = Number(budget ?? team.budget);

    const suggested = [];
    for (const [position, limit] of Object.entries(AUTO_PICK_LIMITS)) {
      const ownedCount = ownedPlayers.filter((p) => p.position === position).length;
      const slotsToFill = limit - ownedCount;
      if (slotsToFill <= 0) continue;

      const candidatesRes = await pool.query(
        `SELECT id, name, position, price::float AS price, points, photo_url, club
         FROM players
         WHERE position = $1 ${ownedIds.length ? 'AND id <> ALL($2::uuid[])' : ''}
         ORDER BY (points::float / GREATEST(price::float, 0.1)) DESC
         LIMIT 30`,
        ownedIds.length ? [position, ownedIds] : [position]
      );

      let picked = 0;
      for (const candidate of candidatesRes.rows) {
        if (picked >= slotsToFill) break;
        if (candidate.price > remainingBudget) continue;
        suggested.push(candidate);
        remainingBudget -= candidate.price;
        picked += 1;
      }
    }

    const ownedPointsRes = ownedIds.length
      ? await pool.query('SELECT id, points FROM players WHERE id = ANY($1::uuid[])', [ownedIds])
      : { rows: [] };
    const ownedPoints = ownedPointsRes.rows.reduce((sum, p) => sum + (p.points || 0), 0);
    const suggestedPoints = suggested.reduce((sum, p) => sum + (p.points || 0), 0);

    // Persist: append the suggested players to the squad (richer snapshot, same
    // shape pickPlayer stores) and deduct their cost from the budget so the
    // pitch reflects the auto-pick immediately on reload.
    const newSquad = [
      ...ownedPlayers,
      ...suggested.map((p) => ({
        id: p.id,
        name: p.name,
        position: p.position,
        price: p.price,
        photo_url: p.photo_url,
        club: p.club,
      })),
    ];
    await pool.query(
      'UPDATE teams SET players = $1, budget = $2, updated_at = NOW() WHERE id = $3',
      [JSON.stringify(newSquad), Math.round(remainingBudget * 10) / 10, team.id]
    );

    res.json({
      suggestion: {
        formation: formation || team.formation || '4-3-3',
        expected_points: ownedPoints + suggestedPoints,
        budget_remaining: Math.round(remainingBudget * 10) / 10,
        players: suggested,
      },
    });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/draft/leagues/:leagueId/team/captain
async function setCaptain(req, res, next) {
  try {
    const { leagueId } = req.params;
    const { playerId } = req.body;
    if (!playerId) return res.status(400).json({ error: 'playerId required' });

    // Verify team belongs to user and player is in the team
    const teamRes = await pool.query(
      'SELECT id, players FROM teams WHERE user_id = $1 AND league_id = $2',
      [req.user.id, leagueId]
    );
    if (teamRes.rows.length === 0) return res.status(404).json({ error: 'Team not found' });

    const team = teamRes.rows[0];
    const playerInTeam = (team.players || []).some(p => p.id === playerId);
    if (!playerInTeam) return res.status(400).json({ error: 'Player not in your team' });

    await pool.query(
      'UPDATE teams SET captain_id = $1, updated_at = NOW() WHERE id = $2',
      [playerId, team.id]
    );

    const player = await pool.query('SELECT name, position FROM players WHERE id = $1', [playerId]);

    res.json({
      message: `${player.rows[0]?.name || 'Player'} is now your captain (x2 points)`,
      captainId: playerId,
    });
  } catch (err) {
    next(err);
  }
}

// PATCH /api/drafts/leagues/:leagueId/team/chip — arm a chip for the current gameweek
const VALID_CHIPS = ['triple_captain', 'super_sub', 'shield'];
async function armChip(req, res, next) {
  try {
    const { leagueId } = req.params;
    const { chip, boostPlayerId } = req.body;
    if (!VALID_CHIPS.includes(chip)) {
      return res.status(400).json({ error: 'Invalid chip' });
    }

    const teamRes = await pool.query(
      'SELECT * FROM teams WHERE user_id = $1 AND league_id = $2',
      [req.user.id, leagueId]
    );
    if (teamRes.rows.length === 0) return res.status(404).json({ error: 'Team not found' });
    const team = teamRes.rows[0];

    // Each chip is usable once per tournament.
    const used = Array.isArray(team.chips_used) ? team.chips_used : [];
    if (used.some((c) => c.chip === chip)) {
      return res.status(400).json({ error: 'Chip already used' });
    }

    // Arm it for the active/next gameweek.
    const gwRes = await pool.query(
      `SELECT number FROM gameweeks WHERE status IN ('active','upcoming')
       ORDER BY CASE status WHEN 'active' THEN 0 ELSE 1 END, number ASC LIMIT 1`
    );
    if (gwRes.rows.length === 0) return res.status(400).json({ error: 'No active or upcoming gameweek' });
    const gwNumber = gwRes.rows[0].number;

    let boost = null;
    if (chip === 'super_sub') {
      if (!boostPlayerId) return res.status(400).json({ error: 'boostPlayerId required for Super Sub' });
      const inTeam = (team.players || []).some((p) => p.id === boostPlayerId);
      if (!inTeam) return res.status(400).json({ error: 'Boost player not in your team' });
      boost = boostPlayerId;
    }

    const result = await pool.query(
      `UPDATE teams SET active_chip = $1, active_chip_gw = $2, boost_player_id = $3, updated_at = NOW()
       WHERE id = $4 RETURNING active_chip, active_chip_gw, boost_player_id, chips_used`,
      [chip, gwNumber, boost, team.id]
    );

    res.json({ message: 'Chip armed', team: result.rows[0], gameweek: gwNumber });
  } catch (err) {
    next(err);
  }
}

module.exports = { getMyTeam, createTeam, updateTeam, clearTeamPlayers, pickPlayer, removePlayer, autoPick, setCaptain, armChip };
