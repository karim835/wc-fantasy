/**
 * News Controller — FIFA World Cup 2026 news
 * Fetches from multiple RSS feeds, filters WC-related articles, caches in Redis 30 min.
 */

const Parser = require('rss-parser');
const { cacheGet, cacheSet } = require('../config/cache');

const parser = new Parser({
  timeout: 8000,
  headers: { 'User-Agent': 'Mozilla/5.0 (FantasySports/1.0)' },
  customFields: {
    item: [
      ['media:content', 'mediaContent', { keepArray: false }],
      ['media:thumbnail', 'mediaThumbnail', { keepArray: false }],
      ['enclosure', 'enclosure'],
    ],
  },
});

// RSS sources — sports feeds that regularly cover World Cup 2026
const FEEDS = [
  {
    url: 'https://feeds.bbci.co.uk/sport/football/rss.xml',
    source: 'BBC Sport',
    lang: 'en',
  },
  {
    url: 'https://www.skysports.com/rss/12040',
    source: 'Sky Sports',
    lang: 'en',
  },
  {
    url: 'https://www.espn.com/espn/rss/soccer/news',
    source: 'ESPN FC',
    lang: 'en',
  },
  {
    url: 'https://www.goal.com/feeds/en/news',
    source: 'Goal.com',
    lang: 'en',
  },
  {
    url: 'https://www.lequipe.fr/rss/actu_rss_Football.xml',
    source: "L'Équipe",
    lang: 'fr',
  },
  {
    url: 'https://rmcsport.bfmtv.com/rss/football/',
    source: 'RMC Sport',
    lang: 'fr',
  },
];

// Keywords that qualify an article as World Cup related
const WC_KEYWORDS = [
  'world cup', 'coupe du monde', 'mondial', 'fifa', 'wc2026', 'world cup 2026',
  'qualification', 'qualif', 'group stage', 'phase de groupes',
  'morocco', 'france', 'brazil', 'argentina', 'england', 'spain', 'germany',
  'portugal', 'senegal', 'egypt', 'algeria', 'ivory coast',
  'maroc', 'brésil', 'angleterre', 'espagne', 'allemagne', 'sénégal', 'égypte', 'algérie',
  'mbappe', 'mbappé', 'salah', 'mané', 'vinicius', 'messi', 'ronaldo', 'bellingham',
  'hakimi', 'benzema', 'griezmann',
  'usa 2026', 'canada', 'mexico', 'mexique',
];

const CACHE_KEY = 'news:wc2026';
const CACHE_TTL = 1800; // 30 minutes

function isWcRelated(text = '') {
  const lower = text.toLowerCase();
  return WC_KEYWORDS.some((kw) => lower.includes(kw));
}

function extractImage(item) {
  if (item.enclosure?.url) return item.enclosure.url;
  if (item.mediaContent?.['$']?.url) return item.mediaContent['$'].url;
  if (item.mediaThumbnail?.['$']?.url) return item.mediaThumbnail['$'].url;
  // Try extracting first img from content
  const html = item['content:encoded'] || item.content || '';
  const match = html.match(/<img[^>]+src=["']([^"']+)["']/i);
  return match ? match[1] : null;
}

function normalizeItem(item, source) {
  return {
    id: Buffer.from((item.link || item.guid || item.title || '').slice(0, 100)).toString('base64').slice(0, 32),
    title: item.title?.trim() || '',
    summary: item.contentSnippet?.trim() || item.summary?.trim() || '',
    url: item.link || item.guid || '',
    imageUrl: extractImage(item),
    source,
    publishedAt: item.pubDate || item.isoDate || new Date().toISOString(),
    category: detectCategory(item.title + ' ' + (item.contentSnippet || '')),
  };
}

function detectCategory(text = '') {
  const lower = text.toLowerCase();
  if (/transfer|transfert|signing|deal|contract/.test(lower)) return 'Transfert';
  if (/injur|blessure|fitness|absent/.test(lower)) return 'Blessure';
  if (/result|score|goal|but|match|game|win|lose|draw/.test(lower)) return 'Match';
  if (/squad|sélection|lineup|formation|team/.test(lower)) return 'Équipe';
  if (/qualification|qualif|draw|tirage/.test(lower)) return 'Qualif';
  return 'Actu';
}

