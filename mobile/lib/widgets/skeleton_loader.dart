import 'package:flutter/material.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loaders réutilisables — Shimmer (déjà installé, gratuit)
/// Remplacent les CircularProgressIndicator sur tous les écrans.

// ─── Boîte de base ────────────────────────────────────────────────────────────

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─── Wrapper Shimmer ──────────────────────────────────────────────────────────

class _Shimmer extends StatelessWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceElevated,
      child: child,
    );
  }
}

// ─── Skeleton Card Joueur ─────────────────────────────────────────────────────

class PlayerCardSkeleton extends StatelessWidget {
  const PlayerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar
            const _SkeletonBox(width: 46, height: 46, radius: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: MediaQuery.of(context).size.width * 0.35, height: 14),
                  const SizedBox(height: 6),
                  _SkeletonBox(width: MediaQuery.of(context).size.width * 0.22, height: 11),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                _SkeletonBox(width: 50, height: 14),
                SizedBox(height: 6),
                _SkeletonBox(width: 36, height: 11),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerListSkeleton extends StatelessWidget {
  final int count;
  const PlayerListSkeleton({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(count, (_) => const PlayerCardSkeleton()),
      );
}

// ─── Skeleton Home Screen ─────────────────────────────────────────────────────

class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return _Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header profil
            Row(
              children: [
                const _SkeletonBox(width: 52, height: 52, radius: 26),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: w * 0.3, height: 16),
                    const SizedBox(height: 6),
                    _SkeletonBox(width: w * 0.2, height: 12),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats cards
            Row(
              children: List.generate(3, (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 20),

            // Section title
            _SkeletonBox(width: w * 0.35, height: 16),
            const SizedBox(height: 12),

            // Top players
            ...List.generate(5, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const _SkeletonBox(width: 38, height: 38, radius: 19),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _SkeletonBox(width: w * 0.28, height: 13),
                    const SizedBox(height: 4),
                    _SkeletonBox(width: w * 0.18, height: 10),
                  ])),
                  const _SkeletonBox(width: 44, height: 13),
                ],
              ),
            )),
            const SizedBox(height: 20),

            // News cards
            _SkeletonBox(width: w * 0.25, height: 16),
            const SizedBox(height: 12),
            ...List.generate(3, (_) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton League Card ─────────────────────────────────────────────────────

class LeagueCardSkeleton extends StatelessWidget {
  const LeagueCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return _Shimmer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                const _SkeletonBox(width: 42, height: 42, radius: 21),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _SkeletonBox(width: w * 0.4, height: 15),
                  const SizedBox(height: 6),
                  _SkeletonBox(width: w * 0.25, height: 11),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              const _SkeletonBox(width: 70, height: 26, radius: 13),
              const SizedBox(width: 8),
              const _SkeletonBox(width: 80, height: 26, radius: 13),
            ]),
          ],
        ),
      ),
    );
  }
}

class LeagueListSkeleton extends StatelessWidget {
  final int count;
  const LeagueListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(count, (_) => const LeagueCardSkeleton()),
      );
}

// ─── Skeleton Gameweek ────────────────────────────────────────────────────────

class GameweekSkeleton extends StatelessWidget {
  const GameweekSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return _Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GW header card
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 20),
            _SkeletonBox(width: w * 0.3, height: 15),
            const SizedBox(height: 12),
            ...List.generate(6, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton Profile ─────────────────────────────────────────────────────────

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return _Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar + name
            const _SkeletonBox(width: 80, height: 80, radius: 40),
            const SizedBox(height: 12),
            _SkeletonBox(width: w * 0.35, height: 18),
            const SizedBox(height: 6),
            _SkeletonBox(width: w * 0.25, height: 13),
            const SizedBox(height: 20),

            // Stats grid
            Row(children: List.generate(3, (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                height: 70,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              ),
            ))),
            const SizedBox(height: 20),

            // Chart placeholder
            Container(
              height: 200,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            ),
            const SizedBox(height: 20),

            // Achievements
            _SkeletonBox(width: w * 0.3, height: 15),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
              children: List.generate(6, (_) => Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
