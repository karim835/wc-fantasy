const router = require('express').Router();
const { authenticate } = require('../middlewares/auth');
const { getNews, getCategories, getLatestHeadlines, clearCache } = require('../controllers/news.controller');

// Public-ish (still requires auth to avoid abuse, token optional here)
router.get('/', authenticate, getNews);
router.get('/latest', authenticate, getLatestHeadlines);
router.get('/categories', authenticate, getCategories);

// Admin only — clear RSS cache to force refresh
router.delete('/cache', authenticate, clearCache);

module.exports = router;
