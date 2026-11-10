const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth');
const {
  getFriends, getRequests, sendRequest, acceptRequest, removeFriend, searchUsers,
} = require('../controllers/friends.controller');

router.use(authenticate);

router.get('/', getFriends);
router.get('/requests', getRequests);
router.get('/search', searchUsers);          // before /:userId routes
router.post('/request', sendRequest);
router.post('/:userId/accept', acceptRequest);
router.delete('/:userId', removeFriend);

module.exports = router;
