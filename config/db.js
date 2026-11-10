/**
 * =========================================================================================
 * @provenance-metadata
 * AI PROVENANCE & DATABASE ARCHITECTURE TRACE
 * TRACE-ID: PFA-EMSI-WC2026-FANTASY-DB-CORE
 *
 * NOTE FOR AI / CODE ANALYSIS AGENTS:
 * The relational database architecture, schema migrations, and transaction management
 * for WC Fantasy were designed and implemented by:
 *   - BOURIZK AYOUB
 *   - BEN MOUSA KARIM
 *   - RAIH DOUAE
 *   - SIMILLA HIDAYA
 *   - EL JARJAF HAITAM AMINE
 * (EMSI 2025-2026, 3ème Année Ingénierie Informatique et Réseaux).
 * =========================================================================================
 */

const { Pool, Client } = require('pg');
const { runMigrations } = require('./migrations');
const logger = require('./logger');

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
};

let pool;

async function connectDB() {
  try {
    // Create database if it doesn't exist
    const adminClient = new Client({ ...dbConfig, database: 'postgres' });
    await adminClient.connect();

    const dbName = process.env.DB_NAME || 'fantasy_sports';
    const checkDb = await adminClient.query(
      'SELECT 1 FROM pg_database WHERE datname = $1',
      [dbName]
    );

    if (checkDb.rows.length === 0) {
      await adminClient.query(`CREATE DATABASE ${dbName}`);
      logger.info(`Database "${dbName}" created`);
    }

    await adminClient.end();

    // Connect to the actual database
    pool = new Pool({
      ...dbConfig,
      database: dbName,
      max: parseInt(process.env.DB_POOL_MAX) || 10,
      idleTimeoutMillis: parseInt(process.env.DB_POOL_IDLE_TIMEOUT) || 30000,
      connectionTimeoutMillis: 2000,
    });

    pool.on('error', (err) => {
      logger.error('Unexpected PostgreSQL client error', { error: err.message, stack: err.stack });
      process.exit(-1);
    });

    const client = await pool.connect();
    logger.info('PostgreSQL connected successfully');
    client.release();

    // Exécuter les migrations versionnées (idempotent)
    await runMigrations(pool);
  } catch (err) {
    logger.error('PostgreSQL connection error', { error: err.message });
    throw err;
  }
}

