import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/di/injector.dart';
import '../../core/memories/memories_log.dart';
import '../../core/playback/watch_history.dart';
import '../../core/reading/read_history.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Glad Memories: what you watched and read, how long, and on which days.
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key, this.showBack = true});

  final bool showBack;

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  MemoriesStats? _stats;
  StreamSubscription<dynamic>? _sub;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await MemoriesLog.backfillIfNeeded(
        watched: sl<WatchHistory>().all(),
        read: sl<ReadHistory>().all(),
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() => _stats = MemoriesLog.compute());
    _sub = MemoriesLog.watch()?.listen((_) {
      if (mounted) setState(() => _stats = MemoriesLog.compute());
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _hours(Duration d) {
    final h = d.inMinutes / 60.0;
    if (h >= 100) return h.toStringAsFixed(0);
    return h.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: s == null
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header(context)),
                  if (s.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _empty(),
                    )
                  else ...[
                    SliverToBoxAdapter(child: _hero(s)),
                    SliverToBoxAdapter(child: _tiles(s)),
                    SliverToBoxAdapter(child: _calendar(s)),
                    if (s.recent.isNotEmpty)
                      SliverToBoxAdapter(child: _recent(s)),
                  ],
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.paddingOf(context).bottom + 96,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
    child: Row(
      children: [
        if (widget.showBack)
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            color: AppColors.textPrimary,
          ),
        Expanded(child: Text('Memories', style: AppText.largeTitle)),
      ],
    ),
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 36),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.auto_awesome_rounded, size: 56, color: AppColors.accent),
        const SizedBox(height: 16),
        Text('Nothing here yet', style: AppText.title),
        const SizedBox(height: 8),
        Text(
          'Watch a movie or episode, or read a chapter, and your memories '
          'will start filling in: hours watched, titles finished and a '
          'calendar of every day you showed up.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _hero(MemoriesStats s) {
    final hours = _hours(s.watchTime);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent.withValues(alpha: 0.95),
              Color.lerp(AppColors.accent, const Color(0xFF3B1D8F), 0.65)!,
            ],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIME WATCHED',
                    style: AppText.overline.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        hours,
                        style: AppText.largeTitle.copyWith(
                          fontSize: 56,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'hours',
                        style: AppText.headline.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${s.episodes} episodes finished',
                    style: AppText.body.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                Text(
                  '${s.streak}',
                  style: AppText.title.copyWith(fontSize: 28),
                ),
                Text(
                  'day streak',
                  style: AppText.caption.copyWith(color: Colors.white70),
                ),
                Text(
                  'best ${s.bestStreak}',
                  style: AppText.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tiles(MemoriesStats s) {
    final items = <(IconData, String, int)>[
      (Icons.movie_creation_rounded, 'Movies', s.movies),
      (Icons.tv_rounded, 'Series', s.series),
      (Icons.animation_rounded, 'Anime', s.anime),
      (Icons.menu_book_rounded, 'Manga', s.manga),
      (Icons.auto_stories_rounded, 'Novels', s.novels),
      (Icons.bookmark_added_rounded, 'Chapters read', s.chapters),
    ];
    final tileWidth = (MediaQuery.sizeOf(context).width - 40 - 20) / 3;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final (icon, label, value) in items)
            Container(
              width: tileWidth,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: AppColors.accent),
                  const SizedBox(height: 10),
                  Text('$value', style: AppText.title),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Widget _calendar(MemoriesStats s) {
    final first = DateTime(_month.year, _month.month);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday-first grid
    final now = DateTime.now();
    final atCurrentMonth = _month.year == now.year && _month.month == now.month;

    var monthMs = 0, monthReads = 0, activeDays = 0;
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_month.year, _month.month, d);
      final w = s.dayWatchMs[day] ?? 0;
      final r = s.dayReads[day] ?? 0;
      monthMs += w;
      monthReads += r;
      if (w > 0 || r > 0) activeDays++;
    }

    Widget cell(int dayNumber) {
      final day = DateTime(_month.year, _month.month, dayNumber);
      final w = s.dayWatchMs[day] ?? 0;
      final r = s.dayReads[day] ?? 0;
      // 0 → empty, up to 3h+ → full strength. Reading-only days get a floor.
      final double level = w > 0
          ? (w / (3 * 3600 * 1000)).clamp(0.25, 1.0).toDouble()
          : (r > 0 ? 0.25 : 0.0);
      final isToday =
          atCurrentMonth && now.day == dayNumber;
      return Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: level == 0
              ? AppColors.surface
              : AppColors.accent.withValues(alpha: 0.25 + 0.75 * level),
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(color: AppColors.textPrimary, width: 1.4)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '$dayNumber',
          style: AppText.caption.copyWith(
            color: level > 0.5
                ? Colors.white
                : (level > 0 ? AppColors.textPrimary : AppColors.textTertiary),
            fontWeight: level > 0 ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }

    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++) cell(d),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.settingsCard,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: AppColors.textPrimary,
                ),
                Expanded(
                  child: Text(
                    '${_monthNames[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: AppText.headline,
                  ),
                ),
                IconButton(
                  onPressed: atCurrentMonth
                      ? null
                      : () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: AppColors.textPrimary,
                ),
              ],
            ),
            Row(
              children: [
                for (final l in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(
                        l,
                        style: AppText.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cells,
            ),
            const SizedBox(height: 10),
            Text(
              '${_hours(Duration(milliseconds: monthMs))} h watched · '
              '$monthReads chapters read · $activeDays active days',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recent(MemoriesStats s) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('Recently in your memories', style: AppText.headline),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: s.recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final t = s.recent[i];
              final reading =
                  t.kind == MemoryKind.manga || t.kind == MemoryKind.novel;
              return SizedBox(
                width: 118,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: t.cover == null || t.cover!.isEmpty
                              ? ColoredBox(
                                  color: AppColors.surface2,
                                  child: Icon(
                                    Icons.movie_rounded,
                                    color: AppColors.textTertiary,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: t.cover!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) =>
                                      ColoredBox(color: AppColors.surface2),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      reading
                          ? '${t.units} chapters'
                          : (t.kind == MemoryKind.movie
                                ? (t.done ? 'Watched' : 'Started')
                                : '${t.units} episodes'),
                      style: AppText.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