async function fetchFeed(feedConfig) {
  try {
    const feed = await parser.parseURL(feedConfig.url);
    return (feed.items || []).map((item) => normalizeItem(item, feedConfig.source));
  } catch {
    return []; // silently fail individual feeds
  }
}

// ─── GET /api/news ────────────────────────────────────────────────────────────
async function getNews(req, res, next) {
  try {
    const { page = 1, limit = 20, category, search, lang } = req.query;
    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(50, Math.max(1, parseInt(limit)));

    // Try cache first
    const cached = await cacheGet(CACHE_KEY);
    let articles = cached ? JSON.parse(cached) : null;

    if (!articles) {
      // Fetch all feeds in parallel
      const results = await Promise.allSettled(FEEDS.map(fetchFeed));
      const allItems = results.flatMap((r) => (r.status === 'fulfilled' ? r.value : []));

      // Filter WC-related + deduplicate by URL
      const seen = new Set();
      articles = allItems
        .filter((a) => {
          if (!a.url || seen.has(a.url)) return false;
          seen.add(a.url);
          return isWcRelated(a.title + ' ' + a.summary);
        })
        .sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt));

      // If no WC articles found (feeds down), return latest sports articles
      if (articles.length === 0) {
        const fallback = allItems.filter((a) => {
          if (!a.url || seen.has(a.url)) return false;
          seen.add(a.url);
          return true;
        });
        articles = fallback.sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt)).slice(0, 40);
      }

      await cacheSet(CACHE_KEY, JSON.stringify(articles), CACHE_TTL);
    }

    // Apply filters
    let filtered = articles;
    if (category) filtered = filtered.filter((a) => a.category === category);
    if (lang) filtered = filtered.filter((a) => {
      const feedLang = FEEDS.find((f) => f.source === a.source)?.lang;
      return feedLang === lang;
    });
    if (search) {
      const q = search.toLowerCase();
      filtered = filtered.filter((a) =>
        a.title.toLowerCase().includes(q) || a.summary.toLowerCase().includes(q)
      );
    }

    const total = filtered.length;
    const offset = (pageNum - 1) * limitNum;
    const paginated = filtered.slice(offset, offset + limitNum);

    res.json({
      articles: paginated,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
        hasMore: offset + limitNum < total,
      },
      cachedAt: cached ? undefined : new Date().toISOString(),
    });
  } catch (err) {
    next(err);
  }
}

// ─── GET /api/news/categories ─────────────────────────────────────────────────
async function getCategories(req, res, next) {
  try {
    res.json([
      { key: 'Match', label: 'Matchs', icon: 'sports_soccer' },
      { key: 'Transfert', label: 'Transferts', icon: 'swap_horiz' },
      { key: 'Blessure', label: 'Blessures', icon: 'medical_services' },
      { key: 'Équipe', label: 'Équipes', icon: 'groups' },
      { key: 'Qualif', label: 'Qualifications', icon: 'emoji_events' },
      { key: 'Actu', label: 'Actu', icon: 'newspaper' },
    ]);
  } catch (err) {
    next(err);
  }
}

// ─── GET /api/news/latest ─────────────────────────────────────────────────────
// Returns top 5 headlines for the home screen widget
async function getLatestHeadlines(req, res, next) {
  try {
    const cached = await cacheGet(CACHE_KEY);
    let articles = cached ? JSON.parse(cached) : null;

    if (!articles) {
      const results = await Promise.allSettled(FEEDS.map(fetchFeed));
      const allItems = results.flatMap((r) => (r.status === 'fulfilled' ? r.value : []));
      const seen = new Set();
      articles = allItems
        .filter((a) => {
          if (!a.url || seen.has(a.url)) return false;
          seen.add(a.url);
          return isWcRelated(a.title + ' ' + a.summary);
        })
        .sort((a, b) => new Date(b.publishedAt) - new Date(a.publishedAt));
      await cacheSet(CACHE_KEY, JSON.stringify(articles), CACHE_TTL);
    }

    res.json(articles.slice(0, 5));
  } catch (err) {
    next(err);
  }
}

// ─── DELETE /api/news/cache  (admin) ──────────────────────────────────────────
async function clearCache(req, res, next) {
  try {
    const { redis } = require('../config/cache');
    if (redis) await redis.del(CACHE_KEY);
    res.json({ message: 'Cache effacé' });
  } catch (err) {
    next(err);
  }
}

module.exports = { getNews, getCategories, getLatestHeadlines, clearCache };
