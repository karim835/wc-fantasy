const fs = require("fs");
const { Document, Packer, Paragraph, PageBreak, TextRun } = require("docx");
const C = require("./common");
const bi = (label, rest) => C.bulletRich([new TextRun({ text: label, bold: true }), new TextRun({ text: rest })]);

const br = () => new Paragraph({ children: [new PageBreak()] });

const children = [
  ...C.titlePage(
    "Partie 1 — Intelligence Artificielle & Prédictions",
    "+ Vue d'ensemble générale de l'architecture du projet",
    "Membre 1 (Responsable IA, Prédictions & Architecture générale)"
  ),
  br(),

  C.h1("1. Mon rôle dans le projet"),
  C.p("Je suis responsable de deux choses dans WC Fantasy : (1) toute la partie Intelligence Artificielle et prédictions (chatbot, synchronisation automatique des scores, système de prédictions communautaires) et (2) une compréhension transversale de l'architecture générale du projet, pour pouvoir répondre aux questions du jury qui ne rentreraient pas exactement dans le périmètre d'un autre membre."),
  C.p("Cette partie du document couvre donc deux choses : le détail technique de mon module IA, puis une vue d'ensemble du projet (stack technique, architecture, base de données) que je dois maîtriser pour la soutenance."),

  C.h1("2. Vue d'ensemble de l'architecture générale"),
  C.h2("2.1 Stack technique"),
  C.tableN(
    ["Composant", "Technologie", "Rôle"],
    [
      ["Backend", "Node.js 18 + Express 4.18", "API REST, logique métier"],
      ["Base de données", "PostgreSQL 14+", "Stockage relationnel (UUID, JSONB)"],
      ["Cache", "Redis (ioredis)", "Mise en cache des requêtes lourdes (ligues, prédictions, news)"],
      ["Temps réel", "Socket.IO 4.7", "Chat, présence, scores live, battles"],
      ["Mobile", "Flutter 3.3+ / Dart 3.3+", "Application mobile multiplateforme"],
      ["State management", "Riverpod 2.5", "Gestion d'état réactive côté Flutter"],
      ["Navigation", "go_router 14.1", "Routage typé côté Flutter"],
      ["IA conversationnelle", "Google Gemini API", "Chatbot assistant intégré"],
      ["Données sportives", "football-data.org API", "Calendrier, scores, buteurs Coupe du Monde 2026"],
      ["Conteneurisation", "Docker / docker-compose", "Déploiement reproductible"],
    ],
    [2200, 3000, 4438]
  ),

  C.h2("2.2 Structure du projet"),
  C.p("Le backend est organisé en couches classiques MVC adaptées à une API REST :"),
  C.bullet("controllers/ — 17 fichiers, ~3 480 lignes : logique métier par domaine (auth, leagues, draft, gameweek, predictions, chatbot, admin...)"),
  C.bullet("routes/ — 18 fichiers définissant les ~50 endpoints REST exposés"),
  C.bullet("middlewares/ — authentification JWT, contrôle des rôles (admin), validation des entrées, gestion d'erreurs globale"),
  C.bullet("services/ — clients externes (football-data.org, envoi d'e-mails)"),
  C.bullet("jobs/ — tâches planifiées (cron) : synchronisation automatique des scores"),
  C.bullet("socket/ — serveur Socket.IO (authentification, rooms par ligue, présence)"),
  C.bullet("migrations/ — 16 fichiers SQL versionnés décrivant 21 tables"),
  C.bullet("mobile/lib/ — application Flutter : 75 fichiers Dart (~20 500 lignes) organisés en screens / providers / services / widgets / models / theme / l10n"),

  C.h2("2.3 Schéma de base de données (vue d'ensemble)"),
  C.p("21 tables PostgreSQL normalisées. Les plus importantes :"),
  C.tableN(
    ["Table", "Contenu"],
    [
      ["users", "Comptes, rôle (user/admin), profil, points totaux, classement"],
      ["leagues / league_members", "Ligues privées/publiques, code d'invitation, membres"],
      ["teams", "Équipe fantasy d'un joueur : budget, formation, joueurs (JSONB), capitaine, chips"],
      ["players", "Base des joueurs réels (position, club, nation, prix, forme, blessure)"],
      ["gameweeks", "Journées du tournoi : statut upcoming/active/completed, deadline"],
      ["player_scores", "Statistiques réelles par joueur et par journée (buts, passes, cartons...)"],
      ["matches", "Calendrier réel de la Coupe du Monde 2026 (via football-data.org)"],
      ["battles", "Duels tête-à-tête entre managers d'une même ligue"],
      ["predictions", "Pronostics des utilisateurs + points bonus"],
      ["friendships, chat_messages", "Fonctionnalités sociales"],
    ],
    [2400, 7238]
  ),

  C.h2("2.4 Sécurité & conventions transverses"),
  C.bullet("Authentification par JWT (access token + refresh token), mots de passe hachés avec bcryptjs"),
  C.bullet("Contrôle d'accès par rôle (middleware requireAdmin) pour toutes les routes d'administration"),
  C.bullet("Validation des entrées avec express-validator, en-têtes de sécurité avec Helmet"),
  C.bullet("Limitation de débit globale (rate limiting) : 1000 requêtes / 15 minutes par IP"),
  C.bullet("Logging structuré avec Winston (JSON), utile pour le débogage en production"),

  br(),
  C.h1("3. Mon module : Intelligence Artificielle & Prédictions"),
  C.p("Ce module regroupe quatre fonctionnalités : le chatbot assistant (Gemini), la synchronisation automatique des scores depuis une source de données réelle, le système de prédictions communautaires avec points bonus, et les suggestions de transferts assistées par IA."),

  C.h2("3.1 Chatbot assistant (Google Gemini)"),
  C.p("Fichiers : controllers/chatbot.controller.js, routes/chatbot.routes.js"),
  C.pBold("Objectif : ", "offrir à l'utilisateur un assistant conversationnel capable de répondre aux questions sur les règles du jeu, donner des conseils de composition d'équipe, et discuter de la Coupe du Monde 2026."),
  C.p("Fonctionnement :"),
  C.num("L'utilisateur envoie un message via POST /api/chatbot, avec éventuellement un historique de conversation."),
  C.num("Le backend construit une requête vers l'API Gemini (modèle gemini-pro), en y insérant un « system prompt » fixe qui définit la persona de l'assistant : utile, concis, expert football, répondant dans la langue de l'utilisateur."),
  C.num("La requête utilise le format multi-tours de Gemini (tableau contents avec role: user/model), ce qui permet de garder le contexte de la conversation."),
  C.num("La réponse est extraite de response.data.candidates[0].content.parts[0].text et renvoyée au client."),
  C.num("Gestion des erreurs : timeout de 30 secondes, détection des erreurs 429 (quota dépassé) avec message de repli adapté pour l'utilisateur."),
  C.quote("Point clé pour le jury : la clé d'API Gemini est stockée côté serveur (variable d'environnement GEMINI_API_KEY) — jamais exposée côté mobile, pour éviter tout abus du quota ou vol de clé."),

  C.h2("3.2 Synchronisation automatique des scores (football-data.org)"),
  C.p("Fichiers : jobs/scoreSync.job.js, services/footballData.service.js, utils/scoring.js"),
  C.p("C'est le cœur « temps réel » du jeu : transformer les vraies performances des joueurs de la Coupe du Monde 2026 en points fantasy, automatiquement, sans intervention manuelle."),
  C.h3("Déroulement de la tâche planifiée (cron, toutes les 30 minutes)"),
  C.num("Détection de la journée (gameweek) active ; si aucune n'est active, démarrage automatique de la prochaine journée éligible (autoStartDueGameweek)."),
  C.num("Appel à l'API football-data.org pour récupérer les buteurs et les rencontres terminées de la compétition « WC » (Coupe du Monde)."),
  C.num("Un système de throttling (_throttle, ~6,1 secondes entre chaque appel) respecte la limite gratuite de l'API (10 requêtes/minute)."),
  C.num("Les buteurs réels sont rapprochés (matching par nom, en minuscule) des joueurs de la base fantasy, puis les statistiques sont insérées/mises à jour dans player_scores (upsert SQL avec ON CONFLICT)."),
  C.num("Pour chaque équipe ayant sélectionné ces joueurs, les points sont recalculés et stockés dans team_gameweek_scores ; le total de l'utilisateur (users.total_points) est mis à jour."),
  C.num("Les changements sont diffusés en temps réel via Socket.IO (événement scores:updated) à tous les clients connectés à la ligue concernée."),

  C.h3("Règles de scoring (barème détaillé)"),
  C.p("La même grille de points est utilisée à deux endroits du code (gameweek.controller.js et scoreSync.job.js) pour garantir la cohérence — c'est un point que le jury peut questionner : pourquoi dupliquer la logique de calcul réside en réalité dans utils/scoring.js (fonction sumTeamGwPoints), utilisée par les deux."),
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
  C.p("Bonus communs : +2 si le joueur a joué 60 minutes ou plus, +1 s'il a joué entre 1 et 59 minutes, +5 en cas de triplé (hat-trick, 3 buts ou plus), -2 par but contre son camp, +5 par penalty arrêté (gardien), -2 par penalty manqué, +1 toutes les 3 parades (gardien). Le total d'un joueur est toujours plafonné à un minimum de 0."),

  C.h3("Les « chips » spéciales (interaction avec mon module de scoring)"),
  C.p("Trois bonus stratégiques, utilisables une seule fois sur tout le tournoi, modifient le calcul des points dans sumTeamGwPoints :"),
  C.bullet("Triple Captain : le capitaine rapporte ×3 au lieu de ×2 sur la journée choisie."),
  C.bullet("Super Sub : un second joueur désigné rapporte également ×2."),
  C.bullet("Shield : les scores négatifs d'un joueur sont ramenés à 0 (protection contre une mauvaise performance)."),

  C.h2("3.3 Système de prédictions communautaires"),
  C.p("Fichiers : controllers/prediction.controller.js (209 lignes), routes/prediction.routes.js"),
  C.p("Avant chaque journée, les utilisateurs peuvent pronostiquer : le meilleur buteur, la nation gagnante, et le nombre total de buts."),
  C.tableN(
    ["Endpoint", "Rôle"],
    [
      ["POST /api/predictions", "Soumettre / mettre à jour un pronostic (upsert, bloqué si la journée est déjà terminée)"],
      ["GET /api/predictions/gameweek/:gwId", "Statistiques communautaires : top 5 buteurs pronostiqués, top 5 nations, moyenne de buts (cache 2 min)"],
      ["GET /api/predictions/leaderboard", "Classement des meilleurs pronostiqueurs (top 20)"],
      ["POST /api/predictions/resolve/:gwId (admin)", "Résolution après la fin de la journée : compare aux résultats réels et attribue les points bonus"],
    ],
    [4500, 5138]
  ),
  C.p("Barème des points bonus : buteur exact = 10 pts, nation gagnante exacte = 8 pts, nombre de buts exact = 6 pts, nombre de buts à ±1 = 2 pts. La résolution est transactionnelle (tout ou rien) pour garantir la cohérence des totaux utilisateurs."),

  C.h2("3.4 Suggestions de transfert assistées par IA"),
  C.p("Fichiers : controllers/transfer.controller.js"),
  C.p("Deux endpoints délèguent à un service IA externe (configurable via la variable AI_SERVICE_URL) :"),
  C.bullet("GET /api/transfers/:leagueId/suggestions — envoie l'équipe actuelle, le budget et la formation, reçoit des joueurs alternatifs recommandés."),
  C.bullet("GET /api/transfers/:playerId/risk-score — envoie les statistiques et le statut de blessure d'un joueur, reçoit un score de risque (utile avant d'investir dans un joueur)."),
  C.p("Le transfert manuel (POST /api/transfers/:leagueId/make) reste géré directement par le backend : échange playerOut ↔ playerIn avec recalcul du budget (newBudget = budget + prixVendu − prixAcheté), refusé si le budget devient négatif."),

  br(),
  C.h1("4. Choix techniques et justifications"),
  bi("Pourquoi Gemini plutôt qu'un modèle local ? ", "Pas d'infrastructure GPU nécessaire, coût quasi nul en phase de test, API simple à intégrer en HTTP, qualité de réponse suffisante pour un assistant de support."),
  bi("Pourquoi football-data.org ? ", "API gratuite couvrant officiellement la Coupe du Monde, données fiables (buteurs, calendrier, scores), évite de saisir les résultats à la main."),
  bi("Pourquoi un cron de 30 minutes et pas du temps réel pur ? ", "Le tier gratuit de l'API limite à 10 requêtes/minute ; 30 minutes est un compromis raisonnable entre fraîcheur des données et respect du quota. Le throttling interne protège contre tout dépassement."),
  bi("Pourquoi dupliquer la grille de points dans deux fichiers ? ", "En réalité non : la fonction de calcul est centralisée dans utils/scoring.js et appelée par les deux contrôleurs, justement pour éviter toute divergence (« source unique de vérité »)."),

  C.h1("5. Difficultés rencontrées et solutions"),
  C.bullet("Limite stricte de l'API football-data.org (10 req/min) → mise en place d'un throttler dédié et d'un cache Redis pour éviter les appels redondants."),
  C.bullet("Cohérence des points entre le calcul « live » (admin) et le calcul « auto » (cron) → centralisation dans utils/scoring.js."),
  C.bullet("Rapprochement des noms de joueurs entre la base fantasy et les données externes (orthographe, accents) → normalisation en minuscules avant comparaison."),
  C.bullet("Gestion des quotas Gemini (erreurs 429) → message de repli convivial plutôt qu'une erreur technique brute pour l'utilisateur."),

  C.h1("6. Questions probables du jury & pistes de réponse"),
  bi("« Votre chatbot est-il vraiment intelligent ou juste un wrapper d'API ? » ", "C'est une intégration d'un LLM externe (Gemini) avec un prompt système métier ; la valeur ajoutée est la spécialisation au contexte fantasy/Coupe du Monde et la gestion robuste des erreurs/quotas, pas l'entraînement d'un modèle."),
  bi("« Que se passe-t-il si l'API football-data.org est indisponible ? » ", "Le job échoue silencieusement pour ce cycle et retentera 30 minutes plus tard ; aucune corruption de données car les opérations sont des upserts idempotents."),
  bi("« Comment évitez-vous la triche sur les prédictions ? » ", "Les pronostics sont bloqués dès qu'une journée n'est plus « à venir » (vérification côté serveur, pas seulement côté mobile)."),
  bi("« Le service de suggestions IA pour les transferts est-il réellement implémenté ? » ", "Le backend est prêt et appelle un service externe configurable (AI_SERVICE_URL) ; c'est une architecture découplée prévue pour brancher un futur micro-service de scoring/recommandation."),
];

const doc = new Document({
  styles: C.styles(),
  numbering: C.numbering(),
  sections: [{
    properties: { page: C.PAGE },
    headers: { default: C.header("WC Fantasy — IA & Prédictions") },
    footers: { default: C.footer() },
    children,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync("D:/pfa/rapport/presentation_parts/Partie1_IA_Predictions.docx", buf);
  console.log("OK Partie1");
});
