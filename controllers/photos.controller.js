const axios = require('axios');
const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');
const { cacheGet, cacheSet } = require('../config/cache');
const logger = require('../config/logger');

const AVATAR_DIR = path.join(__dirname, '..', 'uploads', 'avatars');
const AVATAR_TYPES = { jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };

// GET /api/photos/avatar/:userId — stream a user's uploaded avatar with CORS so
// Flutter web can render it cross-origin (same approach as proxyImage).
function getAvatar(req, res) {
  const { userId } = req.params;
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Cross-Origin-Resource-Policy', 'cross-origin');
  // Guard against path traversal — userId must look like a UUID.
  if (!/^[0-9a-fA-F-]{36}$/.test(userId)) {
    return res.status(400).json({ error: 'Invalid id' });
  }
  for (const ext of Object.keys(AVATAR_TYPES)) {
    const file = path.join(AVATAR_DIR, `${userId}.${ext}`);
    if (fs.existsSync(file)) {
      res.set('Content-Type', AVATAR_TYPES[ext]);
      res.set('Cache-Control', 'public, max-age=300');
      return fs.createReadStream(file).pipe(res);
    }
  }
  return res.status(404).json({ error: 'No avatar' });
}

async function getPlayerPhoto(req, res, next) {
  try {
    const { playerId } = req.params;
    const cacheKey = `photo:player:${playerId}`;

    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const result = await pool.query(
      'SELECT id, name, photo_url, nationality FROM players WHERE id = $1',
      [playerId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Player not found' });
    }

    const player = result.rows[0];

    if (player.photo_url) {
      const data = { playerId: player.id, photoUrl: player.photo_url, source: 'db' };
      await cacheSet(cacheKey, data, 86400);
      return res.json(data);
    }

    // Fallback: try Wikipedia API
    const photoUrl = await fetchWikipediaPhoto(player.name);
    if (photoUrl) {
      await pool.query('UPDATE players SET photo_url = $1 WHERE id = $2', [photoUrl, player.id]);
      const data = { playerId: player.id, photoUrl, source: 'wikipedia' };
      await cacheSet(cacheKey, data, 86400);
      return res.json(data);
    }

    // Final fallback: generated avatar
    const fallbackUrl = `https://ui-avatars.com/api/?name=${encodeURIComponent(player.name)}&size=200&background=random`;
    const data = { playerId: player.id, photoUrl: fallbackUrl, source: 'fallback' };
    await cacheSet(cacheKey, data, 3600);
    res.json(data);
  } catch (err) {
    next(err);
  }
}

// Hosts we are willing to proxy images from (prevents the open-relay/SSRF risk
// of a generic ?url= proxy). All are public image CDNs used by our data sources.
const ALLOWED_IMAGE_HOSTS = [
  'r2.thesportsdb.com',
  'www.thesportsdb.com',
  'thesportsdb.com',
  'upload.wikimedia.org',
  'ui-avatars.com',
];

function isAllowedImageHost(hostname) {
  const h = (hostname || '').toLowerCase();
  return ALLOWED_IMAGE_HOSTS.includes(h) || h.endsWith('.wikipedia.org');
}

/**
 * GET /api/photos/proxy?url=<encoded image url>
 * Streams a remote player image through our own origin so the browser sees our
 * permissive CORS headers. TheSportsDB's R2 CDN sends no `Access-Control-Allow-Origin`,
 * so Flutter **web** can't load those images directly — this fixes that (and is a
 * no-op cost on mobile). Host-allowlisted to avoid being an open proxy.
 */
async function proxyImage(req, res, next) {
  try {
    const { url } = req.query;
    if (!url) return res.status(400).json({ error: 'url query param required' });

    let target;
    try {
      target = new URL(url);
    } catch {
      return res.status(400).json({ error: 'Invalid url' });
    }
    if (target.protocol !== 'https:' || !isAllowedImageHost(target.hostname)) {
      return res.status(400).json({ error: 'Host not allowed' });
    }

    const upstream = await axios.get(target.href, {
      responseType: 'stream',
      timeout: 10000,
      validateStatus: () => true,
    });
    if (upstream.status !== 200) {
      return res.status(upstream.status === 404 ? 404 : 502).end();
    }

    res.set('Content-Type', upstream.headers['content-type'] || 'image/jpeg');
    res.set('Cache-Control', 'public, max-age=604800, immutable');
    upstream.data.pipe(res);
  } catch (err) {
    next(err);
  }
}

async function backfillPhotos(req, res, next) {
  try {
    const result = await pool.query(
      'SELECT id, name FROM players WHERE photo_url IS NULL'
    );

    let updated = 0;
    for (const player of result.rows) {
      const photoUrl = await fetchWikipediaPhoto(player.name);
      if (photoUrl) {
        await pool.query('UPDATE players SET photo_url = $1 WHERE id = $2', [photoUrl, player.id]);
        updated++;
      }
      // Rate limit: 1 request per second to Wikipedia
      await new Promise(resolve => setTimeout(resolve, 1000));
    }

    res.json({ message: `Backfill complete. Updated ${updated}/${result.rows.length} players.` });
  } catch (err) {
    next(err);
  }
}

async function fetchWikipediaPhoto(playerName) {
  try {
    const searchUrl = `https://en.wikipedia.org/w/api.php?action=query&titles=${encodeURIComponent(playerName)}&prop=pageimages&format=json&pithumbsize=300`;
    const response = await axios.get(searchUrl, { timeout: 5000 });
    const pages = response.data.query.pages;
    const page = Object.values(pages)[0];
    return page?.thumbnail?.source || null;
  } catch (err) {
    logger.debug(`Wikipedia photo fetch failed for ${playerName}`, { error: err.message });
    return null;
  }
}

module.exports = { getPlayerPhoto, proxyImage, backfillPhotos, getAvatar };
