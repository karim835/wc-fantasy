const fs = require("fs");
const { Document, Packer, Paragraph, PageBreak, TextRun } = require("docx");
const C = require("./common");
const bi = (label, rest) => C.bulletRich([new TextRun({ text: label, bold: true }), new TextRun({ text: rest })]);
const br = () => new Paragraph({ children: [new PageBreak()] });

const children = [
  ...C.titlePage(
    "Partie 3 — Ligues, Draft & Équipes",
    "Création de ligues, composition d'équipe, budget, transferts et chips",
    "Membre 3 (Responsable Ligues & Draft)"
  ),
  br(),

  C.h1("1. Mon rôle dans le projet"),
  C.p("Je suis responsable du cœur « gameplay » de WC Fantasy : la création et gestion des ligues, la composition de l'équipe fantasy (draft), le système de budget et de transferts, et les trois chips spéciales qui ajoutent une dimension stratégique au jeu."),

  C.h1("2. Gestion des ligues"),
  C.p("Fichiers : controllers/league.controller.js, routes/league.routes.js"),
  C.h2("2.1 Concept"),
  C.p("Une ligue est un groupe de joueurs qui s'affrontent sur tout le tournoi. Une ligue peut être privée (rejointe uniquement par code d'invitation) ou publique (visible et rejoignable par tous). Chaque ligue a un propriétaire (owner), un nombre maximal de membres, et une saison."),

  C.h2("2.2 Endpoints principaux"),
  C.tableN(
    ["Endpoint", "Fonction"],
    [
      ["GET /api/leagues", "Liste des ligues de l'utilisateur (mis en cache 5 min)"],
      ["POST /api/leagues", "Création d'une ligue : génère un code d'invitation unique (ex. 3F4A9B2C), ajoute automatiquement le créateur comme membre"],
      ["GET /api/leagues/:id", "Détails + classement des membres (tri par points décroissants)"],
      ["PATCH /api/leagues/:id", "Modification (propriétaire uniquement) : nom, taille max, visibilité, statut"],
      ["DELETE /api/leagues/:id", "Suppression (propriétaire uniquement), cascade sur membres/équipes/battles/chat"],
      ["POST /api/leagues/:id/join", "Rejoindre via code d'invitation ou ligue publique, vérifie le nombre de places restantes"],
      ["DELETE /api/leagues/:id/leave", "Quitter une ligue (le propriétaire ne peut pas quitter sans transférer la propriété)"],
      ["GET /api/leagues/public", "Découverte des ligues publiques disponibles"],
    ],
    [3500, 6138]
  ),
  C.p("Le partage d'une ligue côté mobile génère un QR code (qr_flutter) et utilise le partage natif du téléphone (share_plus) ; un lien profond /join/:code pré-remplit directement la boîte de dialogue pour rejoindre la ligue."),

  br(),
  C.h1("3. Draft : composition de l'équipe fantasy"),
  C.p("Fichiers : controllers/draft.controller.js (280 lignes), widgets/pitch_view.dart (vue terrain côté mobile)"),

  C.h2("3.1 Règles de formation"),
  C.p("Chaque équipe compte 15 joueurs maximum, répartis selon des quotas stricts par poste :"),
  C.tableN(
    ["Poste", "Effectif requis"],
    [
      ["Gardien (GK)", "2"],
      ["Défenseur (DEF)", "5"],
      ["Milieu (MID)", "5"],
      ["Attaquant (FWD)", "3"],
    ],
    [4500, 5138]
  ),
  C.p("Le budget de départ est de 100 millions d'euros (unité fictive). Chaque joueur réel a un prix ; sélectionner un joueur déduit son prix du budget, le retirer le rembourse."),

  C.h2("3.2 Endpoints de draft"),
  C.tableN(
    ["Endpoint", "Fonction"],
    [
      ["GET …/team", "Récupère l'équipe actuelle (budget, formation, joueurs, capitaine, chips)"],
      ["POST …/team", "Création de l'équipe (nom, formation, budget initial 100 M€)"],
      ["PATCH …/team", "Renommer / changer de formation"],
      ["POST …/team/players", "Sélectionner un joueur — vérifie le quota de poste, le budget suffisant, et l'absence de doublon"],
      ["DELETE …/team/players/:id", "Retirer un joueur (remboursement du prix)"],
      ["DELETE …/team/players", "Réinitialiser entièrement l'équipe (budget remis à 100 M€)"],
      ["PATCH …/team/captain", "Désigner le capitaine (score doublé, ou triplé avec la chip Triple Captain)"],
      ["POST …/team/auto-pick", "Suggestion automatique d'équipe via un service IA externe"],
    ],
    [3200, 6438]
  ),
  C.p("Lorsqu'un joueur est sélectionné, le backend stocke un instantané enrichi dans la colonne JSONB teams.players (id, nom, poste, prix, photo, club), ce qui évite de refaire une requête de jointure à chaque affichage de l'équipe côté mobile — un compromis performance/normalisation assumé."),

  C.h2("3.3 Vue terrain (Pitch View) côté mobile"),
  C.p("Le widget PitchView dessine un terrain (CustomPainter) avec les emplacements 2/5/5/3. Toucher un emplacement vide ouvre un sélecteur de joueurs filtré par poste et par budget restant ; toucher un joueur déjà placé ouvre les actions capitaine / retirer / voir le profil."),

  br(),
  C.h1("4. Système de transferts"),
  C.p("Fichiers : controllers/transfer.controller.js, écran transfers_screen.dart"),
  C.p("Une fois l'équipe constituée, l'utilisateur peut échanger un joueur contre un autre :"),
  C.num("Sélection du joueur à vendre (playerOutId) et du joueur à acheter (playerInId)."),
  C.num("Calcul du nouveau budget : budget + prixVendu − prixAcheté."),
  C.num("Le transfert est refusé si le nouveau budget serait négatif, avec un message précis indiquant le montant manquant (ex. « besoin de 2,3 M€ supplémentaires »)."),
  C.num("Mise à jour de l'instantané JSONB de l'équipe avec le nouveau joueur."),
  C.p("Deux endpoints complémentaires délèguent à un service IA externe pour assister la décision : suggestions de transfert (selon budget/formation) et score de risque d'un joueur (blessure, forme) — détaillés par le binôme responsable IA."),

  br(),
  C.h1("5. Les chips spéciales (bonus stratégiques)"),
  C.p("Trois bonus uniques, utilisables une seule fois sur tout le tournoi (migration 014_team_chips.sql) :"),
  C.tableN(
    ["Chip", "Effet"],
    [
      ["Triple Captain", "Le capitaine rapporte ×3 au lieu de ×2 sur la journée armée"],
      ["Super Sub", "Un second joueur désigné (boostPlayerId) rapporte aussi ×2"],
      ["Shield", "Les scores négatifs des joueurs de l'équipe sont ramenés à 0 pour la journée"],
    ],
    [2500, 7138]
  ),
  C.p("Armer une chip (PATCH …/team/chip) vérifie qu'elle n'a pas déjà été utilisée (colonne JSONB chips_used) et l'associe à la prochaine journée active ou à venir. Le calcul d'impact réel des chips sur les points est effectué par la fonction partagée sumTeamGwPoints() (module IA/Scoring), pour garantir qu'un seul et même calcul est utilisé partout."),

  br(),
  C.h1("6. Schéma de base de données concerné"),
  C.tableN(
    ["Table", "Colonnes clés"],
    [
      ["leagues", "id, name, owner_id, max_members, is_private, invite_code, season, status"],
      ["league_members", "league_id, user_id, points (clé composite)"],
      ["teams", "id, user_id, league_id, budget, formation, captain_id, players (JSONB), active_chip, active_chip_gw, boost_player_id, chips_used (JSONB)"],
      ["players", "id, name, position, club, nationality, price, points, form, injury_status"],
    ],
    [2300, 7338]
  ),

  C.h1("7. Choix techniques et justifications"),
  bi("Pourquoi stocker les joueurs d'une équipe en JSONB plutôt qu'une table de jointure team_players ? ", "Simplicité de lecture (un seul SELECT renvoie toute l'équipe avec ses informations enrichies) au prix d'une dénormalisation contrôlée ; acceptable car les écritures sur l'équipe sont peu fréquentes comparées aux lectures."),
  bi("Pourquoi un budget fixe de 100 M€ pour tous, plutôt que dynamique ? ", "Garantit l'équité du jeu : tous les managers démarrent avec les mêmes contraintes, seule la stratégie de sélection les différencie."),
  bi("Pourquoi limiter chaque chip à un usage unique pour tout le tournoi ? ", "C'est la règle classique des jeux fantasy football professionnels (type Premier League Fantasy) : cela force des décisions stratégiques à fort enjeu plutôt qu'un usage systématique chaque journée."),

  C.h1("8. Difficultés rencontrées et solutions"),
  C.bullet("PostgreSQL renvoie les colonnes DECIMAL (comme budget) sous forme de chaîne de caractères côté JSON, ce qui cassait les calculs côté mobile → parsing défensif (double.tryParse) systématisé dans pitch_view.dart et transfers_screen.dart."),
  C.bullet("Risque de double sélection d'un même joueur dans deux requêtes concurrentes → validation systématique de l'absence de doublon avant insertion dans le JSONB, côté serveur."),
  C.bullet("Le quota par poste (2/5/5/3) devait être vérifié à chaque ajout sans recharger toute l'équipe → comptage direct dans le tableau JSONB players avant d'autoriser l'insertion."),

  C.h1("9. Questions probables du jury & pistes de réponse"),
  bi("« Que se passe-t-il si deux utilisateurs rejoignent une ligue presque pleine en même temps ? » ", "Le nombre de membres est revérifié côté serveur au moment de l'insertion ; un dépassement léger reste théoriquement possible sans verrou transactionnel strict — c'est une limite connue, améliorable avec un SELECT FOR UPDATE."),
  bi("« Pourquoi un format JSONB et pas une vraie relation many-to-many pour les équipes ? » ", "Compromis pragmatique pour ce projet : simplicité de lecture/écriture rapide contre une normalisation stricte, qui serait préférable pour un produit à grande échelle avec beaucoup d'écritures concurrentes."),
  bi("« Comment empêchez-vous un utilisateur de dépasser son budget ? » ", "Vérification systématique côté serveur (jamais uniquement côté mobile) avant toute insertion ou tout transfert ; le budget restant est recalculé à chaque opération, jamais simplement décrémenté côté client."),
  bi("« Peut-on changer de capitaine après le début d'une journée ? » ", "Oui techniquement, mais cela n'affecte que le calcul futur ; les points déjà calculés pour une journée terminée ne sont jamais recalculés rétroactivement."),
];

const doc = new Document({
  styles: C.styles(),
  numbering: C.numbering(),
  sections: [{
    properties: { page: C.PAGE },
    headers: { default: C.header("WC Fantasy — Ligues, Draft & Équipes") },
    footers: { default: C.footer() },
    children,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync("D:/pfa/rapport/presentation_parts/Partie3_Ligues_Draft_Equipes.docx", buf);
  console.log("OK Partie3");
});
