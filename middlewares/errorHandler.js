const logger = require('../config/logger');

/**
 * Global Error Handler — Express
 *
 * Gère tous les types d'erreurs de l'API :
 *  - Erreurs de validation (express-validator)
 *  - Erreurs PostgreSQL (contraintes, doublons)
 *  - Erreurs JWT
 *  - Erreurs custom (avec statusCode)
 *  - Erreurs inattendues (500)
 *
 * En production : ne renvoie jamais de stack trace au client.
 * En développement : renvoie le message complet pour le debug.
 */
function errorHandler(err, req, res, next) {
  // ── Contexte de la requête pour les logs ─────────────────────────────────
  const context = {
    method: req.method,
    url: req.originalUrl,
    ip: req.ip,
    userId: req.user?.id || null,
  };

  // ── Validation express-validator ─────────────────────────────────────────
  if (err.name === 'ValidationError' || err.type === 'validation') {
    logger.warn('Validation error', { ...context, errors: err.errors || err.message });
    return res.status(422).json({
      error: 'Validation failed',
      details: err.errors || err.message,
    });
  }

  // ── Erreurs JWT ───────────────────────────────────────────────────────────
  if (err.name === 'JsonWebTokenError') {
    logger.warn('Invalid JWT token', context);
    return res.status(401).json({ error: 'Invalid token' });
  }
  if (err.name === 'TokenExpiredError') {
    logger.warn('Expired JWT token', context);
    return res.status(401).json({ error: 'Token expired' });
  }

  // ── Erreurs PostgreSQL ────────────────────────────────────────────────────
  if (err.code === '23505') {
    logger.warn('DB unique constraint violation', { ...context, detail: err.detail });
    return res.status(409).json({ error: 'Resource already exists', detail: err.detail });
  }
  if (err.code === '23503') {
    logger.warn('DB foreign key violation', { ...context, detail: err.detail });
    return res.status(400).json({ error: 'Referenced resource not found' });
  }
  if (err.code === '23502') {
    logger.warn('DB not-null violation', { ...context, detail: err.detail });
    return res.status(400).json({ error: 'Required field missing', detail: err.detail });
  }
  if (err.code === '42P01') {
    logger.error('DB table not found — schema may be outdated', context);
    return res.status(500).json({ error: 'Database schema error' });
  }

  // ── Erreur custom avec statusCode ─────────────────────────────────────────
  const statusCode = err.statusCode || err.status || 500;

  if (statusCode < 500) {
    // 4xx : erreur client, juste un warn
    logger.warn(err.message, { ...context, statusCode });
    return res.status(statusCode).json({ error: err.message });
  }

  // ── Erreur serveur 500 ────────────────────────────────────────────────────
  logger.error('Unhandled server error', {
    ...context,
    error: err.message,
    stack: err.stack,
    statusCode,
  });

  const isProd = process.env.NODE_ENV === 'production';
  res.status(500).json({
    error: isProd ? 'Internal server error' : err.message,
    ...(isProd ? {} : { stack: err.stack }),
  });
}

/**
 * Créer une erreur HTTP avec statusCode.
 * Usage : throw createError(404, 'Player not found');
 */
function createError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

module.exports = errorHandler;
module.exports.createError = createError;
