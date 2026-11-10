import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../services/locale_notifier.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Map<String, dynamic>? _settings;
  bool _loading = true;
  bool _saving = false;

  // Password change
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _showPwSection = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await apiService.getSettings();
      if (mounted) setState(() { _settings = data['settings'] as Map<String, dynamic>; _loading = false; });
    } catch (e) {
      debugPrint('[Settings._load] $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).cannotLoadSettings), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleSetting(String key, bool value) async {
    setState(() => _settings![key] = value);
    try {
      await apiService.updateSettings({key: value});
    } catch (e) {
      debugPrint('[Settings._toggleSetting] $e');
      // Revert on error
      if (mounted) setState(() => _settings![key] = !value);
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPwCtrl.text.trim();
    final newPw = _newPwCtrl.text.trim();
    final confirm = _confirmPwCtrl.text.trim();

    final l = AppLocalizations.of(context);
    if (current.isEmpty || newPw.isEmpty) {
      _snack(l.fillAllFields, Colors.red);
      return;
    }
    if (newPw != confirm) {
      _snack(l.passwordsMismatch, Colors.red);
      return;
    }
    if (newPw.length < 8) {
      _snack(l.min8chars, Colors.red);
      return;
    }

    setState(() => _saving = true);
    try {
      await apiService.changePassword(current, newPw);
      _currentPwCtrl.clear();
      _newPwCtrl.clear();
      _confirmPwCtrl.clear();
      if (mounted) setState(() { _saving = false; _showPwSection = false; });
      _snack(l.passwordChanged, Colors.green);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      _snack('Erreur: ${e.toString().replaceAll('Exception: ', '')}', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: BrandAppBar(title: Text(l.settings)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Notifications section
                _SectionHeader(l.notifications),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.sports_score,
                  title: l.battlesScores,
                  subtitle: l.battlesScoresSubtitle,
                  value: _settings?['notifications_battles'] as bool? ?? true,
                  onChanged: (v) => _toggleSetting('notifications_battles', v),
                ),
                _SettingsTile(
                  icon: Icons.chat_bubble_outline,
                  title: l.leagueChat,
                  subtitle: l.leagueChatSubtitle,
                  value: _settings?['notifications_chat'] as bool? ?? true,
                  onChanged: (v) => _toggleSetting('notifications_chat', v),
                ),
                _SettingsTile(
                  icon: Icons.newspaper_outlined,
                  title: l.wcNews,
                  subtitle: l.wcNewsSubtitle,
                  value: _settings?['notifications_news'] as bool? ?? false,
                  onChanged: (v) => _toggleSetting('notifications_news', v),
                ),

                const SizedBox(height: 24),

                // Appearance section
                _SectionHeader(l.appearance),
                const SizedBox(height: 8),
                _LanguageTile(),

                const SizedBox(height: 24),

                // Security section
                _SectionHeader(l.security),
                const SizedBox(height: 8),

                Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.lock_outline, color: AppColors.gold),
                        title: Text(l.changePassword, style: const TextStyle(color: Colors.white)),
                        trailing: Icon(
                          _showPwSection ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white54,
                        ),
                        onTap: () => setState(() => _showPwSection = !_showPwSection),
                      ),
                      if (_showPwSection) ...[
                        const Divider(color: Colors.white12, height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _PwField(
                                ctrl: _currentPwCtrl,
                                label: l.currentPassword,
                                obscure: _obscureCurrent,
                                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                              ),
                              const SizedBox(height: 12),
                              _PwField(
                                ctrl: _newPwCtrl,
                                label: l.newPassword,
                                obscure: _obscureNew,
                                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                              ),
                              const SizedBox(height: 12),
                              _PwField(
                                ctrl: _confirmPwCtrl,
                                label: l.confirmNewPassword,
                                obscure: _obscureNew,
                                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _changePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: _saving
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                      : Text(l.changePassword, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Admin section — only rendered for admin users (also gated server-side).
                // Uses the live profile so it reflects the actually logged-in account.
                ...ref.watch(myProfileProvider).when(
                  loading: () => const [SizedBox.shrink()],
                  error: (e, _) => [
                    const SizedBox(height: 12),
                    Text('⚠️ Profil: $e', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                  data: (user) {
                    final widgets = <Widget>[
                      const SizedBox(height: 16),
                      // Diagnostic line: which account + role the app currently sees.
                      Text(
                        '${user?.email ?? '—'} · ${user?.role ?? 'user'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ];
                    if (user?.isAdmin ?? false) {
                      widgets.addAll([
                        const SizedBox(height: 16),
                        _SectionHeader(l.administration),
                        const SizedBox(height: 8),
                        Card(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.warning),
                            title: Text(l.adminDashboard, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(l.adminDashboardSubtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 16),
                            onTap: () => context.push('/admin'),
                          ),
                        ),
                      ]);
                    }
                    widgets.add(const SizedBox(height: 24));
                    return widgets;
                  },
                ),

                // App info section
                _SectionHeader(l.appInfo),
                const SizedBox(height: 8),
                Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _InfoTile(label: l.version, value: '1.0.0'),
                      const Divider(color: Colors.white12, height: 1),
                      _InfoTile(label: l.season, value: 'WC 2026'),
                      const Divider(color: Colors.white12, height: 1),
                      _InfoTile(label: l.serverStatus, value: l.connected),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Danger zone
                _SectionHeader(l.dangerZone),
                const SizedBox(height: 8),
                Card(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    title: Text(l.deleteAccount, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    onTap: _deleteAccount,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Future<void> _deleteAccount() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l.deleteAccount, style: const TextStyle(color: Colors.white)),
        content: Text(l.deleteAccountConfirm, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.deleteAccount),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await apiService.deleteAccount();
      if (mounted) context.go('/landing');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.error}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Icon(icon, color: value ? AppColors.gold : Colors.white38),
        title: Text(title, style: TextStyle(color: value ? Colors.white : Colors.white54, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.gold,
      ),
    );
  }
}

class _PwField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;

  const _PwField({required this.ctrl, required this.label, required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white38, size: 20),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Language selector ────────────────────────────────────────────────────────

class _LanguageTile extends StatefulWidget {
  @override
  State<_LanguageTile> createState() => _LanguageTileState();
}

class _LanguageTileState extends State<_LanguageTile> {
  @override
  void initState() {
    super.initState();
    localeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    localeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isFr = localeNotifier.isFrench;
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.language, color: AppColors.gold),
            const SizedBox(width: 16),
            const Expanded(
              child: Text('Langue / Language',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            _LangChip(
              label: '🇫🇷 FR',
              selected: isFr,
              onTap: () => localeNotifier.setLocale('fr'),
            ),
            const SizedBox(width: 8),
            _LangChip(
              label: '🇬🇧 EN',
              selected: !isFr,
              onTap: () => localeNotifier.setLocale('en'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.gold : Colors.white54,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
