const fs = require("fs");
const { Document, Packer, Paragraph, PageBreak, TextRun } = require("docx");
const C = require("./common");
const bi = (label, rest) => C.bulletRich([new TextRun({ text: label, bold: true }), new TextRun({ text: rest })]);
const br = () => new Paragraph({ children: [new PageBreak()] });

const children = [
  ...C.titlePage(
    "Partie 5 — Social & Application Mobile (Flutter)",
    "Amis, chat, actualités, design system et navigation",
    "Membre 5 (Responsable Social & Mobile UI)"
  ),
  br(),

  C.h1("1. Mon rôle dans le projet"),
  C.p("Je suis responsable des fonctionnalités sociales de WC Fantasy (amis, chat de ligue, actualités) et de l'expérience mobile dans son ensemble côté Flutter : organisation de l'application, design system, navigation, et widgets transverses utilisés par tous les écrans."),

  C.h1("2. Système d'amis"),
  C.p("Fichiers : controllers/friends.controller.js (126 lignes), routes/friends.routes.js, migration 015_friends.sql"),
  C.tableN(
    ["Endpoint", "Fonction"],
    [
      ["GET /api/friends", "Liste des amis acceptés (requête bidirectionnelle, classée par points décroissants)"],
      ["GET /api/friends/requests", "Demandes d'amitié entrantes en attente"],
      ["POST /api/friends/request", "Envoi d'une demande par nom d'utilisateur"],
      ["POST /api/friends/:userId/accept", "Acceptation d'une demande entrante"],
      ["DELETE /api/friends/:userId", "Suppression d'un ami ou refus d'une demande"],
      ["GET /api/friends/search", "Recherche de profils par nom d'utilisateur (2 caractères min, top 20)"],
    ],
    [3700, 5938]
  ),
  C.p("La table friendships utilise une clé composite (user_id, friend_id) avec un statut (pending/accepted) ; la relation est gérée comme un graphe non orienté une fois acceptée, mais orientée tant qu'elle est en attente (pour savoir qui doit valider)."),
  C.p("Côté mobile, les profils d'amis sont consultables en lecture seule via l'écran manager_screen.dart (route /manager/:userId), qui affiche l'équipe de l'ami sans permettre de la modifier."),

  br(),
  C.h1("3. Chat de ligue (temps réel)"),
  C.p("Fichiers : controllers/chat.controller.js, routes/chat.routes.js, intégration avec socket/socket.js"),
  C.p("Chaque ligue dispose d'un salon de discussion. Le flux est hybride REST + WebSocket :"),
  C.num("L'historique (50 derniers messages) est chargé via GET /api/chat/:leagueId au moment où l'écran s'ouvre."),
  C.num("L'envoi d'un message passe par POST /api/chat/:leagueId (validation de longueur 1 à 1000 caractères), qui insère en base puis diffuse l'événement chat:message à toute la room de la ligue."),
  C.num("Les autres clients connectés à la même ligue reçoivent le message instantanément, sans recharger la page."),
  C.num("Un indicateur « X en ligne » et « ... est en train d'écrire » est calculé côté serveur (league:presence, chat:typing) à partir des sockets effectivement connectés à la room, pas d'un simple « dernier vu »."),

  br(),
  C.h1("4. Actualités (agrégation RSS)"),
  C.p("Fichiers : controllers/news.controller.js (245 lignes), routes/news.routes.js"),
  C.p("Le fil d'actualité agrège 6 flux RSS (BBC Sport, Sky Sports, ESPN FC, Goal.com, L'Équipe, RMC Sport) puis filtre les articles pertinents pour la Coupe du Monde 2026 à l'aide d'une liste de mots-clés (noms d'équipes, de joueurs vedettes, termes comme « world cup », « mondial », « qualification »)."),
  C.bullet("Les appels aux flux sont effectués en parallèle avec Promise.allSettled, afin qu'un flux en panne ne bloque pas l'affichage des autres."),
  C.bullet("Déduplication des articles par URL, mise en cache 30 minutes pour limiter la charge."),
  C.bullet("Si aucun article lié à la Coupe du Monde n'est trouvé, repli automatique sur les dernières actualités sportives générales."),
  C.bullet("Catégorisation automatique (Match, Transfert, Blessure, Équipe, Qualif, Actu) et support multilingue (FR/EN) via le paramètre lang."),

  br(),
  C.h1("5. Architecture de l'application Flutter"),
  C.p("75 fichiers Dart, environ 20 500 lignes, organisés par responsabilité :"),
  C.tableN(
    ["Dossier", "Contenu"],
    [
      ["screens/", "35+ écrans (auth, gameplay, profil, admin, social...)"],
      ["providers/", "6 providers Riverpod (état réactif : auth, ligues, draft, battles, joueurs, transferts)"],
      ["services/", "11 services (API HTTP, WebSocket, notifications, connectivité, cache, analytics, localisation)"],
      ["widgets/", "19 composants réutilisables (cartes joueur, terrain, graphiques, indicateurs de chargement)"],
      ["models/", "7 classes de modèle (User, League, Team, Player, Battle, Transfer, NewsArticle)"],
      ["theme/", "Design system centralisé (couleurs, thème sombre)"],
      ["l10n/", "Localisation française/anglaise écrite à la main"],
    ],
    [2300, 7338]
  ),

  C.h2("5.1 Gestion d'état avec Riverpod"),
  C.p("Le choix de Riverpod (plutôt que Provider ou setState) permet une gestion d'état testable et découplée de l'arbre de widgets. Exemple représentatif : authProvider expose un AuthState (utilisateur courant, chargement, erreur, authentifié ou non) piloté par un AuthNotifier qui encapsule les appels login/register/logout/loadProfile vers l'API."),

  C.h2("5.2 Navigation avec go_router"),
  C.p("La navigation est centralisée dans main.dart avec des routes typées et imbriquées (ex. /home/leagues/:leagueId, /home/draft/:leagueId). Une fonctionnalité de garde (redirect) protège la route /admin : si l'utilisateur courant n'a pas le rôle admin, il est automatiquement redirigé vers /home — complément côté UI à la protection serveur déjà décrite dans le module Authentification."),

  C.h2("5.3 Design system & identité visuelle"),
  C.p("L'application est volontairement en thème sombre uniquement (pas de bascule clair/sombre), avec une palette aux couleurs du tournoi :"),
  C.tableN(
    ["Couleur", "Code", "Usage"],
    [
      ["Or (gold)", "#C8961C", "Couleur principale, boutons d'action, accents"],
      ["Rouge", "#C41E3A", "Alertes, éléments secondaires"],
      ["Navy", "#1F3864 / fond #0E1A2C", "Arrière-plan, surfaces"],
    ],
    [2300, 2200, 5138]
  ),
  C.p("Toutes les couleurs sont centralisées dans theme/app_colors.dart (jamais de Color(0x...) codé en dur dans les écrans), avec des polices Oswald (titres) et Inter (texte courant) via Google Fonts. Le logo (trophée transparent) est utilisé pour l'icône de l'application et l'écran de démarrage natif, générés automatiquement via flutter_launcher_icons et flutter_native_splash."),

  C.h2("5.4 Localisation (français / anglais)"),
  C.p("Le système de traduction est écrit à la main (app_localizations.dart) plutôt que généré automatiquement, avec le français comme langue par défaut. Chaque texte de l'interface est accessible via AppLocalizations.of(context).maClé, ce qui rend le changement de langue (disponible dans les réglages) immédiat sur tout l'écran sans rechargement."),

  C.h2("5.5 Composants transverses notables"),
  C.bullet("brand_app_bar.dart — barre d'application personnalisée avec dégradé rouge → navy, utilisée sur tous les écrans."),
  C.bullet("PlayerPhoto / PlayerPhotoLarge — affichage des photos de joueurs récupérées en ligne, avec repli sur les initiales si aucune photo n'est disponible."),
  C.bullet("deadline_countdown.dart — compteur en direct avant la date limite de composition d'équipe, affiché sur l'accueil et l'écran de draft."),
  C.bullet("offline_banner.dart — bannière de connectivité (connectivity_plus), pour prévenir l'utilisateur en cas de coupure réseau."),
  C.bullet("skeleton_loader.dart / loading_shimmer.dart — animations de chargement, pour une perception de fluidité même sur connexion lente."),

  C.h2("5.6 Une particularité technique notable : le proxy d'images"),
  C.p("Les photos de joueurs proviennent d'un CDN externe (TheSportsDB) qui ne renvoie aucun en-tête CORS. Or la cible de développement principale est Flutter Web, beaucoup plus stricte que le mobile natif sur ce point. La solution : un proxy backend (GET /api/photos/proxy?url=...) qui re-diffuse l'image avec nos propres en-têtes CORS, avec une liste blanche de domaines autorisés pour éviter de transformer ce proxy en relais ouvert exploitable pour masquer des requêtes vers n'importe quel site."),

  br(),
  C.h1("6. Schéma de base de données concerné"),
  C.tableN(
    ["Table", "Colonnes clés"],
    [
      ["friendships", "user_id, friend_id, status (pending/accepted)"],
      ["chat_messages", "id, league_id, user_id, message, created_at"],
      ["user_settings", "user_id, notifications_battles/chat/news"],
    ],
    [2300, 7338]
  ),

  C.h1("7. Choix techniques et justifications"),
  bi("Pourquoi écrire la localisation à la main plutôt qu'utiliser le générateur Flutter intl standard ? ", "Plus de contrôle direct sur la structure et plus simple à déboguer dans le temps imparti du projet, au prix d'un peu plus de code répétitif."),
  bi("Pourquoi un thème exclusivement sombre ? ", "Choix de direction artistique cohérent avec l'identité « stade de nuit / compétition », et réduction du périmètre de tests visuels (un seul thème à maintenir plutôt que deux)."),
  bi("Pourquoi un proxy backend pour les images plutôt que les afficher directement depuis le CDN ? ", "Flutter Web applique les règles CORS du navigateur ; sans proxy, les images ne s'afficheraient simplement pas en mode web, qui est la cible de développement principale faute de SDK Android disponible sur la machine de développement."),
  bi("Pourquoi Riverpod plutôt que Provider ou Bloc ? ", "API plus moderne, meilleure testabilité (providers indépendants du BuildContext), et compatibilité immédiate avec go_router pour les redirections conditionnelles (ex. garde admin)."),

  C.h1("8. Difficultés rencontrées et solutions"),
  C.bullet("Images de joueurs invisibles en mode web à cause du CORS → mise en place du proxy backend avec liste blanche de domaines."),
  C.bullet("Absence de SDK Android sur la machine de développement → la stratégie de vérification s'est appuyée sur flutter analyze, flutter test et le mode web plutôt que sur un build APK/AAB réel."),
  C.bullet("Présence « en ligne » dans le chat pouvait afficher des utilisateurs déjà déconnectés → calcul recalculé à partir des sockets réellement connectés à la room (io.in(room).fetchSockets()) plutôt que d'un simple drapeau en base."),
  C.bullet("Flux RSS parfois indisponibles individuellement → agrégation tolérante aux pannes (Promise.allSettled) pour ne jamais faire échouer tout le fil d'actualité à cause d'une seule source."),

  C.h1("9. Questions probables du jury & pistes de réponse"),
  bi("« Pourquoi pas de notifications push (Firebase) opérationnelles ? » ", "L'infrastructure (push_notification_service.dart) est prête mais non finalisée par manque de temps ; les notifications locales (flutter_local_notifications) couvrent les besoins de démonstration sans dépendance externe."),
  bi("« Comment gérez-vous le spam dans le chat de ligue ? » ", "Validation de longueur côté serveur (1-1000 caractères) ; la modération de contenu (filtrage de mots, blocage d'utilisateurs) n'est pas implémentée et serait une amélioration future logique."),
  bi("« Le design est-il responsive sur toutes les tailles d'écran ? » ", "L'application a été développée et testée principalement en mode Flutter Web (faute de SDK Android) ; le layout est globalement adaptatif mais n'a pas été audité sur toutes les tailles de tablette."),
  bi("« Pourquoi le français est-il la langue par défaut et non l'anglais ? » ", "Choix produit cohérent avec le contexte du projet (soutenance académique francophone), l'anglais reste disponible et bascule immédiatement toute l'interface."),
];

const doc = new Document({
  styles: C.styles(),
  numbering: C.numbering(),
  sections: [{
    properties: { page: C.PAGE },
    headers: { default: C.header("WC Fantasy — Social & Mobile (Flutter)") },
    footers: { default: C.footer() },
    children,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync("D:/pfa/rapport/presentation_parts/Partie5_Social_Mobile_Flutter.docx", buf);
  console.log("OK Partie5");
});
