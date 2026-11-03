import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

Widget _poster(MediaItem item, {BoxFit fit = BoxFit.cover}) {
  final url = item.cover;
  if (url == null || url.isEmpty) {
    return ColoredBox(
      color: AppColors.surface2,
      child: Center(
        child: Icon(Icons.movie_rounded, color: AppColors.textTertiary),
      ),
    );
  }
  return CachedNetworkImage(
    imageUrl: url,
    httpHeaders: item.coverHeaders,
    fit: fit,
    placeholder: (_, _) => ColoredBox(color: AppColors.surface2),
    errorWidget: (_, _, _) => ColoredBox(color: AppColors.surface2),
  );
}

class _TitleScrim extends StatelessWidget {
  const _TitleScrim({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xE6000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.headline.copyWith(fontSize: 19),
          ),
          if (item.score != null || item.genres.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (item.score != null)
                  '★ ${(item.score! / 10).toStringAsFixed(1)}',
                ...item.genres.take(2),
              ].join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

/// A coverflow-style carousel: the centred poster is large, the ones either
/// side recede, tilt and fade. Swipe or tap to open.
class GladCoverflow extends StatefulWidget {
  const GladCoverflow({super.key, required this.items, required this.onOpen});

  final List<MediaItem> items;
  final ValueChanged<MediaItem> onOpen;

  @override
  State<GladCoverflow> createState() => _GladCoverflowState();
}

class _GladCoverflowState extends State<GladCoverflow> {
  late final PageController _c = PageController(viewportFraction: 0.62);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double get _page {
    if (_c.hasClients && _c.position.haveDimensions) {
      return _c.page ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: PageView.builder(
        controller: _c,
        clipBehavior: Clip.none,
        itemCount: widget.items.length,
        itemBuilder: (context, i) {
          final item = widget.items[i];
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final double dist = (_page - i).clamp(-1.0, 1.0).toDouble();
              final scale = 1 - dist.abs() * 0.16;
              return Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(-dist * 0.45)
                    ..scale(scale, scale),
                  child: Opacity(
                    opacity: 1 - dist.abs() * 0.4,
                    child: GestureDetector(
                      onTap: () => widget.onOpen(item),
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _poster(item),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: _TitleScrim(item: item),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// A Tinder-style stack: drag the top card right to save it to My List, left
/// to skip it, or tap it to open the title.
class GladCardStack extends StatefulWidget {
  const GladCardStack({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onSave,
  });

  final List<MediaItem> items;
  final ValueChanged<MediaItem> onOpen;
  final ValueChanged<MediaItem> onSave;

  @override
  State<GladCardStack> createState() => _GladCardStackState();
}

class _GladCardStackState extends State<GladCardStack>
    with SingleTickerProviderStateMixin {
  static const double _threshold = 110;

  int _index = 0;
  Offset _drag = Offset.zero;
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  Animation<Offset>? _flyAnim;

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  bool get _done => _index >= widget.items.length;

  void _release({double velocityX = 0}) {
    if (_done || _fly.isAnimating) return;
    final goRight = _drag.dx > _threshold || velocityX > 900;
    final goLeft = _drag.dx < -_threshold || velocityX < -900;
    if (!goRight && !goLeft) {
      setState(() => _drag = Offset.zero);
      return;
    }
    final item = widget.items[_index];
    final target = Offset(goRight ? 700 : -700, _drag.dy);
    _flyAnim = Tween<Offset>(
      begin: _drag,
      end: target,
    ).animate(CurvedAnimation(parent: _fly, curve: Curves.easeOut));
    _flyAnim!.addListener(() {
      if (mounted) setState(() => _drag = _flyAnim!.value);
    });
    _fly.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      if (goRight) widget.onSave(item);
      setState(() {
        _index++;
        _drag = Offset.zero;
      });
    });
  }

  Widget _card(MediaItem item, {required bool top}) {
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _poster(item),
            Align(
              alignment: Alignment.bottomCenter,
              child: _TitleScrim(item: item),
            ),
            if (top) ...[
              _stamp('SAVE', Colors.greenAccent, _drag.dx / _threshold,
                  Alignment.topLeft),
              _stamp('SKIP', Colors.redAccent, -_drag.dx / _threshold,
                  Alignment.topRight),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stamp(String text, Color color, double amount, Alignment where) {
    final double o = amount.clamp(0.0, 1.0).toDouble();
    if (o <= 0) return const SizedBox.shrink();
    return Align(
      alignment: where,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Opacity(
          opacity: o,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              text,
              style: AppText.title.copyWith(color: color, letterSpacing: 2),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return SizedBox(
        height: 220,
        child: Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _index = 0),
            icon: Icon(Icons.replay_rounded, color: AppColors.accent),
            label: Text(
              'That\'s the stack. Go again',
              style: AppText.body.copyWith(color: AppColors.accent),
            ),
          ),
        ),
      );
    }
    final remaining = widget.items.length - _index;
    final depth = math.min(3, remaining);
    return SizedBox(
      height: 420,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back cards first, so the top card paints last.
          for (var d = depth - 1; d >= 1; d--)
            Transform.translate(
              offset: Offset(0, 14.0 * d),
              child: Transform.scale(
                scale: 1 - 0.06 * d,
                child: FractionallySizedBox(
                  widthFactor: 0.72,
                  child: Opacity(
                    opacity: 1 - 0.25 * d,
                    child: _card(widget.items[_index + d], top: false),
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: () => widget.onOpen(widget.items[_index]),
            onPanUpdate: (d) {
              if (_fly.isAnimating) return;
              setState(() => _drag += d.delta);
            },
            onPanEnd: (d) => _release(velocityX: d.velocity.pixelsPerSecond.dx),
            child: Transform.translate(
              offset: _drag,
              child: Transform.rotate(
                angle: _drag.dx / 900,
                child: FractionallySizedBox(
                  widthFactor: 0.72,
                  child: _card(widget.items[_index], top: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Home "Spotlight": a coverflow of the first rows plus a swipe-to-save stack.
class GladSpotlight extends StatelessWidget {
  const GladSpotlight({
    super.key,
    required this.featured,
    required this.discover,
    required this.onOpen,
    required this.onSave,
    this.onMemories,
  });

  final List<MediaItem> featured;
  final List<MediaItem> discover;
  final ValueChanged<MediaItem> onOpen;
  final ValueChanged<MediaItem> onSave;
  final VoidCallback? onMemories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onMemories != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: GestureDetector(
              onTap: onMemories,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.9),
                      Color.lerp(AppColors.accent, const Color(0xFF3B1D8F), 0.65)!,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Memories', style: AppText.headline),
                          Text(
                            'Hours watched, movies, series, reading and your calendar',
                            style: AppText.caption.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (featured.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Text('Spotlight', style: AppText.title),
          ),
          GladCoverflow(items: featured, onOpen: onOpen),
        ],
        if (discover.length >= 3) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 4),
            child: Row(
              children: [
                Expanded(child: Text('Swipe to discover', style: AppText.title)),
                Icon(Icons.swipe_rounded, color: AppColors.textTertiary),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              'Drag right to save to My List, left to skip.',
              style: AppText.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
          GladCardStack(items: discover, onOpen: onOpen, onSave: onSave),
        ],
      ],
    );
  }
}
