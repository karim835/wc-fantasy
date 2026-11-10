const express = require('express');
const { body } = require('express-validator');
const router = express.Router();
const { authenticate } = require('../middlewares/auth');
const validate = require('../middlewares/validate');
const {
  getBattles, getBattle, scheduleBattle, updateScore, getLiveScore,
} = require('../controllers/battle.controller');

router.use(authenticate);

router.get('/leagues/:leagueId/battles', getBattles);

router.post('/leagues/:leagueId/battles', [
  body('homeTeamId').isUUID().withMessage('homeTeamId must be a valid team ID'),
  body('awayTeamId').isUUID().withMessage('awayTeamId must be a valid team ID'),
  body('gameweek').isInt({ min: 1 }).withMessage('gameweek must be a positive integer'),
], validate, scheduleBattle);

router.get('/battles/:battleId', getBattle);
router.get('/battles/:battleId/live', getLiveScore);

router.patch('/battles/:battleId/score', [
  body('homeScore').isInt({ min: 0 }).withMessage('homeScore must be a non-negative integer'),
  body('awayScore').isInt({ min: 0 }).withMessage('awayScore must be a non-negative integer'),
], validate, updateScore);

module.exports = router;
