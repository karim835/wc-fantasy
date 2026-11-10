const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middlewares/auth');
const {
  getGameweeks,
  getCurrentGameweek,
  getGameweek,
  createGameweek,
  startGameweek,
  finishGameweek,
  getGameweekScores,
  submitPlayerScores,
  getGameweekTeamScores,
  generateBattles,
  getMyBreakdown,
} = require('../controllers/gameweek.controller');

router.use(authenticate);

/**
 * @swagger
 * tags:
 *   name: Gameweeks
 *   description: Gameweek management and scoring
 */

/**
 * @swagger
 * /api/gameweeks:
 *   get:
 *     summary: List all gameweeks ordered by number descending
 *     tags: [Gameweeks]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Array of gameweek objects
 *       401:
 *         description: Unauthorized
 */
router.get('/',            getGameweeks);

/**
 * @swagger
 * /api/gameweeks/current:
 *   get:
 *     summary: Get the current active or next upcoming gameweek
 *     tags: [Gameweeks]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Current gameweek object, or null if none found
 *       401:
 *         description: Unauthorized
 */
router.get('/current',     getCurrentGameweek);

/**
 * @swagger
 * /api/gameweeks/{gwId}:
 *   get:
 *     summary: Get a specific gameweek by ID
 *     tags: [Gameweeks]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: gwId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Gameweek object
 *       404:
 *         description: Gameweek not found
 */
router.get('/:gwId',       getGameweek);

/**
 * @swagger
 * /api/gameweeks:
 *   post:
 *     summary: Create a new gameweek (admin)
 *     tags: [Gameweeks]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [number]
 *             properties:
 *               number:
 *                 type: integer
 *               season:
 *                 type: string
 *                 example: "2025-26"
 *               deadline:
 *                 type: string
 *                 format: date-time
 *     responses:
 *       201:
 *         description: Gameweek created
 *       401:
 *         description: Unauthorized
 */
router.post('/',           requireAdmin, createGameweek);

/**
 * @swagger
 * /api/gameweeks/{gwId}/start:
 *   patch:
 *     summary: Start a gameweek (sets it to active, closes any previously active GW)
 *     tags: [Gameweeks]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: gwId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Gameweek started
 *       404:
 *         description: Gameweek not found
 */
router.patch('/:gwId/start', requireAdmin, startGameweek);

/**
 * @swagger
 * /api/gameweeks/{gwId}/finish:
 *   patch:
 *     summary: Finish an active gameweek, recalculate points and resolve battles
 *     tags: [Gameweeks]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: gwId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Gameweek finished with battle resolution summary
 *       400:
 *         description: Gameweek not found or not active
 */
router.patch('/:gwId/finish',  requireAdmin, finishGameweek);

/**
 * @swagger
 * /api/gameweeks/{gwId}/scores:
 *   get:
 *     summary: Get all player scores for a gameweek
 *     tags: [Gameweeks]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: gwId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Array of player score objects
 */
router.get('/:gwId/scores',        getGameweekScores);

/**
 * @swagger
 * /api/gameweeks/{gwId}/scores:
 *   post:
 *     summary: Submit player scores for a gameweek (admin)
 *     tags: [Gameweeks]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: gwId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [scores]
 *             properties:
 *               scores:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     playerId:
 *                       type: string
 *                     goals:
 *                       type: integer
 *                     assists:
 *                       type: integer
 *                     minutesPlayed:
 *                       type: integer
 *     responses:
 *       201:
 *         description: Scores submitted successfully
 *       400:
 *         description: Invalid request or gameweek not active
 */
router.post('/:gwId/scores',       requireAdmin, submitPlayerScores);

/**
 * @swagger
 * /api/gameweeks/{gwId}/team-scores:
 *   get:
 *     summary: Get ranked team scores for a specific gameweek
 *     tags: [Gameweeks]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: gwId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Array of team scores with rank
 */
router.get('/:gwId/team-scores',   getGameweekTeamScores);

// A user's own per-player points breakdown for a gameweek
router.get('/:gwId/my-breakdown',  getMyBreakdown);

/**
 * @swagger
 * /api/gameweeks/generate-battles:
 *   post:
 *     summary: Generate H2H battles for a gameweek using round-robin matchmaking
 *     tags: [Gameweeks]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [gwId, leagueId]
 *             properties:
 *               gwId:
 *                 type: string
 *                 format: uuid
 *               leagueId:
 *                 type: string
 *                 format: uuid
 *     responses:
 *       201:
 *         description: Battles generated
 *       400:
 *         description: Missing parameters or not enough teams
 */
// Owner-or-admin: the permission check lives inside the controller so a league
// owner can generate battles for their own league, while admins can do any.
router.post('/generate-battles',   generateBattles);

module.exports = router;