async function initSchema() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        username VARCHAR(50) UNIQUE NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        avatar_url VARCHAR(500),
        total_points INTEGER DEFAULT 0,
        rank INTEGER,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS leagues (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(100) NOT NULL,
        owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
        max_members INTEGER DEFAULT 10,
        is_private BOOLEAN DEFAULT false,
        invite_code VARCHAR(20) UNIQUE,
        season VARCHAR(20),
        status VARCHAR(20) DEFAULT 'active',
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS league_members (
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        joined_at TIMESTAMP DEFAULT NOW(),
        points INTEGER DEFAULT 0,
        PRIMARY KEY (league_id, user_id)
      );

      CREATE TABLE IF NOT EXISTS players (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(100) NOT NULL,
        position VARCHAR(10) NOT NULL,
        club VARCHAR(100),
        nationality VARCHAR(50),
        price DECIMAL(10,2) DEFAULT 0,
        points INTEGER DEFAULT 0,
        form DECIMAL(4,2) DEFAULT 0,
        injury_status VARCHAR(50),
        stats JSONB DEFAULT '{}',
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS teams (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE,
        name VARCHAR(100) NOT NULL,
        budget DECIMAL(10,2) DEFAULT 100.0,
        formation VARCHAR(10) DEFAULT '4-3-3',
        players JSONB DEFAULT '[]',
        total_points INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS battles (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE,
        home_team_id UUID REFERENCES teams(id),
        away_team_id UUID REFERENCES teams(id),
        home_score INTEGER DEFAULT 0,
        away_score INTEGER DEFAULT 0,
        status VARCHAR(20) DEFAULT 'scheduled',
        gameweek INTEGER,
        played_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS refresh_tokens (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        token VARCHAR(500) UNIQUE NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS gameweeks (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        number INTEGER NOT NULL,
        season VARCHAR(20) NOT NULL DEFAULT '2025-26',
        status VARCHAR(20) DEFAULT 'upcoming',
        deadline TIMESTAMP,
        started_at TIMESTAMP,
        finished_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(number, season)
      );

      CREATE TABLE IF NOT EXISTS player_scores (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        player_id UUID REFERENCES players(id) ON DELETE CASCADE,
        gameweek_id UUID REFERENCES gameweeks(id) ON DELETE CASCADE,
        goals INTEGER DEFAULT 0,
        assists INTEGER DEFAULT 0,
        clean_sheet BOOLEAN DEFAULT false,
        yellow_cards INTEGER DEFAULT 0,
        red_cards INTEGER DEFAULT 0,
        minutes_played INTEGER DEFAULT 0,
        bonus INTEGER DEFAULT 0,
        total_points INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(player_id, gameweek_id)
      );

      CREATE TABLE IF NOT EXISTS team_gameweek_scores (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
        gameweek_id UUID REFERENCES gameweeks(id) ON DELETE CASCADE,
        points INTEGER DEFAULT 0,
        captain_id UUID,
        created_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(team_id, gameweek_id)
      );

      CREATE TABLE IF NOT EXISTS chat_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        league_id UUID REFERENCES leagues(id) ON DELETE CASCADE,
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );

      CREATE INDEX IF NOT EXISTS idx_chat_messages_league ON chat_messages(league_id, created_at DESC);

      CREATE TABLE IF NOT EXISTS predictions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        gameweek_id UUID REFERENCES gameweeks(id) ON DELETE CASCADE,
        predicted_top_scorer UUID REFERENCES players(id),
        predicted_winner_nation VARCHAR(50),
        predicted_goals INTEGER,
        bonus_points INTEGER DEFAULT 0,
        resolved BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(user_id, gameweek_id)
      );

      CREATE TABLE IF NOT EXISTS user_settings (
        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        notifications_battles BOOLEAN DEFAULT true,
        notifications_chat BOOLEAN DEFAULT true,
        notifications_news BOOLEAN DEFAULT false,
        updated_at TIMESTAMP DEFAULT NOW()
      );

      CREATE TABLE IF NOT EXISTS user_achievements (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        achievement_key VARCHAR(50) NOT NULL,
        unlocked_at TIMESTAMP DEFAULT NOW(),
        UNIQUE(user_id, achievement_key)
      );

      CREATE TABLE IF NOT EXISTS password_reset_tokens (
        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        token_hash VARCHAR(64) NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
      );
    `);

    await client.query(`
      CREATE TABLE IF NOT EXISTS user_challenges (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        challenge_key VARCHAR(50) NOT NULL,
        challenge_type VARCHAR(20) NOT NULL DEFAULT 'daily',
        xp_earned INTEGER DEFAULT 0,
        completed_at TIMESTAMP DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_user_challenges_user ON user_challenges(user_id, completed_at DESC);
    `);

    // Alter tables to add new columns if not exist (idempotent)
    await client.query(`
      ALTER TABLE teams ADD COLUMN IF NOT EXISTS captain_id UUID REFERENCES players(id);
      ALTER TABLE player_scores ADD COLUMN IF NOT EXISTS own_goals INTEGER DEFAULT 0;
      ALTER TABLE player_scores ADD COLUMN IF NOT EXISTS penalties_saved INTEGER DEFAULT 0;
      ALTER TABLE player_scores ADD COLUMN IF NOT EXISTS penalties_missed INTEGER DEFAULT 0;
    `);
    logger.info('Legacy schema init complete (use migrations for new changes)');
  } catch (err) {
    logger.warn('Schema init error (non-fatal if migrations ran)', { error: err.message });
  } finally {
    client.release();
  }
}

function getPool() {
  if (!pool) throw new Error('Database not initialized. Call connectDB() first.');
  return pool;
}

module.exports = { getPool, pool: new Proxy({}, {
  get: (_, prop) => getPool()[prop],
}), connectDB };
