/**
 * Système de migrations DB versionné
 *
 * Principe :
 *  1. Crée la table `schema_migrations` si elle n'existe pas.
 *  2. Lit tous les fichiers *.sql dans le dossier migrations/ (trié par nom).
 *  3. Pour chaque fichier non encore appliqué → l'exécute dans une transaction.
 *  4. Enregistre la migration dans schema_migrations.
 *
 * Les fichiers doivent suivre la convention : 001_description.sql, 002_description.sql, …
 * Les migrations déjà appliquées sont ignorées (idempotent au niveau du runner).
 *
 * Usage (appelé dans config/db.js après connexion) :
 *   const { runMigrations } = require('./migrations');
 *   await runMigrations(pool);
 */

const fs   = require('fs');
const path = require('path');
const logger = require('./logger');

const MIGRATIONS_DIR = path.join(__dirname, '..', 'migrations');

// ─── Assure l'existence de la table de tracking ───────────────────────────────

async function ensureMigrationsTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id          SERIAL PRIMARY KEY,
      filename    VARCHAR(255) UNIQUE NOT NULL,
      applied_at  TIMESTAMP DEFAULT NOW()
    )
  `);
}

// ─── Récupère la liste des migrations déjà appliquées ─────────────────────────

async function getApplied(client) {
  const { rows } = await client.query(
    'SELECT filename FROM schema_migrations ORDER BY id'
  );
  return new Set(rows.map((r) => r.filename));
}

// ─── Charge et trie les fichiers SQL du dossier migrations/ ───────────────────

function getMigrationFiles() {
  if (!fs.existsSync(MIGRATIONS_DIR)) {
    logger.warn('Migrations directory not found — skipping', { dir: MIGRATIONS_DIR });
    return [];
  }

  return fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort(); // tri lexicographique → 001_ avant 002_, etc.
}

// ─── Applique une migration dans une transaction ───────────────────────────────

async function applyMigration(client, filename) {
  const filePath = path.join(MIGRATIONS_DIR, filename);
  const sql = fs.readFileSync(filePath, 'utf8');

  await client.query('BEGIN');
  try {
    await client.query(sql);
    await client.query(
      'INSERT INTO schema_migrations (filename) VALUES ($1)',
      [filename]
    );
    await client.query('COMMIT');
    logger.info(`Migration applied: ${filename}`);
  } catch (err) {
    await client.query('ROLLBACK');
    logger.error(`Migration failed: ${filename}`, {
      error: err.message,
      hint: err.hint,
      detail: err.detail,
    });
    throw err;
  }
}

// ─── Point d'entrée principal ─────────────────────────────────────────────────

async function runMigrations(pool) {
  const client = await pool.connect();
  try {
    await ensureMigrationsTable(client);

    const applied = await getApplied(client);
    const files   = getMigrationFiles();

    const pending = files.filter((f) => !applied.has(f));

    if (pending.length === 0) {
      logger.info('Database schema is up to date — no pending migrations');
      return;
    }

    logger.info(`Running ${pending.length} migration(s)…`, { pending });

    for (const filename of pending) {
      await applyMigration(client, filename);
    }

    logger.info('All migrations applied successfully');
  } catch (err) {
    logger.error('Migration runner failed', { error: err.message, stack: err.stack });
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { runMigrations };
