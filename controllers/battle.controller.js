const { pool } = require('../config/db');
const { cacheGet, cacheSet } = require('../config/cache');
const { getIO } = require('../socket/socket');

async function getBattles(req, res, next) {
  try {
    const { leagueId } = req.params;
    const cacheKey = `battles:${leagueId}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const result = await pool.query(
      `SELECT b.*,
        th.name as home_team_name, th.user_id as home_user_id,
        ta.name as away_team_name, ta.user_id as away_user_id,
        uh.username as home_username, ua.username as away_username
       FROM battles b
       JOIN teams th ON b.home_team_id = th.id
       JOIN teams ta ON b.away_team_id = ta.id
       JOIN users uh ON th.user_id = uh.id
       JOIN users ua ON ta.user_id = ua.id
       WHERE b.league_id = $1
       ORDER BY b.created_at DESC`,
      [leagueId]
    );

    await cacheSet(cacheKey, result.rows, 60);
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
}

async function getBattle(req, res, next) {
  try {
    const { battleId } = req.params;

    // 1. Fetch battle + team info including captain_id and usernames
    const result = await pool.query(
      `SELECT b.*,
        th.name as home_team_name, th.players as home_players, th.captain_id as home_captain_id,
        ta.name as away_team_name, ta.players as away_players, ta.captain_id as away_captain_id,
        uh.username as home_username, ua.username as away_username
       FROM battles b
       JOIN teams th ON b.home_team_id = th.id
       JOIN teams ta ON b.away_team_id = ta.id
       JOIN users uh ON th.user_id = uh.id
       JOIN users ua ON ta.user_id = ua.id
       WHERE b.id = $1`,
      [battleId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Battle not found' });
    }

    const battle = result.rows[0];

    // 2. Resolve gameweek_id from gameweeks table using battle.gameweek number
    let gameweekId = null;
    if (battle.gameweek != null) {
      const gwResult = await pool.query(
        `SELECT id FROM gameweeks WHERE number = $1 ORDER BY created_at DESC LIMIT 1`,
        [battle.gameweek]
      );
      if (gwResult.rows.length > 0) {
        gameweekId = gwResult.rows[0].id;
      }
    }

    // 3. Fetch player scores for this gameweek (all players from both teams in one query)
    const homePlayers = Array.isArray(battle.home_players) ? battle.home_players : [];
    const awayPlayers = Array.isArray(battle.away_players) ? battle.away_players : [];
    const allPlayerIds = [
      ...homePlayers.map((p) => p.id),
      ...awayPlayers.map((p) => p.id),
    ].filter(Boolean);

    let scoresMap = {};
    if (gameweekId && allPlayerIds.length > 0) {
      const scoresResult = await pool.query(
        `SELECT player_id, total_points, goals, assists, clean_sheet,
                yellow_cards, red_cards, minutes_played, bonus,
                own_goals, penalties_saved, penalties_missed
         FROM player_scores
         WHERE gameweek_id = $1 AND player_id = ANY($2::uuid[])`,
        [gameweekId, allPlayerIds]
      );
      for (const row of scoresResult.rows) {
        scoresMap[row.player_id] = row;
      }
    }

    // 4. Build enriched player arrays
    const homeCaptainId = battle.home_captain_id;
    const awayCaptainId = battle.away_captain_id;

    const enrichedHomePlayers = homePlayers.map((p) => {
      const s = scoresMap[p.id] || {};
      return {
        id: p.id,
        name: p.name,
        position: p.position,
        club: p.club,
        gw_points: s.total_points ?? 0,
        goals: s.goals ?? 0,
        assists: s.assists ?? 0,
        clean_sheet: s.clean_sheet ?? false,
        yellow_cards: s.yellow_cards ?? 0,
        red_cards: s.red_cards ?? 0,
        minutes_played: s.minutes_played ?? 0,
        own_goals: s.own_goals ?? 0,
        penalties_saved: s.penalties_saved ?? 0,
        penalties_missed: s.penalties_missed ?? 0,
        isCaptain: p.id === homeCaptainId,
      };
    });

    const enrichedAwayPlayers = awayPlayers.map((p) => {
      const s = scoresMap[p.id] || {};
      return {
        id: p.id,
        name: p.name,
        position: p.position,
        club: p.club,
        gw_points: s.total_points ?? 0,
        goals: s.goals ?? 0,
        assists: s.assists ?? 0,
        clean_sheet: s.clean_sheet ?? false,
        yellow_cards: s.yellow_cards ?? 0,
        red_cards: s.red_cards ?? 0,
        minutes_played: s.minutes_played ?? 0,
        own_goals: s.own_goals ?? 0,
        penalties_saved: s.penalties_saved ?? 0,
        penalties_missed: s.penalties_missed ?? 0,
        isCaptain: p.id === awayCaptainId,
      };
    });

    // 5. Return composed response
    const { home_players, away_players, home_captain_id, away_captain_id, ...battleFields } = battle;
    res.json({
      ...battleFields,
      home_players: enrichedHomePlayers,
      away_players: enrichedAwayPlayers,
    });
  } catch (err) {
    next(err);
  }
}

async function scheduleBattle(req, res, next) {
  try {
    const { leagueId } = req.params;
    const { homeTeamId, awayTeamId, gameweek, playedAt } = req.body;

    const result = await pool.query(
      `INSERT INTO battles (league_id, home_team_id, away_team_id, gameweek, played_at)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [leagueId, homeTeamId, awayTeamId, gameweek, playedAt]
    );

    const io = getIO();
    io.to(`league:${leagueId}`).emit('battle:scheduled', result.rows[0]);

    res.status(201).json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

async function updateScore(req, res, next) {
  try {
    const { battleId } = req.params;
    const { homeScore, awayScore, status } = req.body;

    const result = await pool.query(
      `UPDATE battles SET home_score = $1, away_score = $2, status = COALESCE($3, status)
       WHERE id = $4 RETURNING *`,
      [homeScore, awayScore, status, battleId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Battle not found' });
    }

    const battle = result.rows[0];
    const io = getIO();
    io.to(`league:${battle.league_id}`).emit('battle:score_update', battle);

    res.json(battle);
  } catch (err) {
    next(err);
  }
}

async function getLiveScore(req, res, next) {
  try {
    const { battleId } = req.params;
    const cacheKey = `battle:live:${battleId}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const result = await pool.query(
      'SELECT id, home_score, away_score, status, gameweek FROM battles WHERE id = $1',
      [battleId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Battle not found' });
    }

    await cacheSet(cacheKey, result.rows[0], 10);
    res.json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

module.exports = { getBattles, getBattle, scheduleBattle, updateScore, getLiveScore };
