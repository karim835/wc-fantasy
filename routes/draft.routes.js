const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router({ mergeParams: true });
const { authenticate } = require('../middlewares/auth');
const validate = require('../middlewares/validate');
const {
  getMyTeam, createTeam, updateTeam, clearTeamPlayers, pickPlayer, removePlayer, autoPick, setCaptain, armChip,
} = require('../controllers/draft.controller');

router.use(authenticate);

router.get('/leagues/:leagueId/team', getMyTeam);

router.post('/leagues/:leagueId/team', [
  body('name').trim().notEmpty().isLength({ max: 100 }).withMessage('Team name required (max 100 chars)'),
  body('formation').optional().matches(/^\d-\d-\d(-\d)?$/).withMessage('Invalid formation format'),
], validate, createTeam);

router.patch('/leagues/:leagueId/team', [
  body('name').optional().trim().isLength({ min: 1, max: 100 }).withMessage('Team name max 100 chars'),
  body('formation').optional().matches(/^\d-\d-\d(-\d)?$/).withMessage('Invalid formation format'),
], validate, updateTeam);

router.delete('/leagues/:leagueId/team/players', clearTeamPlayers);

router.post('/leagues/:leagueId/team/pick', [
  body('playerId').isUUID().withMessage('Valid player ID required'),
], validate, pickPlayer);

router.delete('/leagues/:leagueId/team/players/:playerId', [
  param('playerId').isUUID().withMessage('Valid player ID required'),
], validate, removePlayer);

router.post('/leagues/:leagueId/team/auto-pick', autoPick);

router.patch('/leagues/:leagueId/team/captain', [
  body('playerId').isUUID().withMessage('Valid player ID required'),
], validate, setCaptain);

router.patch('/leagues/:leagueId/team/chip', [
  body('chip').isIn(['triple_captain', 'super_sub', 'shield']).withMessage('Invalid chip'),
  body('boostPlayerId').optional().isUUID().withMessage('Valid player ID required'),
], validate, armChip);

module.exports = router;
