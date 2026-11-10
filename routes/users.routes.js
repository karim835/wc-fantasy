const express = require('express');
const router = express.Router();
const { authenticate } = require('../middlewares/auth');
const { getPublicProfile } = require('../controllers/users.controller');

router.use(authenticate);

router.get('/:userId/profile', getPublicProfile);

module.exports = router;
