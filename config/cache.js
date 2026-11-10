const Redis = require('ioredis');

let redisClient;

async function connectRedis() {
  try {
    redisClient = new Redis({
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT) || 6379,
      password: process.env.REDIS_PASSWORD || undefined,
      retryStrategy: (times) => null, // Don't retry
      maxRetriesPerRequest: null,
      enableReadyCheck: false,
      enableOfflineQueue: false,
      connectTimeout: 1000,
      commandTimeout: 1000,
    });

    // Handle all error events
    redisClient.on('error', (err) => {
      // Silently ignore if already null
      if (redisClient) {
        console.warn('⚠️  Redis unavailable - caching disabled');
        redisClient.disconnect();
        redisClient = null;
      }
    });

    redisClient.on('connect', () => {
      console.log('✅ Redis connected');
    });

    // Try to ping with timeout
    await Promise.race([
      redisClient.ping(),
      new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 2000))
    ]);

    console.log('✅ Redis ready');
  } catch (err) {
    console.log('ℹ️  Redis not available - running without cache');
    if (redisClient) {
      redisClient.disconnect();
    }
    redisClient = null;
  }
  return redisClient;
}

function getRedis() {
  return redisClient; // May be null if Redis is unavailable
}

async function cacheGet(key) {
  if (!getRedis()) return null;
  try {
    const data = await getRedis().get(key);
    return data ? JSON.parse(data) : null;
  } catch (err) {
    console.warn('Cache get error:', err.message);
    return null;
  }
}

async function cacheSet(key, value, ttl = parseInt(process.env.REDIS_TTL) || 3600) {
  if (!getRedis()) return;
  try {
    await getRedis().setex(key, ttl, JSON.stringify(value));
  } catch (err) {
    console.warn('Cache set error:', err.message);
  }
}

async function cacheDel(key) {
  if (!getRedis()) return;
  try {
    await getRedis().del(key);
  } catch (err) {
    console.warn('Cache delete error:', err.message);
  }
}

async function cacheDelPattern(pattern) {
  if (!getRedis()) return;
  try {
    const keys = await getRedis().keys(pattern);
    if (keys.length > 0) await getRedis().del(...keys);
  } catch (err) {
    console.warn('Cache pattern delete error:', err.message);
  }
}

module.exports = { connectRedis, getRedis, cacheGet, cacheSet, cacheDel, cacheDelPattern };
