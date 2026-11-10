import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/haptics.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/brand_app_bar.dart';

/// Friends: search users by username, send/accept requests, view your friends
/// ranked by total points.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _cast(List<dynamic> raw) =>
      raw.map((e) => (e as Map).cast<String, dynamic>()).toList();

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([apiService.getFriends(), apiService.getFriendRequests()]);
      if (!mounted) return;
      setState(() {
        _friends = _cast(results[0]);
        _requests = _cast(results[1]);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _searching = false; _results = []; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(q.trim()));
  }

  Future<void> _runSearch(String q) async {
    setState(() => _searching = true);
    try {
      final res = await apiService.searchUsers(q);
      if (mounted) setState(() => _results = _cast(res));
    } catch (_) {/* ignore */}
  }

  Future<void> _add(String username) async {
    final l = AppLocalizations.of(context);
    try {
      await apiService.sendFriendRequest(username);
      Haptics.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.requestSent), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.error}: ${_msg(e)}'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _accept(String userId) async {
    final l = AppLocalizations.of(context);
    await apiService.acceptFriend(userId).catchError((_) {});
    Haptics.success();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.friendAdded), backgroundColor: AppColors.success),
      );
    }
    _loadAll();
  }

  Future<void> _remove(String userId) async {
    await apiService.removeFriend(userId).catchError((_) {});
    Haptics.light();
    _loadAll();
  }

  String _msg(Object e) => e.toString().contains('409')
      ? 'already linked'
      : e.toString().contains('404')
          ? 'not found'
          : 'failed';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: BrandAppBar(title: Text(l.friends)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: l.searchUsers,
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : _searching
                    ? _buildSearchResults(l)
                    : _buildFriendsAndRequests(l),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppLocalizations l) {
    if (_results.isEmpty) {
      return Center(child: Text(l.noResults, style: const TextStyle(color: Colors.white54)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final u = _results[i];
        return _UserRow(
          user: u,
          trailing: TextButton.icon(
            onPressed: () => _add(u['username'] as String),
            icon: const Icon(Icons.person_add_alt, size: 16),
            label: Text(l.addFriend),
            style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          ),
        );
      },
    );
  }

  Widget _buildFriendsAndRequests(AppLocalizations l) {
    if (_friends.isEmpty && _requests.isEmpty) {
      return AppEmptyState(icon: Icons.group_add, title: l.noFriendsYet);
    }
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (_requests.isNotEmpty) ...[
            _SectionLabel('${l.friendRequests} (${_requests.length})'),
            ..._requests.map((u) => _UserRow(
                  user: u,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: AppColors.success),
                        tooltip: l.accept,
                        onPressed: () => _accept(u['id'] as String),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        tooltip: l.decline,
                        onPressed: () => _remove(u['id'] as String),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
          ],
          _SectionLabel(l.friends),
          if (_friends.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l.noFriendsYet, style: const TextStyle(color: Colors.white38)),
            ),
          ..._friends.map((u) => _UserRow(
                user: u,
                onTap: () => context.push('/manager/${u['id']}'),
                trailing: u['rank'] != null
                    ? Text('#${u['rank']}', style: const TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.bold))
                    : null,
              )),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: const TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.bold, fontSize: 14)),
      );
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _UserRow({required this.user, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = user['username'] as String? ?? '?';
    final points = user['total_points'];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.navy,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                if (points != null)
                  Text('$points pts', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    ),
    );
  }
}
