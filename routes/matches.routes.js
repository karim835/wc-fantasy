const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth');
const { getMatches } = require('../controllers/matches.controller');

router.use(authenticate);

router.get('/', getMatches);

module.exports = router;
