import 'package:flutter/material.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../constants/wc_nations.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  /// When true, the form opens directly in account-creation mode (used by the
  /// landing page's "Create account" button).
  final bool startInRegister;
  const LoginScreen({super.key, this.startInRegister = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _favClubCtrl = TextEditingController();
  final _favPlayerCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  late bool _isRegisterMode = widget.startInRegister;
  String? _serverError;

  // Registration extras
  DateTime? _dateOfBirth;
  String? _country;
  String? _favoriteNation;

  // Multi-step registration
  int _step = 1; // 1 = credentials, 2 = profile questions

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    _favClubCtrl.dispose();
    _favPlayerCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _serverError = null; });
    try {
      if (_isRegisterMode) {
        String? dobStr;
        if (_dateOfBirth != null) {
          dobStr = '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}';
        }
        await apiService.register(
          _usernameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          dateOfBirth: dobStr,
          country: _country,
          favoriteNation: _favoriteNation,
          favoriteClub: _favClubCtrl.text.trim().isEmpty ? null : _favClubCtrl.text.trim(),
          favoritePlayer: _favPlayerCtrl.text.trim().isEmpty ? null : _favPlayerCtrl.text.trim(),
          bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        );
        final onboardingDone = await OnboardingScreen.isDone();
        if (mounted) context.go(onboardingDone ? '/home' : '/onboarding');
      } else {
        await apiService.login(_emailCtrl.text.trim(), _passwordCtrl.text);
        if (mounted) context.go('/home');
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] as String?
          ?? e.response?.data?['message'] as String?
          ?? 'Erreur de connexion au serveur';
      if (mounted) setState(() { _serverError = msg; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _serverError = e.toString(); _isLoading = false; });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_step == 1 && _formKey.currentState!.validate()) {
      setState(() { _step = 2; _serverError = null; });
    }
  }

  void _resetMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _step = 1;
      _serverError = null;
      _dateOfBirth = null;
      _country = null;
      _favoriteNation = null;
      _favClubCtrl.clear();
      _favPlayerCtrl.clear();
      _bioCtrl.clear();
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 5),
      helpText: l.dobPicker,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/images/logo.png', height: 96),
                  const SizedBox(height: 12),
                  Text(
                    'WC Fantasy',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRegisterMode
                        ? (_step == 1 ? l.createAccount : l.profileInfo)
                        : l.welcome,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60),
                  ),
                  // Step indicator for register
                  if (_isRegisterMode) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StepDot(active: _step == 1, done: _step > 1),
                        const SizedBox(width: 8),
                        Container(height: 2, width: 40, color: _step > 1 ? AppColors.gold : Colors.white24),
                        const SizedBox(width: 8),
                        _StepDot(active: _step == 2, done: false),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_serverError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_serverError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                        ],
                      ),
                    ),

                  // ── Step 1: credentials ──────────────────────────────
                  if (!_isRegisterMode || _step == 1) ...[
                    if (_isRegisterMode) ...[
                      TextFormField(
                        controller: _usernameCtrl,
                        decoration: _inputDecoration(l.username, Icons.person_outline),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) { if (_serverError != null) setState(() => _serverError = null); },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return l.fieldRequired;
                          if (v.trim().length < 3) return l.min3chars;
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration('Email', Icons.email_outlined),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) { if (_serverError != null) setState(() => _serverError = null); },
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return l.fieldRequired;
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) return l.invalidEmail;
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_showPassword,
                      decoration: _inputDecoration(l.password, Icons.lock_outline).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      textInputAction: _isRegisterMode ? TextInputAction.next : TextInputAction.done,
                      onFieldSubmitted: (_) => _isRegisterMode ? _nextStep() : _submit(),
                      onChanged: (_) { if (_serverError != null) setState(() => _serverError = null); },
                      validator: (v) {
                        if (v == null || v.isEmpty) return l.fieldRequired;
                        if (v.length < 8) return l.min8chars;
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      onPressed: _isLoading ? null : (_isRegisterMode ? _nextStep : _submit),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.5),
                      ),
                      child: Text(
                        _isRegisterMode ? l.next : l.loginBtn,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],

                  // ── Step 2: profile questions ────────────────────────
                  if (_isRegisterMode && _step == 2) ...[
                    // Date of birth
                    GestureDetector(
                      onTap: () => _pickDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_outlined, color: Colors.white38, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _dateOfBirth == null
                                  ? l.dateOfBirth
                                  : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                              style: TextStyle(
                                color: _dateOfBirth == null ? Colors.white54 : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Country
                    _DropdownField(
                      label: l.country,
                      icon: Icons.public,
                      value: _country,
                      items: wcNations2026,
                      onChanged: (v) => setState(() => _country = v),
                    ),
                    const SizedBox(height: 14),
                    // Favorite WC nation
                    _DropdownField(
                      label: l.favoriteNation,
                      icon: Icons.flag_outlined,
                      value: _favoriteNation,
                      items: wcNations2026,
                      onChanged: (v) => setState(() => _favoriteNation = v),
                    ),
                    const SizedBox(height: 14),
                    // Favorite club
                    TextFormField(
                      controller: _favClubCtrl,
                      decoration: _inputDecoration(l.favoriteClub, Icons.sports_soccer),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    // Favorite player
                    TextFormField(
                      controller: _favPlayerCtrl,
                      decoration: _inputDecoration(l.favoritePlayer, Icons.person_pin_outlined),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    // Bio
                    TextFormField(
                      controller: _bioCtrl,
                      maxLines: 3,
                      maxLength: 300,
                      decoration: _inputDecoration(l.bio, Icons.edit_note_outlined).copyWith(
                        alignLabelWithHint: true,
                        counterStyle: const TextStyle(color: Colors.white38),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _step = 1),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(l.back),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.5),
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : Text(l.createAccount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _resetMode,
                    child: Text(
                      _isRegisterMode ? l.alreadyAccount : l.noAccount,
                      style: const TextStyle(color: AppColors.gold),
                    ),
                  ),
                  if (!_isRegisterMode)
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: Text(
                        l.forgotPassword,
                        style: const TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gold)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
        filled: true,
        fillColor: AppColors.surface,
        errorStyle: const TextStyle(color: Colors.redAccent),
      );
}

class _StepDot extends StatelessWidget {
  final bool active;
  final bool done;
  const _StepDot({required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (active || done) ? AppColors.gold : Colors.white12,
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 14, color: Colors.black)
            : Text(
                active ? '●' : '○',
                style: TextStyle(
                  color: active ? Colors.black : Colors.white38,
                  fontSize: 10,
                ),
              ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, color: Colors.white38, size: 20),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(color: Colors.white54)),
            ],
          ),
          dropdownColor: AppColors.surface,
          isExpanded: true,
          iconEnabledColor: Colors.white38,
          style: const TextStyle(color: Colors.white),
          items: items.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
