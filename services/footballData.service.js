/**
 * Football Data Service — football-data.org FREE tier
 *
 * Free plan:
 *  - No credit card required
 *  - 10 requests / minute
 *  - Register at: https://www.football-data.org/client/register
 *  - Set FOOTBALL_DATA_API_KEY in your .env
 *
 * WC 2026 competition code: WC
 * API docs: https://www.football-data.org/documentation/quickstart
 */

const axios = require("axios");

const BASE_URL = "https://api.football-data.org/v4";
const API_KEY = process.env.FOOTBALL_DATA_API_KEY || "";
const COMPETITION = process.env.FOOTBALL_DATA_COMPETITION || "WC";

const client = axios.create({
  baseURL: BASE_URL,
  headers: { "X-Auth-Token": API_KEY },
  timeout: 10000,
});

// ─── Rate-limit helper ──────────────────────────────────────────────────────
// Free tier: 10 req/min → 1 request every 6 seconds
let _lastCallAt = 0;
async function _throttle() {
  const gap = 6100; // ms — slightly over 6s to be safe
  const wait = gap - (Date.now() - _lastCallAt);
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  _lastCallAt = Date.now();
}

// ─── Public helpers ─────────────────────────────────────────────────────────

/**
 * Get all matches for the current competition, optionally filtered by matchday.
 * @param {number|null} matchday
 * @returns {Promise<object[]>}
 */
async function getMatches(matchday = null) {
  await _throttle();
  const params = { status: "FINISHED" };
  if (matchday) params.matchday = matchday;

  const res = await client.get(`/competitions/${COMPETITION}/matches`, {
    params,
  });
  return res.data.matches || [];
}

/**
 * Get matches for the competition, filtered by an explicit status
 * (SCHEDULED | TIMED | IN_PLAY | PAUSED | FINISHED) or null for all.
 * Unlike getMatches() this does NOT hard-code FINISHED, so it can drive the
 * fixtures calendar and gameweek generation.
 * @param {string|null} status
 * @returns {Promise<object[]>}
 */
async function getAllMatches(status = null) {
  await _throttle();
  const params = {};
  if (status) params.status = status;
  const res = await client.get(`/competitions/${COMPETITION}/matches`, { params });
  return res.data.matches || [];
}

/**
 * Get scorers (top scorers) for the competition.
 * @param {number} limit
 * @returns {Promise<object[]>}
 */
async function getTopScorers(limit = 100) {
  await _throttle();
  const res = await client.get(`/competitions/${COMPETITION}/scorers`, {
    params: { limit },
  });
  return res.data.scorers || [];
}

/**
 * Get all teams in the competition (useful to seed clubs).
 * @returns {Promise<object[]>}
 */
async function getTeams() {
  await _throttle();
  const res = await client.get(`/competitions/${COMPETITION}/teams`);
  return res.data.teams || [];
}

/**
 * Get a single match by football-data.org match ID.
 * @param {number} matchId
 * @returns {Promise<object>}
 */
async function getMatch(matchId) {
  await _throttle();
  const res = await client.get(`/matches/${matchId}`);
  return res.data;
}

/**
 * Get current standings for the competition.
 * @returns {Promise<object[]>}
 */
async function getStandings() {
  await _throttle();
  const res = await client.get(`/competitions/${COMPETITION}/standings`);
  return res.data.standings || [];
}

/**
 * Map a football-data.org scorer entry to our player_scores shape.
 * Note: the free API does not give per-match breakdowns per player —
 * it gives season totals. We use this for bulk updates after each matchday.
 *
 * @param {object} scorer  — scorer object from /scorers endpoint
 * @returns {{ playerName, teamName, goals, assists, penalties }}
 */
function mapScorerToStats(scorer) {
  return {
    playerName: scorer.player?.name || "",
    teamName: scorer.team?.name || "",
    goals: scorer.goals || 0,
    assists: scorer.assists || 0,
    penalties: scorer.penalties || 0,
  };
}

/**
 * Map a match object to a minimal result summary.
 * @param {object} match
 * @returns {{ matchId, homeTeam, awayTeam, homeGoals, awayGoals, matchday, status }}
 */
function mapMatchResult(match) {
  const score = match.score?.fullTime || {};
  return {
    matchId: match.id,
    homeTeam: match.homeTeam?.name || "",
    awayTeam: match.awayTeam?.name || "",
    homeGoals: score.home ?? null,
    awayGoals: score.away ?? null,
    matchday: match.matchday,
    status: match.status,
  };
}

module.exports = {
  getMatches,
  getAllMatches,
  getTopScorers,
  getTeams,
  getMatch,
  getStandings,
  mapScorerToStats,
  mapMatchResult,
};
