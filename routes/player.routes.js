const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth');
const { getPlayers, getPlayer, getTopPlayers, getNationalities } = require('../controllers/player.controller');

router.use(authenticate);

router.get('/', getPlayers);
router.get('/top', getTopPlayers);
router.get('/nationalities', getNationalities); // before /:playerId so it isn't captured
router.get('/:playerId', getPlayer);

module.exports = router;
