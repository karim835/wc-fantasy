const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth');
const isAdmin = require('../middlewares/isAdmin');
const { getPlayerPhoto, proxyImage, backfillPhotos, getAvatar } = require('../controllers/photos.controller');

// Public: streams allowlisted remote images through our CORS-enabled origin so
// Flutter web can display them (TheSportsDB's CDN sends no CORS header).
router.get('/proxy', proxyImage);

// Public: streams a user's uploaded avatar (CORS-enabled for web <img>).
router.get('/avatar/:userId', getAvatar);

router.get('/player/:playerId', authenticate, getPlayerPhoto);
router.post('/backfill', authenticate, isAdmin, backfillPhotos);

module.exports = router;
