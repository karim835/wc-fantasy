/**
 * Logger structuré — Winston (npm gratuit)
 *
 * Niveaux : error > warn > info > http > debug
 * Formats  :
 *   - Development : couleurs + timestamp lisible dans le terminal
 *   - Production  : JSON structuré → fichiers rotatifs (30 jours)
 *
 * Fichiers de logs :
 *   logs/error.log   — erreurs uniquement
 *   logs/combined.log — tous les niveaux (rotés quotidiennement)
 *
 * Utilisation :
 *   const logger = require('./config/logger');
 *   logger.info('Serveur démarré', { port: 3000 });
 *   logger.error('Erreur DB', { error: err.message, stack: err.stack });
 */

const winston = require('winston');
const path = require('path');
const fs = require('fs');

// Créer le dossier logs si nécessaire
const logsDir = path.join(__dirname, '..', 'logs');
if (!fs.existsSync(logsDir)) fs.mkdirSync(logsDir, { recursive: true });

// ─── Formats ──────────────────────────────────────────────────────────────────

const { combine, timestamp, colorize, printf, json, errors } = winston.format;

// Format développement : lisible, coloré
const devFormat = combine(
  colorize({ all: true }),
  timestamp({ format: 'HH:mm:ss' }),
  errors({ stack: true }),
  printf(({ level, message, timestamp: ts, stack, ...meta }) => {
    const metaStr = Object.keys(meta).length > 0
      ? '\n  ' + JSON.stringify(meta, null, 2).replace(/\n/g, '\n  ')
      : '';
    return `${ts} [${level}] ${message}${stack ? '\n' + stack : ''}${metaStr}`;
  })
);

// Format production : JSON structuré (compatible ELK, Datadog, etc.)
const prodFormat = combine(
  timestamp(),
  errors({ stack: true }),
  json()
);

// ─── Transports ───────────────────────────────────────────────────────────────

const isProd = process.env.NODE_ENV === 'production';

const transports = [
  // Console (toujours activé)
  new winston.transports.Console({
    format: isProd ? prodFormat : devFormat,
    silent: process.env.NODE_ENV === 'test',
  }),
];

if (isProd) {
  // Fichier erreurs (production uniquement)
  transports.push(
    new winston.transports.File({
      filename: path.join(logsDir, 'error.log'),
      level: 'error',
      format: prodFormat,
      maxsize: 10 * 1024 * 1024, // 10MB
      maxFiles: 5,
    }),
    new winston.transports.File({
      filename: path.join(logsDir, 'combined.log'),
      format: prodFormat,
      maxsize: 20 * 1024 * 1024, // 20MB
      maxFiles: 10,
    })
  );
}

// ─── Instance principale ──────────────────────────────────────────────────────

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || (isProd ? 'info' : 'debug'),
  transports,
  exitOnError: false,
});

// ─── Middleware HTTP (remplace morgan) ────────────────────────────────────────

/**
 * Middleware Express pour logger les requêtes HTTP.
 * À utiliser à la place de (ou en complément de) morgan.
 */
logger.httpMiddleware = (req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    const level = res.statusCode >= 500 ? 'error'
                : res.statusCode >= 400 ? 'warn'
                : 'http';
    logger[level](`${req.method} ${req.originalUrl} ${res.statusCode} — ${duration}ms`, {
      method: req.method,
      url: req.originalUrl,
      status: res.statusCode,
      duration,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    });
  });
  next();
};

module.exports = logger;
