const { cacheGet, cacheSet } = require('../config/cache');

function withCache(keyFn, ttl) {
  return async (req, res, next) => {
    try {
      const key = typeof keyFn === 'function' ? keyFn(req) : keyFn;
      const cached = await cacheGet(key);

      if (cached) {
        return res.json({ ...cached, _cached: true });
      }

      const originalJson = res.json.bind(res);
      res.json = async (data) => {
        if (res.statusCode < 400) {
          await cacheSet(key, data, ttl);
        }
        return originalJson(data);
      };

      next();
    } catch (err) {
      // Cache errors should not block the request
      next();
    }
  };
}

module.exports = { withCache };
