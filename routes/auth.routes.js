const express = require('express');
const { body } = require('express-validator');
const rateLimit = require('express-rate-limit');
const router = express.Router();
const { authenticate } = require('../middlewares/auth');
const validate = require('../middlewares/validate');

// Strict rate limit pour les endpoints sensibles (brute-force protection).
// In production we keep it tight (10 / 15 min). In dev/demo every phone request
// arrives from 127.0.0.1 via `adb reverse`, so a shared 10-attempt bucket blocks
// rapid log-out/log-in testing — raise the ceiling well clear of that there.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: process.env.NODE_ENV === 'production' ? 10 : 1000,
  message: { error: 'Too many attempts, please try again in 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});
const {
  register, login, refresh, logout, getProfile, updateProfile, uploadAvatar, deleteAccount, getProfileStats,
  getSettings, updateSettings, changePassword, getAchievements,
  forgotPassword, resetPassword,
} = require('../controllers/auth.controller');

const registerValidation = [
  body('username').trim().isLength({ min: 3, max: 50 }).withMessage('Username must be 3-50 characters'),
  body('email').isEmail().normalizeEmail().withMessage('Invalid email'),
  body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
  body('date_of_birth').optional({ nullable: true }).isISO8601().withMessage('Invalid date of birth'),
  body('country').optional({ nullable: true }).isLength({ max: 60 }).withMessage('Country max 60 chars'),
  body('favorite_nation').optional({ nullable: true }).isLength({ max: 60 }).withMessage('Favorite nation max 60 chars'),
  body('favorite_club').optional({ nullable: true }).isLength({ max: 80 }).withMessage('Favorite club max 80 chars'),
  body('favorite_player').optional({ nullable: true }).isLength({ max: 80 }).withMessage('Favorite player max 80 chars'),
  body('bio').optional({ nullable: true }).isLength({ max: 300 }).withMessage('Bio max 300 chars'),
];

const loginValidation = [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
];

/**
 * @swagger
 * tags:
 *   name: Auth
 *   description: Authentication and user account management
 */

/**
 * @swagger
 * /api/auth/register:
 *   post:
 *     summary: Register a new user
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [username, email, password]
 *             properties:
 *               username:
 *                 type: string
 *                 minLength: 3
 *                 maxLength: 50
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 minLength: 8
 *     responses:
 *       201:
 *         description: User created successfully with JWT tokens
 *       409:
 *         description: Email or username already taken
 *       422:
 *         description: Validation error
 */
router.post('/register', authLimiter, registerValidation, validate, register);

/**
 * @swagger
 * /api/auth/login:
 *   post:
 *     summary: Authenticate user and obtain JWT tokens
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, password]
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login successful, returns accessToken and refreshToken
 *       401:
 *         description: Invalid credentials
 */
router.post('/login', authLimiter, loginValidation, validate, login);

/**
 * @swagger
 * /api/auth/refresh:
 *   post:
 *     summary: Refresh access token using a refresh token
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [refreshToken]
 *             properties:
 *               refreshToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: New access and refresh tokens returned
 *       401:
 *         description: Invalid or expired refresh token
 */
router.post('/refresh', refresh);

/**
 * @swagger
 * /api/auth/logout:
 *   post:
 *     summary: Invalidate a refresh token
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               refreshToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: Logged out successfully
 */
router.post('/logout', logout);

/**
 * @swagger
 * /api/auth/profile:
 *   get:
 *     summary: Get the authenticated user's profile
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile object
 *       401:
 *         description: No token provided or invalid token
 */
router.get('/profile', authenticate, getProfile);

/**
 * @swagger
 * /api/auth/profile/stats:
 *   get:
 *     summary: Get detailed profile statistics (leagues, teams, predictions, GW history)
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Extended profile stats
 *       401:
 *         description: Unauthorized
 */
router.get('/profile/stats', authenticate, getProfileStats);

/**
 * @swagger
 * /api/auth/profile:
 *   patch:
 *     summary: Update username or avatar URL
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               username:
 *                 type: string
 *               avatar_url:
 *                 type: string
 *     responses:
 *       200:
 *         description: Updated user object
 *       401:
 *         description: Unauthorized
 */
router.patch('/profile', authenticate, updateProfile);

// Profile photo upload (base64) + account deletion
router.post('/avatar', authenticate, uploadAvatar);
router.delete('/account', authenticate, deleteAccount);

/**
 * @swagger
 * /api/auth/settings:
 *   get:
 *     summary: Get notification settings for the authenticated user
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User settings object
 *       401:
 *         description: Unauthorized
 */
router.get('/settings',           authenticate, getSettings);

/**
 * @swagger
 * /api/auth/settings:
 *   patch:
 *     summary: Update notification settings
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               notifications_battles:
 *                 type: boolean
 *               notifications_chat:
 *                 type: boolean
 *               notifications_news:
 *                 type: boolean
 *     responses:
 *       200:
 *         description: Updated settings object
 *       401:
 *         description: Unauthorized
 */
router.patch('/settings',         authenticate, updateSettings);

/**
 * @swagger
 * /api/auth/profile/password:
 *   patch:
 *     summary: Change the authenticated user's password
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [currentPassword, newPassword]
 *             properties:
 *               currentPassword:
 *                 type: string
 *               newPassword:
 *                 type: string
 *                 minLength: 8
 *     responses:
 *       200:
 *         description: Password changed successfully
 *       400:
 *         description: Missing fields or new password too short
 *       401:
 *         description: Current password is incorrect
 */
router.patch('/profile/password', authenticate, changePassword);

/**
 * @swagger
 * /api/auth/achievements:
 *   get:
 *     summary: Get the list of achievements and unlock status for the authenticated user
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Array of achievement objects with unlock status
 *       401:
 *         description: Unauthorized
 */
router.get('/achievements',       authenticate, getAchievements);

/**
 * @swagger
 * /api/auth/forgot-password:
 *   post:
 *     summary: Request a password reset email (FREE — Gmail SMTP via Nodemailer)
 *     tags: [Auth]
 *     security: []
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
 *     responses:
 *       200:
 *         description: Reset email sent (always 200 to prevent email enumeration)
 *       400:
 *         description: Email field missing
 */
router.post('/forgot-password', authLimiter, [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required'),
], validate, forgotPassword);

/**
 * @swagger
 * /api/auth/reset-password:
 *   post:
 *     summary: Reset password using a valid reset token
 *     tags: [Auth]
 *     security: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [token, newPassword]
 *             properties:
 *               token:
 *                 type: string
 *                 description: Raw token from the reset email link
 *               newPassword:
 *                 type: string
 *                 minLength: 8
 *     responses:
 *       200:
 *         description: Password reset successfully
 *       400:
 *         description: Invalid/expired token or password too short
 */
router.post('/reset-password', [
  body('token').notEmpty().withMessage('Reset token required'),
  body('newPassword').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
], resetPassword);

module.exports = router;
