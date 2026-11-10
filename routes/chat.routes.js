const express = require('express');
const router = express.Router();
const { param, body } = require('express-validator');
const { authenticate } = require('../middlewares/auth');
const validate = require('../middlewares/validate');
const { getMessages, sendMessage } = require('../controllers/chat.controller');

router.use(authenticate);

router.get('/leagues/:leagueId/messages', [
  param('leagueId').isUUID().withMessage('Valid league ID required'),
], validate, getMessages);

router.post('/leagues/:leagueId/messages', [
  param('leagueId').isUUID().withMessage('Valid league ID required'),
  body('message').trim().notEmpty().withMessage('Message is required')
    .isLength({ max: 500 }).withMessage('Message must be under 500 characters'),
], validate, sendMessage);

module.exports = router;
