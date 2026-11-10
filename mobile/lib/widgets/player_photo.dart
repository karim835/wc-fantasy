import 'package:flutter/material.dart';
import 'package:wc_fantasy/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/player_image_service.dart';
import 'player_avatar.dart';

/// Async widget that fetches and displays a player's real photo.
/// Falls back to gradient avatar while loading or on error.
class PlayerPhoto extends StatefulWidget {
  final String name;
  final String? photoUrl;
  final String? nationality;
  final double radius;
  final bool showFlag;
  final BoxFit fit;

  const PlayerPhoto({
    super.key,
    required this.name,
    this.photoUrl,
    this.nationality,
    this.radius = 22,
    this.showFlag = false,
    this.fit = BoxFit.cover,
  });

  @override
  State<PlayerPhoto> createState() => _PlayerPhotoState();
}

class _PlayerPhotoState extends State<PlayerPhoto> {
  String? _url;
  bool _loaded = false;
  bool _triedFallback = false;

  @override
  void initState() {
    super.initState();
    _fetchPhoto();
  }

  Future<void> _fetchPhoto() async {
    // Prefer the DB-provided photo URL; if it fails to render, _onDirectFailed
    // will retry via the TheSportsDB search API (which is always current).
    if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty) {
      if (mounted) setState(() { _url = widget.photoUrl; _loaded = true; });
      return;
    }
    final url = await PlayerImageService.getPhoto(widget.name);
    if (mounted) setState(() { _url = url; _loaded = true; });
  }

  void _onDirectFailed() {
    if (_triedFallback || !mounted) return;
    _triedFallback = true;
    PlayerImageService.getPhoto(widget.name).then((url) {
      if (mounted && url != null && url.isNotEmpty && url != _url) {
        setState(() => _url = url);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return PlayerAvatar(
        name: widget.name,
        nationality: widget.nationality,
        radius: widget.radius,
        showFlag: widget.showFlag,
      );
    }

    if (_url == null || _url!.isEmpty) {
      return PlayerAvatar(
        name: widget.name,
        nationality: widget.nationality,
        radius: widget.radius,
        showFlag: widget.showFlag,
      );
    }

    Widget img = ClipOval(
      child: CachedNetworkImage(
        imageUrl: PlayerImageService.proxied(_url!),
        width: widget.radius * 2,
        height: widget.radius * 2,
        fit: widget.fit,
        errorWidget: (_, __, ___) {
          // Fire-and-forget: retry with the search API (won't loop — _triedFallback guards it).
          Future.microtask(_onDirectFailed);
          return PlayerAvatar(
            name: widget.name,
            nationality: widget.nationality,
            radius: widget.radius,
            showFlag: widget.showFlag,
          );
        },
        placeholder: (_, __) => PlayerAvatar(
          name: widget.name,
          nationality: widget.nationality,
          radius: widget.radius,
          showFlag: widget.showFlag,
        ),
      ),
    );

    if (!widget.showFlag || widget.nationality == null) return img;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        img,
        Positioned(
          bottom: -2, right: -4,
          child: Container(
            padding: const EdgeInsets.all(1),
            decoration: const BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Text(
              flagEmoji(widget.nationality),
              style: TextStyle(fontSize: widget.radius * 0.52),
            ),
          ),
        ),
      ],
    );
  }
}

/// Large rectangular player photo for detail screen header.
class PlayerPhotoLarge extends StatefulWidget {
  final String name;
  final String? photoUrl;
  final String? nationality;
  final double height;

  const PlayerPhotoLarge({
    super.key,
    required this.name,
    this.photoUrl,
    this.nationality,
    this.height = 200,
  });

  @override
  State<PlayerPhotoLarge> createState() => _PlayerPhotoLargeState();
}

class _PlayerPhotoLargeState extends State<PlayerPhotoLarge> {
  String? _url;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (widget.photoUrl != null && widget.photoUrl!.isNotEmpty) {
      setState(() { _url = widget.photoUrl; _loaded = true; });
      return;
    }
    final url = await PlayerImageService.getPhoto(widget.name);
    if (mounted) setState(() { _url = url; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return SizedBox(
        height: widget.height,
        child: Center(child: PlayerAvatar(name: widget.name, nationality: widget.nationality, radius: 50, showFlag: true)),
      );
    }

    if (_url == null || _url!.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(child: PlayerAvatar(name: widget.name, nationality: widget.nationality, radius: 60, showFlag: true)),
      );
    }

    return SizedBox(
      height: widget.height,
      child: CachedNetworkImage(
        imageUrl: PlayerImageService.proxied(_url!),
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => Center(
          child: PlayerAvatar(name: widget.name, nationality: widget.nationality, radius: 60, showFlag: true),
        ),
        placeholder: (_, __) => Center(
          child: PlayerAvatar(name: widget.name, nationality: widget.nationality, radius: 60, showFlag: true),
        ),
      ),
    );
  }
}
