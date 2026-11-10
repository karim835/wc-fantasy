import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../widgets/performance_chart.dart';
import '../widgets/share_button.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_empty_state.dart';
import '../l10n/app_localizations.dart';
import '../constants/wc_nations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _data;
  List<dynamic> _achievements = [];
  bool _isLoading = true;
  bool _editMode = false;
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _favClubCtrl = TextEditingController();
  final _favPlayerCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String? _selectedCountry;
  String? _selectedNation;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    analyticsService.logScreen('profile');
    _load();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _favClubCtrl.dispose();
    _favPlayerCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        apiService.getProfileStats(),
        apiService.getAchievements(),
      ]);
      setState(() {
        _data = results[0] as Map<String, dynamic>;
        _achievements = results[1] as List<dynamic>;
        final user = _data!['user'] as Map<String, dynamic>? ?? {};
        _usernameCtrl.text = user['username'] ?? '';
        _emailCtrl.text = user['email'] ?? '';
        _favClubCtrl.text = user['favorite_club'] ?? '';
        _favPlayerCtrl.text = user['favorite_player'] ?? '';
        _bioCtrl.text = user['bio'] ?? '';
        _selectedCountry = user['country'] as String?;
        _selectedNation = user['favorite_nation'] as String?;
      });
    } catch (e) {
      debugPrint('[Profile._load] $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).cannotLoadProfile), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_usernameCtrl.text.trim().isEmpty) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final currentEmail = (_data?['user'] as Map?)?['email'] as String?;
      final newEmail = _emailCtrl.text.trim();
      await apiService.updateProfile(
        username: _usernameCtrl.text.trim(),
        email: (newEmail.isNotEmpty && newEmail != currentEmail) ? newEmail : null,
        country: _selectedCountry,
        favoriteNation: _selectedNation,
        favoriteClub: _favClubCtrl.text.trim().isEmpty ? null : _favClubCtrl.text.trim(),
        favoritePlayer: _favPlayerCtrl.text.trim().isEmpty ? null : _favPlayerCtrl.text.trim(),
        bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      );
      setState(() => _editMode = false);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.profileUpdated), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      final taken = e.toString().contains('409') || e.toString().contains('already taken');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(taken ? l.emailTaken : '${l.error}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final l = AppLocalizations.of(context);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 70);
      if (file == null) return;
      setState(() => _uploadingAvatar = true);
      final bytes = await file.readAsBytes();
      final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
      await apiService.uploadAvatar(bytes, ext);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.photoUpdated), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.error}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.logout, style: const TextStyle(color: Colors.white)),
        content: Text(l.logoutConfirm, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.logout, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await apiService.logout();
      if (mounted) context.go('/landing');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandAppBar(
        title: Text(AppLocalizations.of(context).profile),
        actions: [
          if (!_editMode)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editMode = true),
              tooltip: AppLocalizations.of(context).save,
            )
          else
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(AppLocalizations.of(context).save, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ),
          // Bouton partage profil (share_plus — gratuit)
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white70),
            tooltip: 'Partager mon profil',
            onPressed: () {
              final user = _data?['user'];
              final pts  = user?['total_points'] ?? 0;
              final name = user?['username'] ?? 'Mon équipe';
              ShareSheet.show(
                context,
                title: 'Mon profil WC Fantasy',
                message: '$name est sur WC Fantasy ! Rejoins-moi pour la Coupe du Monde.',
                score: '$pts',
                leagueName: 'WC Fantasy',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: AppLocalizations.of(context).settings,
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.redAccent),
            onPressed: _logout,
            tooltip: AppLocalizations.of(context).logout,
          ),
        ],
      ),
      body: _isLoading
          ? const ProfileSkeleton()
          : _data == null
              ? AppEmptyState.error(onRetry: _load)
              : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ProfileHeader(
                    user: _data?['user'],
                    editMode: _editMode,
                    usernameCtrl: _usernameCtrl,
                    emailCtrl: _emailCtrl,
                    uploadingAvatar: _uploadingAvatar,
                    onPickAvatar: _pickAvatar,
                    onCancelEdit: () => setState(() => _editMode = false),
                  ),
                  const SizedBox(height: 16),
                  _AboutCard(
                    user: _data?['user'],
                    editMode: _editMode,
                    favClubCtrl: _favClubCtrl,
                    favPlayerCtrl: _favPlayerCtrl,
                    bioCtrl: _bioCtrl,
                    selectedCountry: _selectedCountry,
                    selectedNation: _selectedNation,
                    onCountryChanged: (v) => setState(() => _selectedCountry = v),
                    onNationChanged: (v) => setState(() => _selectedNation = v),
                  ),
                  const SizedBox(height: 20),
                  _StatsGrid(data: _data),
                  const SizedBox(height: 20),
                  if ((_data?['stats']?['gw_history'] as List?)?.isNotEmpty == true) ...[
                    _SectionTitle('Performance'),
                    const SizedBox(height: 10),
                    // ── Graphique de performance (fl_chart — gratuit) ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: PerformanceChart(
                        gwHistory: _data!['stats']['gw_history'] as List,
                        title: 'Points par Gameweek',
                        lineColor: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _GwHistory(history: _data!['stats']['gw_history'] as List),
                    const SizedBox(height: 20),
                  ],
                  if ((_data?['stats']?['teams'] as List?)?.isNotEmpty == true) ...[
                    _SectionTitle('Mes Équipes'),
                    const SizedBox(height: 10),
                    _TeamsList(teams: _data!['stats']['teams'] as List),
                    const SizedBox(height: 20),
                  ],
                  _PredictionSummary(predictions: _data?['stats']?['predictions']),
                  if (_achievements.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionTitle('Achievements'),
                    const SizedBox(height: 10),
                    _AchievementsSection(achievements: _achievements),
                  ],
                  const SizedBox(height: 20),
                  _WrappedBanner(),
                ],
              ),
            ),
    );
  }
}

