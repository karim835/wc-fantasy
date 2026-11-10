/**
 * Admin routes — internal testing and debugging endpoints
 * In production, protect these with proper admin middleware
 */

const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middlewares/auth');
const { sendPasswordResetEmail, sendWelcomeEmail } = require('../services/emailService');
const {
  getOverview, listUsers, setUserRole, deleteUser,
  listLeagues, deleteLeague, updatePlayer,
} = require('../controllers/admin.controller');

// All admin dashboard endpoints require an authenticated admin.
router.use(authenticate, requireAdmin);

// ─── Dashboard ───────────────────────────────────────────────────────────────
router.get('/overview',            getOverview);
router.get('/users',               listUsers);
router.patch('/users/:id/role',    setUserRole);
router.delete('/users/:id',        deleteUser);
router.get('/leagues',             listLeagues);
router.delete('/leagues/:id',      deleteLeague);
router.patch('/players/:id',       updatePlayer);

/**
 * @swagger
 * /api/admin/test-email:
 *   post:
 *     summary: Test email sending (admin only)
 *     tags: [Admin]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email]
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               type:
 *                 type: string
 *                 enum: [reset, welcome]
 *                 default: reset
 *     responses:
 *       200:
 *         description: Test email sent
 *       500:
 *         description: Email send failed
 */
router.post('/test-email', authenticate, async (req, res) => {
  try {
    const { email, type = 'reset' } = req.body;
    if (!email) return res.status(400).json({ error: 'Email required' });

    const testToken = 'test-token-' + Date.now();

    if (type === 'welcome') {
      await sendWelcomeEmail(email, 'Test User');
    } else {
      await sendPasswordResetEmail(email, testToken, 'Test User');
    }

    res.json({ message: `${type} email sent to ${email}` });
  } catch (err) {
    console.error('Test email error:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
