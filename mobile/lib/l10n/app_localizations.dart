import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const supportedLocales = [Locale('fr'), Locale('en')];

  bool get _fr => locale.languageCode == 'fr';

  // ─── Navigation ────────────────────────────────────────────────────
  String get home => _fr ? 'Accueil' : 'Home';
  String get draft => 'Draft';
  String get leagues => _fr ? 'Ligues' : 'Leagues';
  String get news => _fr ? 'Actualités' : 'News';
  String get gameweeks => _fr ? 'Journées' : 'Gameweeks';
  String get aiChat => 'AI Chat';
  String get fantasy => 'Fantasy';
  String get more => _fr ? 'Plus' : 'More';
  String get nations => _fr ? 'Nations' : 'Nations';
  String get transfers => _fr ? 'Transferts' : 'Transfers';

  // ─── Common ────────────────────────────────────────────────────────
  String get appName => 'WC Fantasy';
  String get loading => _fr ? 'Chargement...' : 'Loading...';
  String get retry => _fr ? 'Réessayer' : 'Retry';
  String get save => _fr ? 'Enregistrer' : 'Save';
  String get cancel => _fr ? 'Annuler' : 'Cancel';
  String get confirm => _fr ? 'Confirmer' : 'Confirm';
  String get error => _fr ? 'Erreur' : 'Error';
  String get success => _fr ? 'Succès' : 'Success';
  String get noData => _fr ? 'Aucune donnée' : 'No data';
  String get seeAll => _fr ? 'Voir tout' : 'See all';
  String get search => _fr ? 'Rechercher...' : 'Search...';

  // ─── Auth ──────────────────────────────────────────────────────────
  String get login => _fr ? 'Se connecter' : 'Login';
  String get loginBtn => _fr ? 'Se connecter' : 'Sign in';
  String get logout => _fr ? 'Déconnexion' : 'Logout';
  String get register => _fr ? 'Créer un compte' : 'Create account';
  String get createAccount => _fr ? 'Créer un compte' : 'Create account';
  String get profileInfo => _fr ? 'Parle-nous de toi' : 'Tell us about you';
  String get username => _fr ? 'Nom d\'utilisateur' : 'Username';
  String get password => _fr ? 'Mot de passe' : 'Password';
  String get welcome => _fr ? 'Bienvenue' : 'Welcome';
  String get next => _fr ? 'Suivant' : 'Next';

  // ─── Landing ───────────────────────────────────────────────────────
  String get slogan => _fr ? 'Ton équipe. Ta gloire.' : 'Your team. Your glory.';
  String get sloganSub => _fr ? 'Coupe du Monde 2026' : 'World Cup 2026';
  String get getStarted => _fr ? 'Commencer' : 'Get started';

  // ─── Team builder (pitch) ──────────────────────────────────────────
  String get playersSelectedLabel => _fr ? 'sélectionnés' : 'selected';
  String get bank => _fr ? 'Banque' : 'Bank';
  String get pickStartingLineup => _fr ? 'Compose ton onze' : 'Pick your lineup';
  String get selectAPlayer => _fr ? 'Choisir un joueur' : 'Select a player';
  String get removeFromTeam => _fr ? 'Retirer de l\'équipe' : 'Remove from team';
  String get viewProfile => _fr ? 'Voir le profil' : 'View profile';
  String get makeCaptain => _fr ? 'Nommer capitaine' : 'Make captain';
  String get teamComplete => _fr ? 'Équipe complète !' : 'Team complete!';
  String get noAffordablePlayers => _fr ? 'Aucun joueur dans ton budget' : 'No players within budget';
  String get autoPickLabel => _fr ? 'Auto' : 'Auto Pick';

  // ─── Round 6: team management ──────────────────────────────────────
  String get manageTeam => _fr ? 'Gérer l\'équipe' : 'Manage team';
  String get resetSquad => _fr ? 'Réinitialiser l\'effectif' : 'Reset squad';
  String get resetSquadConfirm => _fr ? 'Retirer tous les joueurs et récupérer ton budget ?' : 'Remove all players and refund your budget?';
  String removeConfirm(String name) => _fr ? 'Retirer $name de ton équipe ?' : 'Remove $name from your team?';

  // ─── Round 6: profile & account ────────────────────────────────────
  String get email => _fr ? 'E-mail' : 'Email';
  String memberSince(String date) => _fr ? 'Membre depuis $date' : 'Member since $date';
  String get emailTaken => _fr ? 'Cet e-mail est déjà utilisé' : 'That email is already taken';
  String get photoUpdated => _fr ? 'Photo mise à jour !' : 'Photo updated!';
  String get deleteAccount => _fr ? 'Supprimer le compte' : 'Delete account';
  String get deleteAccountConfirm => _fr
      ? 'Cette action est définitive. Ton compte, tes équipes et tes ligues seront supprimés. Continuer ?'
      : 'This is permanent. Your account, teams and leagues will be deleted. Continue?';
  String get dangerZone => _fr ? 'Zone de danger' : 'Danger zone';

  // ─── Round 6: manager view + social/discovery ─────────────────────
  String get manager => _fr ? 'Manager' : 'Manager';
  String get rank => _fr ? 'Rang' : 'Rank';
  String get leaveLeague => _fr ? 'Quitter la ligue' : 'Leave league';
  String get leaveLeagueConfirm => _fr ? 'Quitter cette ligue ? Ton équipe dans cette ligue sera supprimée.' : 'Leave this league? Your team in it will be deleted.';
  String get deleteLeague => _fr ? 'Supprimer la ligue' : 'Delete league';
  String get deleteLeagueConfirm => _fr ? 'Supprimer définitivement cette ligue pour tous les membres ?' : 'Permanently delete this league for all members?';
  String get manageLeague => _fr ? 'Gérer la ligue' : 'Manage league';
  String get renameLeague => _fr ? 'Renommer' : 'Rename';
  String get kickMember => _fr ? 'Exclure' : 'Kick';
  String get discoverLeagues => _fr ? 'Découvrir' : 'Discover';
  String get publicLeagues => _fr ? 'Ligues publiques' : 'Public leagues';
  String get noPublicLeagues => _fr ? 'Aucune ligue publique ouverte' : 'No open public leagues';
  String get leftLeague => _fr ? 'Ligue quittée' : 'Left the league';

  // ─── Round 6: gameweek breakdown ───────────────────────────────────
  String get myTeamTab => _fr ? 'Mon équipe' : 'My Team';
  String get gameweekTotal => _fr ? 'Total de la journée' : 'Gameweek total';

  // ─── Round 6: player sort + compare ────────────────────────────────
  String get sortBy => _fr ? 'Trier par' : 'Sort by';
  String get sortPoints => _fr ? 'Points' : 'Points';
  String get sortPrice => _fr ? 'Prix' : 'Price';
  String get sortForm => _fr ? 'Forme' : 'Form';
  String get sortName => _fr ? 'Nom' : 'Name';
  String get comparePlayers => _fr ? 'Comparer' : 'Compare';
  String get selectTwoPlayers => _fr ? 'Choisis deux joueurs à comparer' : 'Pick two players to compare';
  String get addPlayer => _fr ? 'Ajouter un joueur' : 'Add a player';
  String get position => _fr ? 'Poste' : 'Position';
  String get age => _fr ? 'Âge' : 'Age';
  String get searchPlaceholder => _fr ? 'Rechercher un joueur…' : 'Search a player…';
  String get back => _fr ? 'Retour' : 'Back';
  String get alreadyAccount => _fr ? 'Déjà un compte ? Se connecter' : 'Already have an account? Sign in';
  String get noAccount => _fr ? 'Pas de compte ? S\'inscrire' : 'No account? Sign up';
  String get forgotPassword => _fr ? 'Mot de passe oublié ?' : 'Forgot password?';
  String get fieldRequired => _fr ? 'Champ requis' : 'Required field';
  String get min3chars => _fr ? 'Minimum 3 caractères' : 'Minimum 3 characters';
  String get min8chars => _fr ? 'Minimum 8 caractères' : 'Minimum 8 characters';
  String get invalidEmail => _fr ? 'Email invalide' : 'Invalid email';
  // Profile extra fields
  String get dateOfBirth => _fr ? 'Date de naissance' : 'Date of birth';
  String get dobPicker => _fr ? 'Sélectionner la date de naissance' : 'Select date of birth';
  String get country => _fr ? 'Pays' : 'Country';
  String get favoriteNation => _fr ? 'Nation favorite (CdM)' : 'Favorite nation (WC)';
  String get favoriteClub => _fr ? 'Club favori' : 'Favorite club';
  String get favoritePlayer => _fr ? 'Joueur favori' : 'Favorite player';
  String get bio => _fr ? 'Bio (optionnel)' : 'Bio (optional)';
  String get aboutMe => _fr ? 'À propos' : 'About me';

  // ─── Home ──────────────────────────────────────────────────────────
  String get topPlayers => _fr ? 'Top joueurs' : 'Top players';
  String get latestNews => _fr ? 'Actu WC 2026' : 'WC 2026 News';
  String get quickActions => _fr ? 'Actions rapides' : 'Quick actions';
  String get challenges => _fr ? 'Défis' : 'Challenges';
  String get profile => _fr ? 'Profil' : 'Profile';

  // ─── Players ───────────────────────────────────────────────────────
  String get players => _fr ? 'Joueurs' : 'Players';
  String get allPositions => _fr ? 'Tous' : 'All';
  String get price => _fr ? 'Prix' : 'Price';
  String get form => _fr ? 'Forme' : 'Form';
  String get points => _fr ? 'pts' : 'pts';
  String get available => _fr ? 'Disponible' : 'Available';
  String get injured => _fr ? 'Blessé' : 'Injured';
  String get advancedFilters => _fr ? 'Filtres avancés' : 'Advanced filters';
  String get resetFilters => _fr ? 'Réinitialiser' : 'Reset';
  String get minForm => _fr ? 'Forme min.' : 'Min. form';
  String get priceRange => _fr ? 'Fourchette de prix' : 'Price range';
  String get availability => _fr ? 'Disponibilité' : 'Availability';

  // ─── Leagues ───────────────────────────────────────────────────────
  String get createLeague => _fr ? 'Créer une ligue' : 'Create league';
  String get joinLeague => _fr ? 'Rejoindre une ligue' : 'Join league';
  String get leagueName => _fr ? 'Nom de la ligue' : 'League name';
  String get leagueCode => _fr ? 'Code d\'invitation' : 'Invite code';
  String get maxMembers => _fr ? 'Membres max.' : 'Max members';
  String get create => _fr ? 'Créer' : 'Create';
  String get join => _fr ? 'Rejoindre' : 'Join';
  String get myLeagues => _fr ? 'Mes Ligues' : 'My Leagues';
  String get privateLeague => _fr ? 'Ligue privée' : 'Private league';
  String get privateLeagueHint => _fr ? 'Nécessite un code d\'invitation' : 'Requires an invite code';
  String get noLeaguesTitle => _fr ? 'Aucune ligue' : 'No leagues';
  String get noLeaguesSubtitle => _fr ? 'Crée ou rejoins une ligue pour commencer' : 'Create or join a league to get started';
  String get enterInviteCode => _fr ? 'Entrez le code d\'invitation' : 'Enter the invite code';
  String get invalidCode => _fr ? 'Code invalide' : 'Invalid code';
  String get nameRequired => _fr ? 'Le nom est requis' : 'Name is required';
  String get leagueJoined => _fr ? 'Ligue rejointe avec succès !' : 'League joined successfully!';
  String get errorCreating => _fr ? 'Erreur lors de la création' : 'Error creating';
  String get invalidCodeOrNotFound => _fr ? 'Code invalide ou ligue introuvable' : 'Invalid code or league not found';

  // ─── Battles ───────────────────────────────────────────────────────
  String get battles => _fr ? 'Battles' : 'Battles';
  String get vs => 'VS';
  String get winner => _fr ? 'Gagnant' : 'Winner';

  // ─── League detail ─────────────────────────────────────────────────
  String get leagueInfoTab => _fr ? 'Infos' : 'Info';
  String get leagueRankingTab => _fr ? 'Classement' : 'Ranking';
  String get members => _fr ? 'Membres' : 'Members';
  String get status => _fr ? 'Statut' : 'Status';
  String get type => _fr ? 'Type' : 'Type';
  String get myPoints => _fr ? 'Mes points' : 'My points';
  String get privateLabel => _fr ? '🔒 Privée' : '🔒 Private';
  String get publicLabel => _fr ? '🌍 Publique' : '🌍 Public';
  String get shareLeagueMsg => _fr ? 'Rejoins ma ligue WC Fantasy avec le code : ' : 'Join my WC Fantasy league with code: ';

  // ─── Settings ──────────────────────────────────────────────────────
  String get settings => _fr ? 'Paramètres' : 'Settings';
  String get notifications => _fr ? 'Notifications' : 'Notifications';
  String get theme => _fr ? 'Thème' : 'Theme';
  String get darkMode => _fr ? 'Mode sombre' : 'Dark mode';
  String get language => _fr ? 'Langue' : 'Language';
  String get security => _fr ? 'Sécurité' : 'Security';
  String get changePassword => _fr ? 'Changer le mot de passe' : 'Change password';
  String get appInfo => _fr ? 'Application' : 'App info';
  String get version => _fr ? 'Version' : 'Version';
  String get french => 'Français';
  String get english => 'English';
  String get appearance => _fr ? 'Apparence' : 'Appearance';
  String get administration => _fr ? 'Administration' : 'Administration';
  String get battlesScores => _fr ? 'Battles & Scores' : 'Battles & Scores';
  String get battlesScoresSubtitle => _fr ? 'Scores en direct, résultats de battles' : 'Live scores, battle results';
  String get leagueChat => _fr ? 'Chat de Ligue' : 'League Chat';
  String get leagueChatSubtitle => _fr ? 'Nouveaux messages dans tes ligues' : 'New messages in your leagues';
  String get wcNews => _fr ? 'Actualités WC' : 'WC News';
  String get wcNewsSubtitle => _fr ? 'Dernières news de la Coupe du Monde' : 'Latest World Cup news';
  String get currentPassword => _fr ? 'Mot de passe actuel' : 'Current password';
  String get newPassword => _fr ? 'Nouveau mot de passe' : 'New password';
  String get confirmNewPassword => _fr ? 'Confirmer le nouveau mot de passe' : 'Confirm new password';
  String get playerStatsEntry => _fr ? 'Saisie des stats joueurs' : 'Player stats entry';
  String get playerStatsSubtitle => _fr ? 'Entrer les stats par gameweek' : 'Enter stats by gameweek';
  // ── Admin dashboard ──────────────────────────────────────────────────────
  String get adminDashboard => _fr ? 'Tableau de bord admin' : 'Admin dashboard';
  String get adminDashboardSubtitle => _fr ? 'Utilisateurs, ligues, joueurs, système' : 'Users, leagues, players, system';
  String get overview => _fr ? 'Vue d\'ensemble' : 'Overview';
  String get usersTab => _fr ? 'Utilisateurs' : 'Users';
  String get leaguesTab => _fr ? 'Ligues' : 'Leagues';
  String get playersTab => _fr ? 'Joueurs' : 'Players';
  String get scoringTab => _fr ? 'Scores' : 'Scoring';
  String get totalUsers => _fr ? 'Utilisateurs' : 'Users';
  String get totalLeagues => _fr ? 'Ligues' : 'Leagues';
  String get totalTeams => _fr ? 'Équipes' : 'Teams';
  String get totalPlayers => _fr ? 'Joueurs' : 'Players';
  String get totalMatches => _fr ? 'Matchs' : 'Matches';
  String get totalBattles => _fr ? 'Battles' : 'Battles';
  String get signupsLast14d => _fr ? 'Inscriptions (14 j)' : 'Signups (14 d)';
  String get recentUsers => _fr ? 'Utilisateurs récents' : 'Recent users';
  String get systemInfo => _fr ? 'Système' : 'System';
  String get dbStats => _fr ? 'Base de données' : 'Database';
  String get uptime => _fr ? 'Disponibilité' : 'Uptime';
  String get memory => _fr ? 'Mémoire' : 'Memory';
  String get makeAdmin => _fr ? 'Promouvoir admin' : 'Make admin';
  String get makeUser => _fr ? 'Rétrograder' : 'Make user';
  String get deleteUser => _fr ? 'Supprimer l\'utilisateur' : 'Delete user';
  String deleteUserConfirm(String name) => _fr ? 'Supprimer définitivement « $name » ? Toutes ses données seront perdues.' : 'Permanently delete "$name"? All their data will be lost.';
  String get deleteLeagueAdmin => _fr ? 'Supprimer la ligue' : 'Delete league';
  String deleteLeagueConfirmAdmin(String name) => _fr ? 'Supprimer la ligue « $name » et toutes ses équipes ?' : 'Delete league "$name" and all its teams?';
  String get editPlayer => _fr ? 'Modifier le joueur' : 'Edit player';
  String get injuryStatus => _fr ? 'Statut blessure' : 'Injury status';
  String get roleAdmin => _fr ? 'ADMIN' : 'ADMIN';
  String get delete => _fr ? 'Supprimer' : 'Delete';
  String get searchUsersAdmin => _fr ? 'Rechercher un utilisateur…' : 'Search users…';
  String get searchLeagues => _fr ? 'Rechercher une ligue…' : 'Search leagues…';
  String get searchPlayersAdmin => _fr ? 'Rechercher un joueur…' : 'Search players…';
  String get manageScoring => _fr ? 'Gérer les scores & gameweeks' : 'Manage scoring & gameweeks';
  String get manageScoringSub => _fr ? 'Saisie des stats, démarrer/terminer une journée' : 'Enter stats, start/finish a gameweek';
  String get updated => _fr ? 'Mis à jour ✓' : 'Updated ✓';
  String get season => _fr ? 'Saison' : 'Season';
  String get serverStatus => _fr ? 'Serveur' : 'Server';
  String get connected => _fr ? 'Connecté' : 'Connected';
  String get welcomeGreeting => _fr ? 'Bienvenue,' : 'Welcome,';
  String get ptsTotal => _fr ? 'pts total' : 'pts total';
  String get fillAllFields => _fr ? 'Remplir tous les champs' : 'Fill in all fields';
  String get passwordsMismatch => _fr ? 'Les mots de passe ne correspondent pas' : 'Passwords don\'t match';
  String get passwordChanged => _fr ? 'Mot de passe modifié avec succès' : 'Password changed successfully';
  String get profileUpdated => _fr ? 'Profil mis à jour' : 'Profile updated';
  String get cannotLoadSettings => _fr ? 'Impossible de charger les paramètres' : 'Cannot load settings';
  String get cannotLoadProfile => _fr ? 'Impossible de charger le profil' : 'Cannot load profile';

  // ─── Profile ───────────────────────────────────────────────────────
  String get achievements => _fr ? 'Succès' : 'Achievements';
  String get totalPoints => _fr ? 'Points totaux' : 'Total points';
  String get predictions => _fr ? 'Prédictions' : 'Predictions';
  String get myPrediction => _fr ? 'Ma Prédiction' : 'My Prediction';
  String get community => _fr ? 'Communauté' : 'Community';

  // ─── Offline ───────────────────────────────────────────────────────
  String get offlineBanner => _fr ? 'Mode hors ligne — données en cache' : 'Offline — cached data';

  // ─── Gameweek ──────────────────────────────────────────────────────
  String get ranking => _fr ? 'Classement' : 'Ranking';
  String get predict => _fr ? 'Prédire' : 'Predict';
  String get finishGw => _fr ? 'Terminer la GW' : 'Finish GW';
  String get generateBattles => _fr ? 'Générer les Battles' : 'Generate Battles';

  // ─── Challenges ────────────────────────────────────────────────────
  String get challengesAndXp => _fr ? 'Défis & XP' : 'Challenges & XP';
  String get daily => _fr ? 'Quotidiens' : 'Daily';
  String get weekly => _fr ? 'Hebdo' : 'Weekly';

  // ─── News ──────────────────────────────────────────────────────────
  String get newsTitle => _fr ? 'Actu World Cup 2026' : 'World Cup 2026 News';
  String get newsSection => _fr ? 'Actu WC 2026' : 'WC 2026 News';
  String get searchNews => _fr ? 'Rechercher une news...' : 'Search news...';
  String get refresh => _fr ? 'Actualiser' : 'Refresh';

  // ─── Onboarding ────────────────────────────────────────────────────
  String get skip => _fr ? 'Ignorer' : 'Skip';
  String get start => _fr ? 'Commencer !' : 'Get started!';
  String get onbTitle1 => _fr ? 'Bienvenue sur\nWC Fantasy' : 'Welcome to\nWC Fantasy';
  String get onbSubtitle1 => _fr ? 'Le jeu fantasy officieux de la\nCoupe du Monde 2026.' : 'The unofficial fantasy game of the\n2026 World Cup.';
  String get onbDesc1 => _fr ? 'Composez votre équipe de rêve avec les meilleurs joueurs du monde et affrontez vos amis.' : 'Build your dream team with the best players in the world and take on your friends.';
  String get onbTitle2 => _fr ? 'Construisez\nVotre Équipe' : 'Build\nYour Team';
  String get onbSubtitle2 => _fr ? 'Budget de 100M€ pour recruter\nvos stars mondiales.' : '€100M budget to sign\nyour global stars.';
  String get onbDesc2 => _fr ? 'Choisissez la meilleure formation, nommez votre capitaine et maximisez vos points.' : 'Pick the best formation, name your captain and maximise your points.';
  String get onbTitle3 => _fr ? 'Affrontez\nVos Amis' : 'Take On\nYour Friends';
  String get onbSubtitle3 => _fr ? 'Ligues privées, Battles H2H,\ntournois entre amis.' : 'Private leagues, H2H battles,\ntournaments among friends.';
  String get onbDesc3 => _fr ? 'Créez votre ligue, invitez vos amis et voyez qui est le meilleur manager du groupe !' : 'Create your league, invite your friends and see who is the best manager in the group!';
  String get onbTitle4 => _fr ? 'Scores\nen Temps Réel' : 'Real-Time\nScores';
  String get onbSubtitle4 => _fr ? 'Vos points se mettent à jour\nautomatiquement toutes les 30 min.' : 'Your points update\nautomatically every 30 min.';
  String get onbDesc4 => _fr ? 'Suivez les performances de vos joueurs match par match pendant la Coupe du Monde.' : 'Follow your players\' performances match by match during the World Cup.';
  String get onbTitle5 => _fr ? 'Prêt à\nGagner ?' : 'Ready to\nWin?';
  String get onbSubtitle5 => _fr ? 'La Coupe du Monde 2026\nvous attend.' : 'The 2026 World Cup\nawaits you.';
  String get onbDesc5 => _fr ? 'Prouvez que vous êtes le meilleur manager football. Que le meilleur gagne !' : 'Prove you are the best football manager. May the best win!';

  // ─── Gameweek (admin + states) ───────────────────────────────────────
  String get finishGameweekTitle => _fr ? 'Terminer la Gameweek' : 'Finish the Gameweek';
  String get finishGameweekConfirm => _fr ? 'Cela va finaliser les scores et clôturer la journée.' : 'This will finalize the scores and close the gameweek.';
  String get gameweekFinished => _fr ? 'Gameweek terminée' : 'Gameweek finished';
  String get noLeagueAvailable => _fr ? 'Aucune ligue disponible' : 'No league available';
  String get mustOwnLeagueForBattles => _fr ? 'Vous devez être propriétaire d\'une ligue pour générer des battles' : 'You must own a league to generate battles';
  String get noTeamScores => _fr ? 'Aucun score pour le moment' : 'No scores yet';
  String get noPlayerScores => _fr ? 'Aucun score joueur' : 'No player scores';
  String get matchesLabel => _fr ? 'matchs' : 'matches';
  String get loadingError => _fr ? 'Erreur de chargement' : 'Loading error';

  // ─── Profile / More ──────────────────────────────────────────────────
  String get logoutConfirm => _fr ? 'Voulez-vous vraiment vous déconnecter ?' : 'Do you really want to log out?';
  String get newUsername => _fr ? 'Nouveau pseudo' : 'New username';
  String get seasonWrapped => _fr ? 'Rétro de la Saison' : 'Season Wrapped';
  String get viewRecap => _fr ? 'Vois ton résumé de la saison' : 'See your season recap';

  // ─── Fantasy hub ─────────────────────────────────────────────────────
  String get fantasySubtitle => _fr ? 'Draft · Ligues · Battles · Prédictions' : 'Draft · Leagues · Battles · Predictions';

  // ─── Empty states ────────────────────────────────────────────────────
  String get emptyNoTeamTitle => _fr ? 'Pas encore d\'équipe' : 'No team yet';
  String get emptyNoTeamSubtitle => _fr ? 'Rejoins une ligue et compose ta première équipe.' : 'Join a league and build your first team.';
  String get emptyNoTeamAction => _fr ? 'Aller au Draft' : 'Go to Draft';
  String get emptyNoLeagueSubtitle => _fr ? 'Crée ta ligue ou rejoins-en une avec un code d\'invitation.' : 'Create your league or join one with an invite code.';
  String get emptyNoPlayersTitle => _fr ? 'Aucun joueur trouvé' : 'No players found';
  String get emptyNoPlayersSubtitle => _fr ? 'Essaie de modifier tes filtres de recherche.' : 'Try adjusting your search filters.';
  String get emptyNoNewsTitle => _fr ? 'Pas d\'actualités' : 'No news';
  String get emptyNoNewsSubtitle => _fr ? 'Vérifie ta connexion ou réessaie dans quelques instants.' : 'Check your connection or try again shortly.';
  String get emptyNoBattlesTitle => _fr ? 'Aucun battle' : 'No battles';
  String get emptyNoBattlesSubtitle => _fr ? 'Les battles seront générés automatiquement au début du gameweek.' : 'Battles are generated automatically at the start of the gameweek.';
  String get emptyNoHistoryTitle => _fr ? 'Aucun historique' : 'No history';
  String get emptyNoHistorySubtitle => _fr ? 'Tes statistiques apparaîtront ici après le premier gameweek.' : 'Your stats will appear here after the first gameweek.';
  String get emptyOfflineTitle => _fr ? 'Hors ligne' : 'Offline';
  String get emptyOfflineSubtitle => _fr ? 'Vérifie ta connexion Internet et réessaie.' : 'Check your internet connection and try again.';
  String get emptyErrorTitle => _fr ? 'Oups !' : 'Oops!';
  String get emptyErrorSubtitle => _fr ? 'Une erreur est survenue.' : 'Something went wrong.';

  // ─── Draft / Team ────────────────────────────────────────────────────
  String get formation => _fr ? 'Formation' : 'Formation';
  String get budget => _fr ? 'Budget' : 'Budget';
  String get captain => _fr ? 'Capitaine' : 'Captain';
  String get teamName => _fr ? 'Nom de l\'équipe' : 'Team name';
  String get createMyTeam => _fr ? 'Créer mon équipe' : 'Create my team';
  String get draftNoTeamSubtitle => _fr ? 'Crée ton équipe pour commencer à ajouter des joueurs' : 'Create your team to start adding players';
  String get noDraftedPlayers => _fr ? 'Aucun joueur drafté' : 'No drafted players';
  String get setCaptainTooltip => _fr ? 'Définir comme capitaine (x2 pts)' : 'Set as captain (x2 pts)';
  String get captainDoublePoints => _fr ? 'Le capitaine marque le DOUBLE des points chaque gameweek.' : 'The captain scores DOUBLE points every gameweek.';
  String get tapStarForCaptain => _fr ? 'Appuie sur ⭐ pour choisir ton capitaine (x2 pts)' : 'Tap ⭐ to pick your captain (x2 pts)';
  String get joinLeagueInTab => _fr ? 'Rejoins d\'abord une ligue dans l\'onglet Ligues' : 'Join a league first in the Leagues tab';
  String nameCaptainConfirm(String name) => _fr ? 'Nommer $name capitaine ?' : 'Make $name captain?';
  String captainSetMsg(String name) => _fr ? '$name est maintenant ton capitaine ⭐ (x2 pts)' : '$name is now your captain ⭐ (x2 pts)';
  String get teamCreated => _fr ? '✅ Équipe créée ! Tu peux maintenant ajouter des joueurs.' : '✅ Team created! You can now add players.';
  String get teamCreateError => _fr ? '❌ Erreur lors de la création de l\'équipe' : '❌ Error creating the team';
  String get createTeamFirst => _fr ? '⚠️ Crée d\'abord une équipe dans l\'onglet "Mon Équipe"' : '⚠️ Create a team first in the "My Team" tab';
  String get playerAlreadyInTeam => _fr ? '⚠️ Ce joueur est déjà dans ton équipe' : '⚠️ This player is already in your team';
  String get cannotAddPlayer => _fr ? '❌ Impossible d\'ajouter le joueur. Réessaie.' : '❌ Couldn\'t add the player. Try again.';
  String get insufficientBudget => _fr ? '💸 Budget insuffisant pour ce joueur' : '💸 Not enough budget for this player';
  String get joinLeagueFirst => _fr ? 'Rejoins une ligue d\'abord !' : 'Join a league first!';
  String get autoPickSuggestion => _fr ? '🤖 Suggestion Auto-Pick' : '🤖 Auto-Pick suggestion';
  String get expectedPoints => _fr ? 'Points attendus' : 'Expected points';
  String playerAddedToTeam(String name) => _fr ? '✅ $name ajouté à ton équipe !' : '✅ $name added to your team!';

  // ─── Transfers ───────────────────────────────────────────────────────
  String get cannotLoadTeam => _fr ? 'Impossible de charger l\'équipe' : 'Couldn\'t load the team';
  String get confirmTransfer => _fr ? 'Confirmer le transfert' : 'Confirm transfer';
  String get noPlayersInTeam => _fr ? 'Aucun joueur dans ton équipe' : 'No players in your team';
  String get noTeamInLeague => _fr ? 'Pas d\'équipe dans cette ligue' : 'No team in this league';
  String get noSuggestions => _fr ? 'Aucune suggestion disponible pour le moment.' : 'No suggestions available right now.';
  String get budgetRemaining => _fr ? 'Budget restant' : 'Remaining budget';
  String get inTeam => _fr ? 'Dans équipe' : 'In team';
  String get choose => _fr ? 'Choisir' : 'Choose';
  String get transferOut => _fr ? 'Sortant' : 'Out';
  String get transferIn => _fr ? 'Entrant' : 'In';
  String transferDoneMsg(String out, String inn) => _fr ? '$out → $inn effectué !' : '$out → $inn done!';

  // ─── Round 5: deadline countdown ───────────────────────────────────
  String get deadlineLabel => _fr ? 'Clôture dans' : 'Deadline in';
  String get deadlinePassed => _fr ? 'Journée verrouillée' : 'Gameweek locked';
  String get noActiveGameweek => _fr ? 'Aucune journée active' : 'No active gameweek';
  String gameweekShort(int n) => _fr ? 'J$n' : 'GW$n';

  // ─── Round 5: how to play / scoring rules ──────────────────────────
  String get howToPlay => _fr ? 'Comment jouer' : 'How to play';
  String get scoringRules => _fr ? 'Règles de score' : 'Scoring rules';
  String get rulesIntro => _fr
      ? 'Compose ton équipe de 15 joueurs, choisis ton capitaine et marque des points selon les performances réelles à la Coupe du Monde 2026.'
      : 'Build your 15-player squad, pick a captain and score points from real World Cup 2026 performances.';
  String get rulesSquadTitle => _fr ? 'Ton effectif' : 'Your squad';
  String get rulesSquadBody => _fr
      ? '2 gardiens, 5 défenseurs, 5 milieux, 3 attaquants — budget de 100 M€. Le capitaine marque double (×2).'
      : '2 goalkeepers, 5 defenders, 5 midfielders, 3 forwards — 100 M€ budget. The captain scores double (×2).';
  String get rulesPointsTitle => _fr ? 'Points par action' : 'Points per action';
  String get rulesBonusTitle => _fr ? 'Bonus & malus' : 'Bonuses & penalties';
  String get rulesChipsTitle => _fr ? 'Boosts (1 fois chacun)' : 'Chips (once each)';
  String get colAction => _fr ? 'Action' : 'Action';
  String get actionPlaying60 => _fr ? 'Jouer 60 min ou +' : 'Play 60+ min';
  String get actionPlayingSub => _fr ? 'Jouer 1–59 min' : 'Play 1–59 min';
  String get actionGoal => _fr ? 'But' : 'Goal';
  String get actionAssist => _fr ? 'Passe décisive' : 'Assist';
  String get actionCleanSheet => _fr ? 'Cage inviolée' : 'Clean sheet';
  String get actionYellow => _fr ? 'Carton jaune' : 'Yellow card';
  String get actionRed => _fr ? 'Carton rouge' : 'Red card';
  String get bonusHatTrick => _fr ? 'Triplé (3+ buts)' : 'Hat-trick (3+ goals)';
  String get bonusPenSave => _fr ? 'Penalty arrêté' : 'Penalty save';
  String get bonusPenMiss => _fr ? 'Penalty manqué' : 'Penalty missed';
  String get bonusOwnGoal => _fr ? 'But contre son camp' : 'Own goal';

  // ─── Round 5: chips ────────────────────────────────────────────────
  String get chips => _fr ? 'Boosts' : 'Chips';
  String get chipTripleCaptain => _fr ? 'Capitaine Triple' : 'Triple Captain';
  String get chipTripleCaptainDesc => _fr ? 'Ton capitaine marque ×3 cette journée.' : 'Your captain scores ×3 this gameweek.';
  String get chipSuperSub => _fr ? 'Super Remplaçant' : 'Super Sub';
  String get chipSuperSubDesc => _fr ? 'Un 2e joueur marque ×2 cette journée.' : 'A 2nd player scores ×2 this gameweek.';
  String get chipShield => _fr ? 'Bouclier' : 'Shield';
  String get chipShieldDesc => _fr ? 'Aucun point négatif cette journée.' : 'No negative points this gameweek.';
  String get chipAvailable => _fr ? 'Disponible' : 'Available';
  String get chipArmed => _fr ? 'Activé' : 'Armed';
  String get chipUsed => _fr ? 'Utilisé' : 'Used';
  String get chipArm => _fr ? 'Activer' : 'Arm';
  String chipArmedMsg(String chip) => _fr ? '$chip activé pour cette journée !' : '$chip armed for this gameweek!';
  String get chooseBoostPlayer => _fr ? 'Choisis le joueur à booster' : 'Choose the player to boost';

  // ─── Round 5: fixtures / match center ──────────────────────────────
  String get fixtures => _fr ? 'Matchs' : 'Fixtures';
  String get matchCenter => _fr ? 'Centre des matchs' : 'Match center';
  String get live => _fr ? 'EN DIRECT' : 'LIVE';
  String get upcoming => _fr ? 'À venir' : 'Upcoming';
  String get finished => _fr ? 'Terminé' : 'Finished';
  String matchday(int n) => _fr ? 'Journée $n' : 'Matchday $n';
  String get noFixtures => _fr ? 'Aucun match pour le moment' : 'No matches yet';

  // ─── Round 5: friends ──────────────────────────────────────────────
  String get friends => _fr ? 'Amis' : 'Friends';
  String get addFriend => _fr ? 'Ajouter' : 'Add';
  String get friendRequests => _fr ? 'Demandes' : 'Requests';
  String get searchUsers => _fr ? 'Rechercher un joueur…' : 'Search players…';
  String get accept => _fr ? 'Accepter' : 'Accept';
  String get decline => _fr ? 'Refuser' : 'Decline';
  String get noResults => _fr ? 'Aucun résultat' : 'No results';
  String get noFriendsYet => _fr ? 'Pas encore d\'amis — cherche des joueurs !' : 'No friends yet — search for players!';
  String get noRequests => _fr ? 'Aucune demande en attente' : 'No pending requests';
  String get requestSent => _fr ? 'Demande envoyée !' : 'Request sent!';
  String get friendAdded => _fr ? 'Ami ajouté !' : 'Friend added!';

  // ─── Round 5: share / QR + presence ────────────────────────────────
  String get shareLeague => _fr ? 'Partager la ligue' : 'Share league';
  String get scanToJoin => _fr ? 'Scanne pour rejoindre' : 'Scan to join';
  String get copyCode => _fr ? 'Copier le code' : 'Copy code';
  String get codeCopied => _fr ? 'Code copié !' : 'Code copied!';
  String onlineCount(int n) => _fr ? '$n en ligne' : '$n online';
  String get someoneTyping => _fr ? 'écrit…' : 'typing…';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['fr', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
