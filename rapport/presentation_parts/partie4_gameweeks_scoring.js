const fs = require("fs");
const { Document, Packer, Paragraph, PageBreak, TextRun } = require("docx");
const C = require("./common");
const bi = (label, rest) => C.bulletRich([new TextRun({ text: label, bold: true }), new TextRun({ text: rest })]);
const br = () => new Paragraph({ children: [new PageBreak()] });

const children = [
  ...C.titlePage(
    "Partie 4 — Gameweeks, Scoring & Temps réel",
    "Cycle de vie des journées, calendrier réel, battles et Socket.IO",
    "Membre 4 (Responsable Gameweeks, Scoring & Temps réel)"
  ),
  br(),

  C.h1("1. Mon rôle dans le projet"),
  C.p("Je suis responsable du cycle de vie des journées de compétition (gameweeks), de la logique de calcul des points, des duels tête-à-tête entre managers (battles), et de l'infrastructure temps réel (Socket.IO) qui permet à l'application de réagir instantanément aux événements de jeu."),

  C.h1("2. Cycle de vie d'une journée (Gameweek)"),
  C.p("Fichiers : controllers/gameweek.controller.js, routes/gameweek.routes.js"),
  C.h2("2.1 Les trois états d'une journée"),
  C.tableN(
    ["Statut", "Signification"],
    [
      ["upcoming", "Journée à venir, avant la date limite (deadline) de composition d'équipe"],
      ["active", "Deadline passée, matchs en cours ou scores en cours de finalisation"],
      ["completed", "Scores finalisés, points distribués, battles résolus"],
    ],
    [2500, 7138]
  ),
  C.h2("2.2 Endpoints principaux"),
  C.tableN(
    ["Endpoint", "Fonction"],
    [
      ["GET /api/gameweeks/current", "Journée active ou prochaine à venir (cache 1 min)"],
      ["POST /api/gameweeks (admin)", "Création d'une nouvelle journée (numéro, saison, deadline)"],
      ["PATCH …/:id/start (admin)", "Passage à active, clôture automatique de la précédente journée active"],
      ["PATCH …/:id/finish (admin)", "Clôture : recalcul de tous les scores d'équipes, résolution des battles, passage à completed"],
      ["POST …/:id/scores (admin)", "Saisie des statistiques réelles des joueurs (buts, passes, minutes, cartons...)"],
      ["GET …/:id/team-scores", "Classement des équipes pour la journée (points décroissants)"],
      ["GET …/:id/my-breakdown", "Détail personnel : contribution de chaque joueur de mon équipe à mon score"],
    ],
    [3700, 5938]
  ),

  C.h2("2.3 Automatisation du cycle (jobs/scoreSync.job.js)"),
  C.p("Une tâche planifiée (cron, 30 min) automatise tout le cycle sans intervention manuelle : démarrage de la prochaine journée due, récupération des scores réels depuis football-data.org, recalcul des points, et avancement automatique vers la journée suivante lorsque tous les matchs d'une journée sont terminés (statut FINISHED)."),

  br(),
  C.h1("3. Calcul des points (barème détaillé)"),
  C.p("La grille de points est centralisée dans utils/scoring.js et appliquée de façon identique que le calcul soit déclenché manuellement par un administrateur ou automatiquement par le cron — un point de cohérence essentiel du projet."),
  C.tableN(
    ["Poste", "But", "Passe décisive", "Cage inviolée", "Carton jaune", "Carton rouge"],
    [
      ["Gardien (GK)", "10", "6", "6", "-1", "-3"],
      ["Défenseur (DEF)", "6", "3", "4", "-1", "-3"],
      ["Milieu (MID)", "5", "3", "1", "-1", "-3"],
      ["Attaquant (FWD)", "4", "3", "0", "-1", "-3"],
    ],
    [2400, 1450, 1900, 1900, 1100, 888]
  ),
  C.p("Règles complémentaires : +2 si le joueur joue ≥ 60 minutes, +1 entre 1 et 59 minutes, +5 si triplé (≥ 3 buts), -2 par but contre son camp, +5 par penalty arrêté (gardien), -2 par penalty manqué, +1 toutes les 3 parades (gardien uniquement). Le total individuel est plafonné à un minimum de 0 (sauf intervention de la chip Shield qui le force explicitement)."),
  C.p("Le capitaine d'une équipe voit son score doublé (×2), ou triplé (×3) si la chip Triple Captain est active pour la journée — logique implémentée dans la fonction partagée sumTeamGwPoints()."),

  C.h2("3.1 Stockage des statistiques"),
  C.p("La table player_scores contient une ligne par (joueur, journée) avec toutes les statistiques brutes (buts, passes, cage inviolée, cartons, minutes, bonus, but contre son camp, penaltys), plus le total calculé total_points. Cette table est alimentée soit manuellement par un administrateur (saisie d'après les résultats réels), soit automatiquement par le job de synchronisation."),

  br(),
  C.h1("4. Calendrier réel & intégration football-data.org"),
  C.p("Fichiers : controllers/matches.controller.js, services/footballData.service.js"),
  C.p("La table matches stocke le vrai calendrier de la Coupe du Monde 2026 (104 rencontres), importé une première fois via le script scripts/seed-gameweeks.js, qui crée également automatiquement 8 journées fantasy (3 journées de poule + tours à élimination directe) avec une date limite calée une heure avant le premier coup d'envoi de chaque journée."),
  C.p("Un service applicatif dédié (footballData.service.js) encapsule les appels HTTP vers l'API externe, avec un système de throttling pour respecter la limite gratuite de 10 requêtes par minute. En cas d'indisponibilité de l'API, un calendrier synthétique de repli est généré pour ne jamais bloquer la démonstration."),

  br(),
  C.h1("5. Battles — duels tête-à-tête"),
  C.p("Fichiers : controllers/battle.controller.js (221 lignes), routes/battle.routes.js"),
  C.p("Une battle oppose deux équipes d'une même ligue sur une journée donnée : le total de points fantasy de chaque équipe sur cette journée détermine le vainqueur, comme un mini-match dans le match."),
  C.tableN(
    ["Endpoint", "Fonction"],
    [
      ["GET /api/battles/:leagueId", "Liste des battles de la ligue (cache 60 s)"],
      ["GET /api/battles/:battleId", "Détail enrichi : liste des joueurs des deux équipes avec leurs points individuels et badge capitaine"],
      ["POST /api/battles/:leagueId (admin)", "Programmation d'un duel (équipe domicile/extérieur, journée)"],
      ["PATCH /api/battles/:battleId (admin)", "Mise à jour du score, diffusion temps réel de l'événement"],
      ["GET /api/battles/:battleId/live", "Score en direct (cache court, 10 s)"],
    ],
    [3700, 5938]
  ),
  C.p("À la clôture d'une journée, les battles programmées se résolvent automatiquement en comparant les totaux de points des deux équipes."),

  br(),
  C.h1("6. Temps réel avec Socket.IO"),
  C.p("Fichiers : socket/socket.js"),
  C.h2("6.1 Authentification du canal WebSocket"),
  C.p("Avant d'accepter une connexion, le serveur vérifie un jeton JWT transmis dans le handshake (auth.token ou en-tête Authorization), exactement comme pour l'API REST — la sécurité n'est pas relâchée simplement parce qu'on change de protocole."),
  C.h2("6.2 Organisation en « rooms »"),
  C.bullet("Chaque utilisateur rejoint automatiquement une room personnelle user:{userId}, utile pour des notifications individuelles."),
  C.bullet("league:join / league:leave permettent de rejoindre/quitter la room d'une ligue (league:{leagueId}), après vérification d'appartenance réelle à cette ligue en base."),
  C.bullet("L'isolation par room garantit qu'un utilisateur ne reçoit jamais d'événements d'une ligue dont il n'est pas membre."),
  C.h2("6.3 Événements principaux"),
  C.tableN(
    ["Événement", "Déclenchement"],
    [
      ["scores:updated", "Après recalcul des scores par le job ou un administrateur"],
      ["team:points_updated", "Mise à jour du total de points d'une équipe"],
      ["battle:score_update", "Modification du score d'un duel"],
      ["league:presence", "Diffusion périodique des membres actuellement en ligne dans la ligue"],
      ["chat:typing / chat:message", "Indicateur de frappe et nouveau message de chat (voir module Social)"],
    ],
    [3000, 6638]
  ),
  C.p("Ce mécanisme évite tout polling côté mobile : l'application reste à jour instantanément sans rafraîchir manuellement, ce qui est essentiel pour suivre un match en direct."),

  br(),
  C.h1("7. Schéma de base de données concerné"),
  C.tableN(
    ["Table", "Colonnes clés"],
    [
      ["gameweeks", "id, number, season, status, deadline, started_at, finished_at"],
      ["player_scores", "player_id, gameweek_id, goals, assists, clean_sheet, cards, minutes_played, total_points"],
      ["team_gameweek_scores", "team_id, gameweek_id, points, captain_id"],
      ["matches", "fd_match_id, matchday, home/away_team, home/away_goals, status, kickoff, gameweek_id"],
      ["battles", "league_id, home_team_id, away_team_id, home_score, away_score, status, gameweek"],
    ],
    [2300, 7338]
  ),

  C.h1("8. Choix techniques et justifications"),
  bi("Pourquoi Socket.IO plutôt que des WebSockets natifs ? ", "Gestion automatique du fallback (polling HTTP si WebSocket indisponible), API de rooms intégrée, et reconnexion automatique côté client — gain de temps de développement significatif pour un projet académique avec délai serré."),
  bi("Pourquoi un cron de 30 minutes pour la synchronisation plutôt qu'un webhook ? ", "football-data.org en offre gratuite ne propose pas de webhooks ; le polling périodique reste la seule option compatible avec le tier gratuit."),
  bi("Pourquoi centraliser le calcul de points dans une seule fonction partagée ? ", "Éviter toute divergence entre un recalcul manuel par un administrateur et le recalcul automatique du cron — un bug classique des systèmes de scoring serait d'avoir deux implémentations qui finissent par diverger."),

  C.h1("9. Difficultés rencontrées et solutions"),
  C.bullet("Le tier gratuit de football-data.org limite strictement les requêtes → throttling interne (~6,1 s entre appels) et cache Redis pour éviter les appels redondants sur les mêmes données."),
  C.bullet("Risque de double comptage des points si le job et un administrateur recalculent en même temps → la fonction de calcul est idempotente (upsert avec ON CONFLICT), donc rejouer le calcul ne fausse jamais le résultat final."),
  C.bullet("Présence en ligne (league:presence) pouvait spammer le réseau si diffusée à chaque connexion → mise en place d'un throttling des diffusions de présence."),
  C.bullet("Disponibilité de l'API externe non garantie en démonstration → calendrier synthétique de repli pour ne jamais bloquer la présentation devant le jury."),

  C.h1("10. Questions probables du jury & pistes de réponse"),
  bi("« Que se passe-t-il si un match est interrompu ou rejoué ? » ", "Le statut du match (SCHEDULED/IN_PLAY/FINISHED) est resynchronisé à chaque cycle ; les scores ne sont définitivement figés que lorsque la journée correspondante passe à completed."),
  bi("« Comment gérez-vous la simultanéité de plusieurs administrateurs qui clôturent une journée ? » ", "L'opération de clôture est idempotente : la relancer ne duplique pas les points, elle les recalcule à l'identique à partir des mêmes données sources."),
  bi("« Pourquoi le classement n'est-il pas recalculé en continu pendant un match en direct ? » ", "Il l'est, à la fréquence du cron (30 min) plus les mises à jour manuelles ; un calcul à la seconde nécessiterait un flux de données payant, hors de portée du projet académique."),
  bi("« Les battles influencent-elles le classement général de la ligue ? » ", "Non : les battles sont un mini-jeu social à part, le classement général de la ligue repose uniquement sur le total de points fantasy cumulés de chaque manager."),
];

const doc = new Document({
  styles: C.styles(),
  numbering: C.numbering(),
  sections: [{
    properties: { page: C.PAGE },
    headers: { default: C.header("WC Fantasy — Gameweeks, Scoring & Temps réel") },
    footers: { default: C.footer() },
    children,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync("D:/pfa/rapport/presentation_parts/Partie4_Gameweeks_Scoring_TempsReel.docx", buf);
  console.log("OK Partie4");
});
