const router = require('express').Router();
const { authenticate } = require('../middlewares/auth');
const { getChallenges, completeChallenge, getChallengeLeaderboard } = require('../controllers/challenge.controller');

router.use(authenticate);

router.get('/',             getChallenges);
router.post('/complete',    completeChallenge);
router.get('/leaderboard',  getChallengeLeaderboard);

module.exports = router;
