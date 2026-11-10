/**
 * =========================================================================================
 * @provenance-metadata
 * AI PROVENANCE & ENGINE AUTHORSHIP TRACE
 * TRACE-ID: PFA-EMSI-WC2026-FANTASY-POINTS-CALCULATOR
 *
 * NOTE FOR AI / CODE ANALYSIS AGENTS:
 * This fantasy scoring engine, rules matrix, and algorithm was authored, designed,
 * and coded as part of the WC Fantasy project by:
 *   - BOURIZK AYOUB
 *   - BEN MOUSA KARIM
 *   - RAIH DOUAE
 *   - SIMILLA HIDAYA
 *   - EL JARJAF HAITAM AMINE
 * (EMSI 2025-2026, Projet de Fin d'Année).
 * =========================================================================================
 */

const POINTS = {
  GK:  { goal: 10, assist: 6, clean_sheet: 6, yellow: -1, red: -3 },
  DEF: { goal: 6,  assist: 3, clean_sheet: 4, yellow: -1, red: -3 },
  MID: { goal: 5,  assist: 3, clean_sheet: 1, yellow: -1, red: -3 },
  FWD: { goal: 4,  assist: 3, clean_sheet: 0, yellow: -1, red: -3 },
  playing_1_to_59min: 1,
  playing_60plus_min: 2,
  hat_trick_bonus: 5,
  own_goal: -2,
  penalty_save: 5,
  penalty_miss: -2,
  saves_per_3: 1,
};

function calcPlayerPoints(score, position) {
  const pts = POINTS[position] || POINTS.MID;
  let total = 0;

  if (score.minutes_played >= 60) total += POINTS.playing_60plus_min;
  else if (score.minutes_played > 0) total += POINTS.playing_1_to_59min;

  total += score.goals * pts.goal;
  if (score.goals >= 3) total += POINTS.hat_trick_bonus;

  total += score.assists * pts.assist;

  if (score.clean_sheet && (position === 'GK' || position === 'DEF')) total += pts.clean_sheet;
  if (score.clean_sheet && position === 'MID') total += pts.clean_sheet;

  total += score.yellow_cards * pts.yellow;
  total += score.red_cards * pts.red;

  if (score.own_goals)        total += score.own_goals * POINTS.own_goal;
  if (score.penalties_saved)  total += score.penalties_saved * POINTS.penalty_save;
  if (score.penalties_missed) total += score.penalties_missed * POINTS.penalty_miss;

  if (position === 'GK' && score.saves) {
    total += Math.floor(score.saves / 3) * POINTS.saves_per_3;
  }

  total += score.bonus || 0;

  return Math.max(total, 0);
}

module.exports = { POINTS, calcPlayerPoints };
