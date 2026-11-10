const express = require('express');
const { body } = require('express-validator');
const router = express.Router();
const { authenticate } = require('../middlewares/auth');
const validate = require('../middlewares/validate');
const {
  getTransferSuggestions, getRiskScore, makeTransfer,
} = require('../controllers/transfer.controller');

router.use(authenticate);

router.get('/leagues/:leagueId/suggestions', getTransferSuggestions);
router.get('/players/:playerId/risk', getRiskScore);

router.post('/leagues/:leagueId/transfer', [
  body('playerOutId').isUUID().withMessage('playerOutId must be a valid player ID'),
  body('playerInId').isUUID().withMessage('playerInId must be a valid player ID'),
], validate, makeTransfer);

module.exports = router;
