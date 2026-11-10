const fs = require("fs");
const { Document, Packer, Paragraph, PageBreak, TextRun } = require("docx");
const C = require("./common");
const bi = (label, rest) => C.bulletRich([new TextRun({ text: label, bold: true }), new TextRun({ text: rest })]);
const br = () => new Paragraph({ children: [new PageBreak()] });

const children = [
  ...C.titlePage(
    "Partie 2 — Authentification & Gestion des utilisateurs",
    "Comptes, rôles, profils, sécurité et administration",
    "Membre 2 (Responsable Authentification & Utilisateurs)"
  ),
  br(),

  C.h1("1. Mon rôle dans le projet"),
  C.p("Je suis responsable de tout ce qui concerne le compte utilisateur dans WC Fantasy : inscription, connexion, sécurité des accès, gestion du profil, et le module d'administration qui permet de gérer les utilisateurs, les ligues et les joueurs depuis un tableau de bord."),
  C.p("Cette partie est le « socle » du projet : sans authentification fiable, aucune autre fonctionnalité (ligues, draft, prédictions) ne peut identifier qui fait quoi."),

  C.h1("2. Inscription, connexion et jetons JWT"),
  C.p("Fichiers : controllers/auth.controller.js, middlewares/auth.js, routes/auth.routes.js"),

  C.h2("2.1 Inscription (POST /api/auth/register)"),
  C.num("Réception des champs : username, email, password, date_of_birth, country, favorite_nation, favorite_club, favorite_player, bio."),
  C.num("Vérification d'unicité de l'email et du nom d'utilisateur en base."),
  C.num("Hachage du mot de passe avec bcryptjs (facteur de coût 12) — le mot de passe en clair n'est jamais stocké."),
  C.num("Création de la ligne utilisateur, puis génération immédiate des jetons d'authentification."),

  C.h2("2.2 Connexion (POST /api/auth/login) et jetons"),
  C.p("Le système utilise une paire de jetons JWT, pattern standard pour sécuriser une API REST sans état (stateless) :"),
  C.tableN(
    ["Jeton", "Durée de vie", "Rôle"],
    [
      ["Access Token", "7 jours (configurable)", "Envoyé dans l'en-tête Authorization: Bearer <token> à chaque requête protégée"],
      ["Refresh Token", "30 jours (configurable)", "Stocké en base (table refresh_tokens), utilisé pour obtenir un nouvel access token sans redemander le mot de passe"],
    ],
    [1800, 2200, 5638]
  ),
  C.p("À la connexion : récupération de l'utilisateur par email, comparaison du mot de passe avec bcrypt.compare(), génération des deux jetons, insertion du refresh token en base avec sa date d'expiration."),

  C.h2("2.3 Middleware d'authentification"),
  C.p("La fonction authenticate() (middlewares/auth.js) s'exécute avant chaque route protégée :"),
  C.bullet("Extraction du jeton depuis l'en-tête Authorization."),
  C.bullet("Vérification cryptographique avec jwt.verify() et la clé secrète JWT_SECRET."),
  C.bullet("Si valide, chargement de l'utilisateur en base (y compris son rôle) et attachement à req.user pour les contrôleurs suivants."),
  C.bullet("Si le jeton est expiré ou invalide, réponse 401 immédiate — aucune route protégée n'est exécutée sans utilisateur authentifié."),

  C.h2("2.4 Réinitialisation de mot de passe"),
  C.p("Fichiers : auth.controller.js (resetPasswordRequest, confirmReset), services/emailService.js"),
  C.num("L'utilisateur demande une réinitialisation via son email (POST /api/auth/forgot-password)."),
  C.num("Un jeton aléatoire est généré, puis haché (SHA-256) avant d'être stocké en base — même principe que pour un mot de passe : on ne stocke jamais le secret en clair."),
  C.num("Un e-mail (via Nodemailer/SMTP) contient un lien avec le jeton en clair, valable 10 minutes."),
  C.num("À la confirmation (POST /api/auth/reset-password), le jeton reçu est haché et comparé à celui stocké ; si valide et non expiré, le mot de passe est mis à jour et le jeton supprimé."),

  br(),
  C.h1("3. Rôles et contrôle d'accès (Admin)"),
  C.h2("3.1 Le rôle administrateur"),
  C.p("La table users contient une colonne role (valeur par défaut 'user'). Un middleware dédié, requireAdmin, vérifie req.user.role === 'admin' et renvoie une erreur 403 sinon. Ce middleware protège l'ensemble des routes /api/admin/* ainsi que certaines actions sensibles des autres modules (création/démarrage/clôture d'une journée, par exemple)."),
  C.quote("Un compte administrateur de démonstration est créé via le script create-admin.js (admin@wc2026.com), pratique pour la soutenance afin de montrer rapidement le tableau de bord."),

  C.h2("3.2 Tableau de bord d'administration"),
  C.p("Fichiers : controllers/admin.controller.js (217 lignes), routes/admin.routes.js, écran mobile admin_dashboard_screen.dart"),
  C.tableN(
    ["Endpoint", "Fonction"],
    [
      ["GET /api/admin/overview", "Statistiques globales : nb d'utilisateurs/ligues/joueurs, inscriptions des 14 derniers jours, infos système (uptime, mémoire, version BD)"],
      ["GET /api/admin/users", "Liste paginée des utilisateurs avec recherche (nom/email)"],
      ["PATCH /api/admin/users/:id/role", "Promotion/rétrogradation d'un utilisateur (auto-rétrogradation interdite)"],
      ["DELETE /api/admin/users/:id", "Suppression d'un compte (auto-suppression interdite, suppression en cascade)"],
      ["GET /api/admin/leagues", "Liste des ligues avec recherche par nom"],
      ["DELETE /api/admin/leagues/:id", "Suppression d'une ligue"],
      ["PATCH /api/admin/players/:id", "Modification des métadonnées d'un joueur (prix, blessure, points, forme)"],
    ],
    [3700, 5938]
  ),
  C.p("Côté mobile, l'accès au menu Administration est conditionné par un Provider Riverpod (isAdminProvider) qui masque l'entrée de menu si l'utilisateur n'est pas admin — en plus de la protection serveur, qui reste la seule barrière réellement fiable (la vérification côté mobile n'est qu'un confort visuel)."),

  br(),
  C.h1("4. Profil utilisateur, avatar et paramètres"),
  C.h2("4.1 Gestion du profil"),
  C.p("Fichiers : controllers/users.controller.js, routes/users.routes.js"),
  C.bullet("GET /api/users/profile — récupération du profil courant (inclut le rôle, le rang, la date de création)."),
  C.bullet("PATCH /api/users/profile — mise à jour des champs (bio, nation favorite, club favori, joueur favori, et désormais l'email avec gestion du conflit d'unicité, code erreur 409)."),
  C.bullet("DELETE /api/users/account — suppression définitive du compte (cascade sur ses ligues, équipes, prédictions, amitiés)."),

  C.h2("4.2 Upload d'avatar"),
  C.p("Endpoint POST /api/auth/avatar : réception d'une image encodée en base64 (JSON, limite 10 Mo déjà configurée sur express.json), écriture du fichier dans uploads/avatars/<userId>.<ext>, puis mise à jour de users.avatar_url vers une route de diffusion publique GET /api/photos/avatar/:userId."),
  C.p("Cette route de diffusion ajoute volontairement les en-têtes Access-Control-Allow-Origin: * et Cross-Origin-Resource-Policy: cross-origin, nécessaires car la version de développement de l'application est Flutter Web, plus stricte en matière de CORS que les applications mobiles natives."),
  C.p("Côté mobile : image_picker (redimensionnement max 512px, qualité 70%) pour limiter la taille avant envoi."),

  C.h2("4.3 Paramètres utilisateur"),
  C.p("Une table dédiée user_settings stocke les préférences de notifications (battles, chat, actualités), modifiables depuis l'écran Réglages de l'application mobile."),

  br(),
  C.h1("5. Schéma de base de données concerné"),
  C.tableN(
    ["Table", "Colonnes clés", "Remarque"],
    [
      ["users", "id, username, email, password_hash, role, total_points, rank, avatar_url, created_at", "Table centrale, référencée par presque toutes les autres"],
      ["refresh_tokens", "id, user_id, token, expires_at", "Permet la révocation/rotation des sessions"],
      ["password_reset_tokens", "user_id, token_hash, expires_at", "Jetons à usage unique, expiration 10 min"],
      ["user_settings", "user_id, notifications_battles/chat/news", "Préférences, une ligne par utilisateur"],
    ],
    [2300, 4338, 3000]
  ),

  C.h1("6. Choix techniques et justifications"),
  bi("Pourquoi JWT plutôt que des sessions serveur classiques ? ", "L'API doit rester sans état (stateless) pour pouvoir évoluer facilement (plusieurs instances) et fonctionner aussi bien avec le backend web qu'avec l'application mobile, sans dépendre d'un cookie de session."),
  bi("Pourquoi un access token court et un refresh token long ? ", "Limiter la fenêtre d'exploitation si un access token est intercepté, tout en évitant de redemander le mot de passe à chaque expiration."),
  bi("Pourquoi bcrypt et pas un simple hachage SHA-256 ? ", "bcrypt intègre un sel et un facteur de coût réglable, ce qui le rend volontairement lent et donc résistant aux attaques par force brute, contrairement à SHA-256 qui est rapide et donc dangereux pour des mots de passe."),
  bi("Pourquoi un rôle stocké en base plutôt qu'une liste d'emails admin en dur ? ", "Permet de promouvoir/rétrograder des comptes dynamiquement depuis le tableau de bord, sans redéploiement du code."),

  C.h1("7. Difficultés rencontrées et solutions"),
  C.bullet("Le menu Administration restait visible pour des utilisateurs non-admin dans une première version → corrigé en conditionnant son affichage à isAdminProvider, en plus de la protection serveur déjà en place."),
  C.bullet("Risque d'auto-suppression ou d'auto-rétrogradation accidentelle d'un compte admin → ajout de garde-fous explicites dans le contrôleur (refus si id === req.user.id)."),
  C.bullet("flutter_secure_storage stocke les jetons dans IndexedDB en mode web (et non localStorage) : une mauvaise manipulation directe du storage ne suffit pas à authentifier l'app web — seul un vrai login via l'interface fonctionne, ce qui a complexifié certains tests automatisés."),
  C.bullet("Gestion du conflit d'unicité sur l'email lors d'une mise à jour de profil (code PostgreSQL 23505) → capturé explicitement pour renvoyer un message clair (409) plutôt qu'une erreur 500 générique."),

  C.h1("8. Questions probables du jury & pistes de réponse"),
  bi("« Que se passe-t-il si quelqu'un vole un access token ? » ", "Il reste valable au maximum jusqu'à son expiration (7 jours par défaut, configurable) ; pour une vraie production, on réduirait cette durée et on ajouterait une liste de révocation. Le refresh token, lui, est stocké en base et peut être supprimé pour invalider une session."),
  bi("« Pourquoi ne pas avoir utilisé OAuth (Google/Facebook) ? » ", "Choix pédagogique : implémenter l'authentification maison permet de démontrer la compréhension du flux JWT complet (hachage, jetons, middleware), qui est l'objectif d'apprentissage du module."),
  bi("« Comment empêchez-vous un utilisateur normal d'appeler directement les routes admin avec Postman ? » ", "Le middleware requireAdmin vérifie le rôle décodé depuis la base à chaque requête, indépendamment de ce que montre l'interface ; un appel direct sans le bon rôle renvoie 403."),
  bi("« Le mot de passe est-il visible quelque part en clair ? » ", "Jamais : ni en base (uniquement le hash bcrypt), ni dans les logs (aucun log ne capture le corps des requêtes d'authentification)."),
];

const doc = new Document({
  styles: C.styles(),
  numbering: C.numbering(),
  sections: [{
    properties: { page: C.PAGE },
    headers: { default: C.header("WC Fantasy — Authentification & Utilisateurs") },
    footers: { default: C.footer() },
    children,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync("D:/pfa/rapport/presentation_parts/Partie2_Authentification_Utilisateurs.docx", buf);
  console.log("OK Partie2");
});
