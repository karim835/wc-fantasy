import 'package:flutter/material.dart';
import 'package:wc_fantasy/widgets/brand_app_bar.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/news_article.dart';
import '../services/api_service.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/app_empty_state.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<NewsArticle> _articles = [];
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadNews(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      if (!_isLoading && _hasMore) _loadNews();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await apiService.getNewsCategories();
      setState(() => _categories = cats.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint('[News._loadCategories] $e');
    }
  }

  Future<void> _loadNews({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) setState(() { _articles = []; _page = 1; _hasMore = true; _error = null; });
    setState(() => _isLoading = true);
    try {
      final result = await apiService.getNews(
        page: _page,
        limit: 20,
        category: _selectedCategory,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      final rawList = result['articles'] as List<dynamic>? ?? [];
      final newArticles = rawList.map((e) => NewsArticle.fromJson(e as Map<String, dynamic>)).toList();
      final pagination = result['pagination'] as Map<String, dynamic>?;
      setState(() {
        _articles.addAll(newArticles);
        _hasMore = pagination?['hasMore'] as bool? ?? false;
        _page++;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _selectCategory(String? cat) {
    setState(() => _selectedCategory = cat == _selectedCategory ? null : cat);
    _loadNews(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: BrandAppBar(
        title: Row(
          children: [
            const Text('⚽', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context).newsTitle),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context).refresh,
            onPressed: () => _loadNews(reset: true),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_categories.isNotEmpty ? 110 : 64),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  onSubmitted: (_) => _loadNews(reset: true),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).searchNews,
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () { _searchCtrl.clear(); _loadNews(reset: true); },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (_categories.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                  child: Row(
                    children: [
                      _CategoryChip(label: 'Tout', selected: _selectedCategory == null, onTap: () => _selectCategory(null)),
                      ..._categories.map((cat) => _CategoryChip(
                        label: cat['label'] as String,
                        selected: _selectedCategory == cat['key'],
                        onTap: () => _selectCategory(cat['key'] as String),
                      )),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      body: _error != null && _articles.isEmpty
          ? _ErrorState(error: _error!, onRetry: () => _loadNews(reset: true))
          : _articles.isEmpty && _isLoading
              ? const PlayerListSkeleton(count: 5)
              : _articles.isEmpty
                  ? const AppEmptyState.noNews()
                  : RefreshIndicator(
                      onRefresh: () => _loadNews(reset: true),
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.only(top: 8, bottom: 24),
                        itemCount: _articles.length + (_isLoading || _hasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _articles.length) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final article = _articles[i];
                          return i == 0
                              ? _FeaturedCard(article: article)
                              : _ArticleCard(article: article);
                        },
                      ),
                    ),
    );
  }
}

// ─── Category chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.gold : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Featured card (first article) ───────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final NewsArticle article;
  const _FeaturedCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(context, article.url),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.surface,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (article.imageUrl != null)
                Image.network(
                  article.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const _PlaceholderImage(),
                )
              else
                const _PlaceholderImage(),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 16, right: 16, bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CategoryBadge(category: article.category),
                        const SizedBox(width: 8),
                        Text(article.source, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        const Spacer(),
                        Text(article.timeAgo, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.title,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Regular article card ─────────────────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  final NewsArticle article;
  const _ArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(context, article.url),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                height: 72,
                child: article.imageUrl != null
                    ? Image.network(
                        article.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PlaceholderImage(),
                      )
                    : const _PlaceholderImage(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CategoryBadge(category: article.category),
                      const Spacer(),
                      Text(article.timeAgo, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.source,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category badge ───────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  static const _colors = {
    'Match': AppColors.gold,
    'Transfert': Color(0xFF66BB6A),
    'Blessure': Color(0xFFEF5350),
    'Équipe': Color(0xFFFFA726),
    'Qualif': Color(0xFFAB47BC),
    'Actu': Color(0xFF78909C),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[category] ?? const Color(0xFF78909C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(category, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Placeholder image ────────────────────────────────────────────────────────

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Icon(Icons.sports_soccer, color: AppColors.gold, size: 32),
      ),
    );
  }
}

// ─── Empty / Error states ─────────────────────────────────────────────────────


class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            const Text('Impossible de charger les news', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Vérifie ta connexion internet', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── URL launcher ─────────────────────────────────────────────────────────────

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
    );
  }
}
