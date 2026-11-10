/**
 * Predictions Controller — Communautaires WC 2026
 * Les utilisateurs prédisent avant chaque gameweek :
 *   - le meilleur buteur (joueur)
 *   - la nation qui va le mieux scorer
 *   - le nombre total de buts dans la GW
 * Bonus points attribués une fois la GW terminée.
 */

const { pool } = require('../config/db');
const { cacheGet, cacheSet, cacheDel } = require('../config/cache');

// Bonus points
const BONUS = {
  top_scorer_correct: 10,   // bonne prédiction du buteur
  winner_nation_correct: 8, // bonne nation
  goals_exact: 6,           // nombre exact de buts
  goals_close: 2,           // ±1 but
};

// POST /api/predictions — soumettre une prédiction
async function submitPrediction(req, res, next) {
  try {
    const { gameweekId, predictedTopScorer, predictedWinnerNation, predictedGoals } = req.body;
    if (!gameweekId) return res.status(400).json({ error: 'gameweekId required' });

    // Check gameweek exists and hasn't started yet
    const gwRes = await pool.query('SELECT status FROM gameweeks WHERE id = $1', [gameweekId]);
    if (gwRes.rows.length === 0) return res.status(404).json({ error: 'Gameweek not found' });
    if (gwRes.rows[0].status === 'completed') {
      return res.status(400).json({ error: 'Cannot predict on a completed gameweek' });
    }

    const result = await pool.query(
      `INSERT INTO predictions
         (user_id, gameweek_id, predicted_top_scorer, predicted_winner_nation, predicted_goals)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (user_id, gameweek_id) DO UPDATE SET
         predicted_top_scorer   = EXCLUDED.predicted_top_scorer,
         predicted_winner_nation = EXCLUDED.predicted_winner_nation,
         predicted_goals        = EXCLUDED.predicted_goals,
         updated_at             = NOW()
       RETURNING *`,
      [req.user.id, gameweekId, predictedTopScorer || null,
       predictedWinnerNation || null, predictedGoals || null]
    );

    await cacheDel(`predictions:gw:${gameweekId}`);
    res.status(201).json(result.rows[0]);
  } catch (err) {
    next(err);
  }
}

// GET /api/predictions/gameweek/:gwId — mes prédictions + stats communautaires
async function getGameweekPredictions(req, res, next) {
  try {
    const { gwId } = req.params;
    const cacheKey = `predictions:gw:${gwId}`;
    const cached = await cacheGet(cacheKey);
    if (cached) {
      const data = JSON.parse(cached);
      // Attach personal prediction
      const myPred = await pool.query(
        'SELECT * FROM predictions WHERE user_id = $1 AND gameweek_id = $2',
        [req.user.id, gwId]
      );
      return res.json({ ...data, myPrediction: myPred.rows[0] || null });
    }

    // Community stats — most predicted top scorer
    const topScorerStats = await pool.query(
      `SELECT p.id, p.name, p.club, p.nationality, COUNT(*) as votes
       FROM predictions pr
       JOIN players p ON pr.predicted_top_scorer = p.id
       WHERE pr.gameweek_id = $1 AND pr.predicted_top_scorer IS NOT NULL
       GROUP BY p.id, p.name, p.club, p.nationality
       ORDER BY votes DESC
       LIMIT 5`,
      [gwId]
    );

    // Most predicted winner nation
    const nationStats = await pool.query(
      `SELECT predicted_winner_nation as nation, COUNT(*) as votes
       FROM predictions
       WHERE gameweek_id = $1 AND predicted_winner_nation IS NOT NULL
       GROUP BY predicted_winner_nation
       ORDER BY votes DESC
       LIMIT 5`,
      [gwId]
    );

    // Average predicted goals
    const goalsStats = await pool.query(
      `SELECT ROUND(AVG(predicted_goals), 1) as avg_goals, COUNT(*) as total_predictions
       FROM predictions
       WHERE gameweek_id = $1 AND predicted_goals IS NOT NULL`,
      [gwId]
    );

    const community = {
      topScorerVotes: topScorerStats.rows,
      nationVotes: nationStats.rows,
      avgPredictedGoals: goalsStats.rows[0]?.avg_goals || 0,
      totalPredictions: parseInt(goalsStats.rows[0]?.total_predictions || 0),
    };

    await cacheSet(cacheKey, JSON.stringify(community), 120); // cache 2 min

    const myPred = await pool.query(
      'SELECT * FROM predictions WHERE user_id = $1 AND gameweek_id = $2',
      [req.user.id, gwId]
    );

    res.json({ community, myPrediction: myPred.rows[0] || null });
  } catch (err) {
    next(err);
  }
}

// GET /api/predictions/leaderboard — classement des meilleurs prédicteurs
async function getPredictionLeaderboard(req, res, next) {
  try {
    const result = await pool.query(
      `SELECT u.id, u.username, u.avatar_url,
              COALESCE(SUM(pr.bonus_points), 0) as prediction_points,
              COUNT(pr.id) as total_predictions,
              COUNT(pr.id) FILTER (WHERE pr.resolved = true AND pr.bonus_points > 0) as correct_predictions
       FROM users u
       LEFT JOIN predictions pr ON pr.user_id = u.id
       GROUP BY u.id, u.username, u.avatar_url
       ORDER BY prediction_points DESC, correct_predictions DESC
       LIMIT 20`,
    );
    res.json(result.rows);
  } catch (err) {
    next(err);
  }
}

// POST /api/predictions/resolve/:gwId — résoudre les prédictions après une GW (admin)
async function resolvePredictions(req, res, next) {
  try {
    const { gwId } = req.params;
    const { actualTopScorerId, actualWinnerNation, actualTotalGoals } = req.body;

    const preds = await pool.query(
      'SELECT * FROM predictions WHERE gameweek_id = $1 AND resolved = false',
      [gwId]
    );

    let resolved = 0;
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      for (const pred of preds.rows) {
        let bonus = 0;

        if (actualTopScorerId && pred.predicted_top_scorer === actualTopScorerId) {
          bonus += BONUS.top_scorer_correct;
        }
        if (actualWinnerNation && pred.predicted_winner_nation === actualWinnerNation) {
          bonus += BONUS.winner_nation_correct;
        }
        if (actualTotalGoals !== undefined && pred.predicted_goals !== null) {
          const diff = Math.abs(actualTotalGoals - pred.predicted_goals);
          if (diff === 0) bonus += BONUS.goals_exact;
          else if (diff === 1) bonus += BONUS.goals_close;
        }

        await client.query(
          `UPDATE predictions SET bonus_points = $1, resolved = true WHERE id = $2`,
          [bonus, pred.id]
        );

        if (bonus > 0) {
          await client.query(
            `UPDATE users SET total_points = total_points + $1 WHERE id = $2`,
            [bonus, pred.user_id]
          );
        }

        resolved++;
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    await cacheDel(`predictions:gw:${gwId}`);
    res.json({ message: `${resolved} predictions resolved`, gameweekId: gwId });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  submitPrediction,
  getGameweekPredictions,
  getPredictionLeaderboard,
  resolvePredictions,
};
