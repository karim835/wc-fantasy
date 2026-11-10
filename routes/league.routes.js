const express = require('express');
const { body } = require('express-validator');
const router = express.Router();
const { authenticate, isLeagueOwner } = require('../middlewares/auth');
const validate = require('../middlewares/validate');
const {
  getLeagues, createLeague, getLeague, joinLeague, getLeaderboard, getMemberTeam,
  leaveLeague, updateLeague, deleteLeague, kickMember, getPublicLeagues, joinPublicLeague,
} = require('../controllers/league.controller');

router.use(authenticate);

// Discover public leagues — MUST be registered before '/:leagueId' so 'public' isn't captured as an id.
router.get('/public', getPublicLeagues);

/**
 * @swagger
 * tags:
 *   name: Leagues
 *   description: Fantasy league management
 */

/**
 * @swagger
 * /api/leagues:
 *   get:
 *     summary: Get all leagues the authenticated user belongs to
 *     tags: [Leagues]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Array of league objects
 *       401:
 *         description: Unauthorized
 */
router.get('/', getLeagues);

/**
 * @swagger
 * /api/leagues:
 *   post:
 *     summary: Create a new league
 *     tags: [Leagues]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name]
 *             properties:
 *               name:
 *                 type: string
 *                 maxLength: 100
 *               max_members:
 *                 type: integer
 *                 default: 10
 *               is_private:
 *                 type: boolean
 *                 default: false
 *               season:
 *                 type: string
 *                 example: "2025-26"
 *     responses:
 *       201:
 *         description: League created with invite code
 *       401:
 *         description: Unauthorized
 */
router.post('/', [
  body('name').trim().notEmpty().isLength({ min: 3, max: 100 }).withMessage('League name must be 3-100 characters'),
  body('max_members').optional().isInt({ min: 2, max: 32 }).withMessage('max_members must be between 2 and 32'),
  body('is_private').optional().isBoolean().withMessage('is_private must be a boolean'),
  body('season').optional().isLength({ max: 20 }).withMessage('season max 20 characters'),
], validate, createLeague);

/**
 * @swagger
 * /api/leagues/{leagueId}:
 *   get:
 *     summary: Get details of a specific league
 *     tags: [Leagues]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: leagueId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: League details including members
 *       404:
 *         description: League not found
 */
router.get('/:leagueId', getLeague);

/**
 * @swagger
 * /api/leagues/join:
 *   post:
 *     summary: Join a league using an invite code
 *     tags: [Leagues]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [invite_code]
 *             properties:
 *               invite_code:
 *                 type: string
 *     responses:
 *       200:
 *         description: Successfully joined the league
 *       404:
 *         description: Invalid invite code
 *       409:
 *         description: Already a member or league is full
 */
router.post('/join', [
  body('invite_code').trim().notEmpty().isLength({ min: 4, max: 20 }).withMessage('Valid invite code required'),
], validate, joinLeague);

/**
 * @swagger
 * /api/leagues/{leagueId}/leaderboard:
 *   get:
 *     summary: Get the points leaderboard for a league
 *     tags: [Leagues]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: leagueId
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       200:
 *         description: Ranked list of league members with points
 *       404:
 *         description: League not found
 */
router.get('/:leagueId/leaderboard', getLeaderboard);

// ── Round 6: membership, owner controls, public join, member team ──
router.delete('/:leagueId/leave', leaveLeague);
router.post('/:leagueId/join-public', joinPublicLeague);
router.get('/:leagueId/members/:userId/team', getMemberTeam);

// Owner-only
router.patch('/:leagueId', [
  body('name').optional().trim().isLength({ min: 3, max: 100 }),
  body('max_members').optional().isInt({ min: 2, max: 32 }),
  body('is_private').optional().isBoolean(),
], validate, isLeagueOwner, updateLeague);
router.delete('/:leagueId', isLeagueOwner, deleteLeague);
router.delete('/:leagueId/members/:userId', isLeagueOwner, kickMember);

module.exports = router;
