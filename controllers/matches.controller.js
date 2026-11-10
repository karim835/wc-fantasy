const { pool } = require('../config/db');
const { cacheGet, cacheSet } = require('../config/cache');
const footballData = require('../services/footballData.service');

// Status groups exposed to the client.
const LIVE_STATUSES = ['IN_PLAY', 'PAUSED'];
const UPCOMING_STATUSES = ['SCHEDULED', 'TIMED'];

// GET /api/matches?status=live|upcoming|finished&matchday=
async function getMatches(req, res, next) {
  try {
    const { status, matchday } = req.query;
    const cacheKey = `matches:${status || 'all'}:${matchday || 'all'}`;
    const cached = await cacheGet(cacheKey);
    if (cached) return res.json(cached);

    const where = [];
    const params = [];
    if (status === 'live') {
      params.push(LIVE_STATUSES);
      where.push(`status = ANY($${params.length})`);
    } else if (status === 'upcoming') {
      params.push(UPCOMING_STATUSES);
      where.push(`status = ANY($${params.length})`);
    } else if (status === 'finished') {
      params.push('FINISHED');
      where.push(`status = $${params.length}`);
    }
    if (matchday) {
      params.push(parseInt(matchday, 10));
      where.push(`matchday = $${params.length}`);
    }

    const sql = `SELECT * FROM matches
                 ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
                 ORDER BY kickoff ASC NULLS LAST, matchday ASC`;
    let { rows } = await pool.query(sql, params);

    // Fallback: if the table is empty (seeder never ran), fetch live from the API.
    if (rows.length === 0 && !status && !matchday) {
      try {
        const live = await footballData.getMatches();
        rows = live.map((m) => {
          const r = footballData.mapMatchResult(m);
          return {
            fd_match_id: r.matchId, matchday: r.matchday,
            home_team: r.homeTeam, away_team: r.awayTeam,
            home_goals: r.homeGoals, away_goals: r.awayGoals,
            status: m.status, kickoff: m.utcDate,
          };
        });
      } catch (_) { /* keep empty */ }
    }

    await cacheSet(cacheKey, rows, 300); // 5 min
    res.json(rows);
  } catch (err) {
    next(err);
  }
}

module.exports = { getMatches };