class _WrappedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => context.push('/wrapped'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), AppColors.gold],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.bar_chart, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.seasonWrapped, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(l.viewRecap, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Achievements Section ─────────────────────────────────────────────────────

class _AchievementsSection extends StatelessWidget {
  final List<dynamic> achievements;
  const _AchievementsSection({required this.achievements});

  static const _iconMap = <String, IconData>{
    'sports_soccer': Icons.sports_soccer,
    'emoji_events': Icons.emoji_events,
    'military_tech': Icons.military_tech,
    'stars': Icons.stars,
    'psychology': Icons.psychology,
    'grade': Icons.grade,
    'workspace_premium': Icons.workspace_premium,
    'chat': Icons.chat,
    'account_tree': Icons.account_tree,
  };

  @override
  Widget build(BuildContext context) {
    final unlocked = achievements.where((a) => a['unlocked'] == true).toList();
    final locked = achievements.where((a) => a['unlocked'] != true).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Row(
          children: [
            Text(
              '${unlocked.length} / ${achievements.length} débloqués',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: achievements.isEmpty
                      ? 0
                      : unlocked.length / achievements.length,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.goldBright),
                  minHeight: 6,
                ),
              )
                  .animate()
                  .slideX(begin: -1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
            ),
          ],
        ),

        if (unlocked.isNotEmpty) ...[
          const SizedBox(height: 14),
          // Unlocked grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: unlocked.length,
            itemBuilder: (_, i) {
              final a = unlocked[i] as Map<String, dynamic>;
              final icon = _iconMap[a['icon'] as String? ?? ''] ?? Icons.stars;
              return _BadgeTile(icon: icon, title: a['title'] ?? '', unlocked: true)
                  .animate(delay: Duration(milliseconds: i * 80))
                  .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 300.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 200.ms);
            },
          ),
        ],

        if (locked.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('À débloquer', style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          ...locked.asMap().entries.map((e) {
            final a = e.value as Map<String, dynamic>;
            final icon = _iconMap[a['icon'] as String? ?? ''] ?? Icons.stars;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white12, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['title'] ?? '',
                              style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(a['description'] ?? '',
                              style: const TextStyle(color: Colors.white24, fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_outline, color: Colors.white12, size: 16),
                  ],
                ),
              )
                  .animate(delay: Duration(milliseconds: e.key * 40))
                  .fadeIn(duration: 200.ms)
                  .slideX(begin: 0.05, end: 0, duration: 200.ms),
            );
          }),
        ],
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool unlocked;
  const _BadgeTile({required this.icon, required this.title, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.surfaceElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBright.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldBright.withValues(alpha: 0.12),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldBright.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: AppColors.goldBright, size: 24),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Profile Header ───────────────────────────────────────────────────────────

String _monthYear(DateTime d, BuildContext context) {
  final fr = Localizations.localeOf(context).languageCode == 'fr';
  const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const frM = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  return '${(fr ? frM : en)[d.month - 1]} ${d.year}';
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic>? user;
  final bool editMode;
  final TextEditingController usernameCtrl;
  final TextEditingController emailCtrl;
  final bool uploadingAvatar;
  final VoidCallback onPickAvatar;
  final VoidCallback onCancelEdit;

  const _ProfileHeader({
    required this.user,
    required this.editMode,
    required this.usernameCtrl,
    required this.emailCtrl,
    required this.uploadingAvatar,
    required this.onPickAvatar,
    required this.onCancelEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final initial = (user?['username'] ?? 'U')[0].toUpperCase();
    final avatarUrl = user?['avatar_url'] as String?;
    final createdAt = user?['created_at'] != null ? DateTime.tryParse(user!['created_at'].toString()) : null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.surface, AppColors.background]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.gold,
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? CachedNetworkImageProvider(ApiService.absoluteUrl(avatarUrl))
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(initial, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black))
                    : null,
              ),
              if (uploadingAvatar)
                const Positioned.fill(child: CircleAvatar(radius: 40, backgroundColor: Colors.black45, child: CircularProgressIndicator(color: Colors.white))),
              if (editMode)
                Positioned(
                  right: 0, bottom: 0,
                  child: GestureDetector(
                    onTap: onPickAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (editMode) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: usernameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: l.newUsername,
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: onCancelEdit,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: l.email,
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ] else ...[
            Text(user?['username'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user?['email'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(l.memberSince(_monthYear(createdAt, context)), style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Text(
              '${user?['total_points'] ?? 0} points totaux',
              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── About Card ──────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  final Map<String, dynamic>? user;
  final bool editMode;
  final TextEditingController favClubCtrl;
  final TextEditingController favPlayerCtrl;
  final TextEditingController bioCtrl;
  final String? selectedCountry;
  final String? selectedNation;
  final ValueChanged<String?> onCountryChanged;
  final ValueChanged<String?> onNationChanged;

  const _AboutCard({
    required this.user,
    required this.editMode,
    required this.favClubCtrl,
    required this.favPlayerCtrl,
    required this.bioCtrl,
    required this.selectedCountry,
    required this.selectedNation,
    required this.onCountryChanged,
    required this.onNationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dob = user?['date_of_birth'] as String?;
    final country = user?['country'] as String?;
    final nation = user?['favorite_nation'] as String?;
    final club = user?['favorite_club'] as String?;
    final player = user?['favorite_player'] as String?;
    final bio = user?['bio'] as String?;

    final hasContent = editMode ||
        dob != null || country != null || nation != null ||
        club != null || player != null || bio != null;
    if (!hasContent) return const SizedBox();

    String? formatDob(String? raw) {
      if (raw == null) return null;
      try {
        final dt = DateTime.parse(raw);
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } catch (_) {
        return raw;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(l.aboutMe, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          if (!editMode) ...[
            if (formatDob(dob) != null)
              _InfoRow(Icons.cake_outlined, l.dateOfBirth, formatDob(dob)!),
            if (country != null)
              _InfoRow(Icons.flag_outlined, l.country, country),
            if (nation != null)
              _InfoRow(Icons.sports_soccer_outlined, l.favoriteNation, nation),
            if (club != null)
              _InfoRow(Icons.shield_outlined, l.favoriteClub, club),
            if (player != null)
              _InfoRow(Icons.star_outline, l.favoritePlayer, player),
            if (bio != null) ...[
              const SizedBox(height: 8),
              Text(bio, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ] else ...[
            _ProfileDropdown(
              label: l.country,
              value: selectedCountry,
              items: wcNations2026.where((n) => n != 'Other').toList()..add('Other'),
              onChanged: onCountryChanged,
            ),
            const SizedBox(height: 10),
            _ProfileDropdown(
              label: l.favoriteNation,
              value: selectedNation,
              items: wcNations2026.where((n) => n != 'Other').toList()..add('Other'),
              onChanged: onNationChanged,
            ),
            const SizedBox(height: 10),
            _EditField(controller: favClubCtrl, label: l.favoriteClub, icon: Icons.shield_outlined),
            const SizedBox(height: 10),
            _EditField(controller: favPlayerCtrl, label: l.favoritePlayer, icon: Icons.star_outline),
            const SizedBox(height: 10),
            _EditField(controller: bioCtrl, label: l.bio, icon: Icons.edit_note, maxLines: 3, maxLength: 300),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white38, size: 16),
            const SizedBox(width: 8),
            Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 13)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white38, size: 18),
          filled: true,
          fillColor: Colors.white10,
          counterStyle: const TextStyle(color: Colors.white38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}

class _ProfileDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _ProfileDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: Colors.white),
        items: items.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
        onChanged: onChanged,
      );
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final stats = data?['stats'];
    final leaguesCount = stats?['leagues_count'] ?? 0;
    final teamsCount = (stats?['teams'] as List?)?.length ?? 0;
    final predTotal = stats?['predictions']?['total'] ?? 0;
    final predCorrect = stats?['predictions']?['correct'] ?? 0;
    final accuracy = predTotal > 0 ? '${(predCorrect / predTotal * 100).toStringAsFixed(0)}%' : '-';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _StatCard(icon: Icons.emoji_events, label: 'Ligues', value: '$leaguesCount', color: AppColors.gold),
        _StatCard(icon: Icons.people, label: 'Équipes', value: '$teamsCount', color: const Color(0xFF66BB6A)),
        _StatCard(icon: Icons.lightbulb, label: 'Prédictions', value: '$predTotal', color: const Color(0xFFFFA726)),
        _StatCard(icon: Icons.gps_fixed, label: 'Précision', value: accuracy, color: const Color(0xFFAB47BC)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── GW History ───────────────────────────────────────────────────────────────

class _GwHistory extends StatelessWidget {
  final List history;
  const _GwHistory({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: history.asMap().entries.map((e) {
          final gw = e.value as Map<String, dynamic>;
          final pts = gw['gw_points'] ?? 0;
          final isLast = e.key == history.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isLast ? null : const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('GW${gw['number']}',
                      style: const TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(gw['season'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                Text('$pts pts',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Teams List ───────────────────────────────────────────────────────────────

class _TeamsList extends StatelessWidget {
  final List teams;
  const _TeamsList({required this.teams});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: teams.map((t) {
        final team = t as Map<String, dynamic>;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.people, color: AppColors.gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(team['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    Text('${team['league_name']} · ${team['formation']}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    if (team['captain_name'] != null)
                      Text('⭐ Capitaine: ${team['captain_name']}',
                          style: const TextStyle(color: AppColors.goldBright, fontSize: 11)),
                  ],
                ),
              ),
              Text('${team['total_points']} pts',
                  style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Prediction Summary ───────────────────────────────────────────────────────

class _PredictionSummary extends StatelessWidget {
  final Map<String, dynamic>? predictions;
  const _PredictionSummary({required this.predictions});

  @override
  Widget build(BuildContext context) {
    if (predictions == null) return const SizedBox();
    final total = predictions!['total'] ?? 0;
    final correct = predictions!['correct'] ?? 0;
    final bonus = predictions!['bonus_pts'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFAB47BC).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Color(0xFFAB47BC), size: 18),
              SizedBox(width: 8),
              Text('Prédictions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PredStat('Total', '$total', Colors.white70),
              _PredStat('Correctes', '$correct', Colors.greenAccent),
              _PredStat('Bonus pts', '+$bonus', const Color(0xFFAB47BC)),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: correct / total,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFAB47BC)),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Text('${(correct / total * 100).toStringAsFixed(0)}% de précision',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _PredStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PredStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));
}
