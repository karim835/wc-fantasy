const router = require('express').Router();
const { authenticate } = require('../middlewares/auth');
const {
  submitPrediction,
  getGameweekPredictions,
  getPredictionLeaderboard,
  resolvePredictions,
} = require('../controllers/prediction.controller');

router.use(authenticate);

router.post('/',                          submitPrediction);
router.get('/gameweek/:gwId',             getGameweekPredictions);
router.get('/leaderboard',                getPredictionLeaderboard);
router.post('/resolve/:gwId',             resolvePredictions);

module.exports = router;
