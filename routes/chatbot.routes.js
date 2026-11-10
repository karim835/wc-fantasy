const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth');
const { chat } = require('../controllers/chatbot.controller');

router.post('/chat', authenticate, chat);

module.exports = router;
