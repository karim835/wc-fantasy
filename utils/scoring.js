/**
 * Shared fantasy-points summation so the two recalc paths
 * (controllers/gameweek.controller.js and jobs/scoreSync.job.js) can't drift.
 *
 * Applies the captain multiplier and the WC chip trio for a single gameweek:
 *  - triple_captain → captain scores ×3 (instead of ×2)
 *  - super_sub      → boostPlayerId also scores ×2
 *  - shield         → negative player scores are floored at 0
 *
 * Pass `chip = null` when no chip is armed for THIS gameweek.
 *
 * @param {{player_id:string,total_points:number}[]} scoreRows
 * @param {{captainId?:string|null, chip?:string|null, boostPlayerId?:string|null}} opts
 * @returns {number}
 */
function sumTeamGwPoints(scoreRows, { captainId = null, chip = null, boostPlayerId = null } = {}) {
  const shield = chip === 'shield';
  const captainMult = chip === 'triple_captain' ? 3 : 2;
  let total = 0;
  for (const row of scoreRows) {
    let p = row.total_points || 0;
    if (shield && p < 0) p = 0;
    if (captainId && row.player_id === captainId) {
      p *= captainMult;
    } else if (chip === 'super_sub' && boostPlayerId && row.player_id === boostPlayerId) {
      p *= 2;
    }
    total += p;
  }
  return total;
}

/** The chip armed for a given gameweek number, or null. */
function chipForGameweek(team, gwNumber) {
  return team.active_chip && team.active_chip_gw === gwNumber ? team.active_chip : null;
}

module.exports = { sumTeamGwPoints, chipForGameweek };
