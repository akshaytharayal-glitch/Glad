import 'package:hive/hive.dart';

import '../models/provider_info.dart';
import '../playback/watch_history.dart';
import '../profiles/profile_scope.dart';
import '../reading/read_history.dart';
import '../zmode/zmode_ids.dart';

/// What a title is, for the Memories stats.
enum MemoryKind { movie, series, anime, manga, novel }

/// One title in the user's Memories.
class MemoryTitle {
  const MemoryTitle({
    required this.title,
    required this.kind,
    required this.cover,
    required this.done,
    required this.units,
    required this.watchMs,
    required this.lastMs,
  });

  final String title;
  final MemoryKind kind;
  final String? cover;

  /// A movie / series / book the user got to the end of.
  final bool done;

  /// Episodes finished (watching) or chapters read (reading).
  final int units;
  final int watchMs;
  final int lastMs;
}

/// The numbers behind the Memories screen.
class MemoriesStats {
  const MemoriesStats({
    required this.movies,
    required this.series,
    required this.anime,
    required this.manga,
    required this.novels,
    required this.episodes,
    required this.chapters,
    required this.watchTime,
    required this.dayWatchMs,
    required this.dayReads,
    required this.recent,
    required this.streak,
    required this.bestStreak,
  });

  /// Finished movies.
  final int movies;

  /// Series / anime the user has started.
  final int series;
  final int anime;
  final int manga;
  final int novels;
  final int episodes;
  final int chapters;
  final Duration watchTime;

  /// Watch time per calendar day (local midnight → milliseconds).
  final Map<DateTime, int> dayWatchMs;

  /// Chapters read per calendar day.
  final Map<DateTime, int> dayReads;
  final List<MemoryTitle> recent;
  final int streak;
  final int bestStreak;

  bool get isEmpty =>
      movies + series + anime + manga + novels == 0 && watchTime == Duration.zero;
}

/// Local, per-profile record of what the user watched and read, and when.
///
/// [WatchHistory] only keeps the LAST episode's position for each show, so it
/// cannot say how many hours were watched in total or on which days. This log
/// is fed from the same save() calls and adds that: watch time per day, the
/// episodes finished per title and the chapters read per title.
///
/// Everything stays on the device. Failures are swallowed on purpose — a stats
/// log must never be able to break playback or reading.
class MemoriesLog {
  MemoriesLog._();

  static const String boxName = 'glad_memories';

  /// Resolves the active viewer profile. Set once at startup by the injector.
  static String Function()? profileResolver;

  static Box? _box;

  static String get _profile => profileResolver?.call() ?? kDefaultProfileId;

  static Future<void> init() async {
    try {
      _box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
    } catch (_) {
      _box = null;
    }
  }

  // ── Keys ──────────────────────────────────────────────────────────────────

  static String _dayKey(String profile, DateTime d) =>
      'd|$profile|${d.year}-${d.month}-${d.day}';

  static String _titleKey(String profile, String kind, String id) =>
      't|$profile|$kind|$id';

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  // ── Recording ─────────────────────────────────────────────────────────────

  /// Classify a watched title. The metadata (zm://) URL knows exactly; for
  /// source titles fall back on the MAL id (anime) and on whether it has
  /// episode numbers at all (a movie has none).
  static MemoryKind kindOfWatch(HistoryEntry e) {
    final z = ZmodeIds.parseShow(e.showUrl);
    if (z != null) {
      switch (z.kind) {
        case ZKind.movie:
          return MemoryKind.movie;
        case ZKind.anime:
          return MemoryKind.anime;
        case ZKind.tv:
        case ZKind.manga:
        case ZKind.novel:
          return MemoryKind.series;
      }
    }
    if (e.malId != null) return MemoryKind.anime;
    return e.episodeNumber == null ? MemoryKind.movie : MemoryKind.series;
  }

  /// Called from [WatchHistory.save] on every progress tick.
  static Future<void> recordWatch(String profile, HistoryEntry e) async {
    final box = _box;
    if (box == null) return;
    try {
      final kind = kindOfWatch(e);
      final now = DateTime.fromMillisecondsSinceEpoch(e.updatedAt);

      // Time actually played = the forward movement of the position within
      // the same episode. A seek or a new episode contributes nothing, and a
      // gap above 30 s (a seek, or a flush after a long pause) is ignored.
      final progressKey = 'p|$profile|${e.sourceId}|${e.showId}';
      final prev = box.get(progressKey);
      var deltaMs = 0;
      if (prev is Map && prev['ep'] == e.episodeId) {
        final p = (prev['pos'] as num?)?.toInt() ?? 0;
        final d = e.position.inMilliseconds - p;
        if (d > 0 && d <= 30000) deltaMs = d;
      }
      await box.put(progressKey, {
        'ep': e.episodeId,
        'pos': e.position.inMilliseconds,
      });

      final tKey = _titleKey(profile, kind.name, '${e.sourceId}|${e.showId}');
      final t = Map<String, dynamic>.from((box.get(tKey) as Map?) ?? const {});
      final eps = List<String>.from((t['eps'] as List?) ?? const []);
      var newlyFinished = false;
      if (e.finished && !eps.contains(e.episodeId)) {
        eps.add(e.episodeId);
        newlyFinished = true;
      }
      t['title'] = e.showTitle;
      t['kind'] = kind.name;
      t['cover'] = e.cover ?? t['cover'];
      t['eps'] = eps;
      t['ms'] = ((t['ms'] as num?)?.toInt() ?? 0) + deltaMs;
      t['last'] = e.updatedAt;
      if (kind == MemoryKind.movie) t['done'] = (t['done'] == true) || e.finished;
      await box.put(tKey, t);

      if (deltaMs > 0) {
        final dKey = _dayKey(profile, now);
        final day = Map<String, dynamic>.from(
          (box.get(dKey) as Map?) ?? const {},
        );
        day['w'] = ((day['w'] as num?)?.toInt() ?? 0) + deltaMs;
        await box.put(dKey, day);
      }
      if (newlyFinished) {
        final dKey = _dayKey(profile, now);
        final day = Map<String, dynamic>.from(
          (box.get(dKey) as Map?) ?? const {},
        );
        day['f'] = ((day['f'] as num?)?.toInt() ?? 0) + 1;
        await box.put(dKey, day);
      }
    } catch (_) {}
  }

  /// Called from [ReadHistory.save] whenever the reading position moves.
  static Future<void> recordRead(String profile, ReadEntry e) async {
    final box = _box;
    if (box == null) return;
    try {
      final kind = e.type == ProviderType.manga
          ? MemoryKind.manga
          : MemoryKind.novel;
      final now = DateTime.fromMillisecondsSinceEpoch(e.updatedMs);
      final tKey = _titleKey(profile, kind.name, '${e.sourceId}|${e.showId}');
      final t = Map<String, dynamic>.from((box.get(tKey) as Map?) ?? const {});
      final chapters = List<String>.from((t['eps'] as List?) ?? const []);
      var isNewChapter = false;
      if (!chapters.contains(e.chapterId)) {
        chapters.add(e.chapterId);
        isNewChapter = true;
      }
      t['title'] = e.title;
      t['kind'] = kind.name;
      t['cover'] = e.cover ?? t['cover'];
      t['eps'] = chapters;
      t['last'] = e.updatedMs;
      t['done'] = (t['done'] == true) || e.finished;
      await box.put(tKey, t);

      if (isNewChapter) {
        final dKey = _dayKey(profile, now);
        final day = Map<String, dynamic>.from(
          (box.get(dKey) as Map?) ?? const {},
        );
        day['r'] = ((day['r'] as num?)?.toInt() ?? 0) + 1;
        await box.put(dKey, day);
      }
    } catch (_) {}
  }

  // ── Back-fill ─────────────────────────────────────────────────────────────

  /// One-time import of what the existing history already knows, so Memories is
  /// not empty on day one. Time is estimated from the saved positions — the
  /// per-day record only starts being exact from here on.
  static Future<void> backfillIfNeeded({
    required List<HistoryEntry> watched,
    required List<ReadEntry> read,
  }) async {
    final box = _box;
    if (box == null) return;
    final profile = _profile;
    final flag = 'seeded|$profile';
    if (box.get(flag) == true) return;
    try {
      for (final e in watched) {
        final kind = kindOfWatch(e);
        final tKey = _titleKey(profile, kind.name, '${e.sourceId}|${e.showId}');
        if (box.containsKey(tKey)) continue;
        final ms = e.finished
            ? e.duration.inMilliseconds
            : e.position.inMilliseconds;
        await box.put(tKey, {
          'title': e.showTitle,
          'kind': kind.name,
          'cover': e.cover,
          'eps': e.finished ? [e.episodeId] : <String>[],
          'ms': ms,
          'last': e.updatedAt,
          'done': kind == MemoryKind.movie && e.finished,
        });
        final dKey = _dayKey(
          profile,
          DateTime.fromMillisecondsSinceEpoch(e.updatedAt),
        );
        final day = Map<String, dynamic>.from(
          (box.get(dKey) as Map?) ?? const {},
        );
        day['w'] = ((day['w'] as num?)?.toInt() ?? 0) + ms;
        if (e.finished) day['f'] = ((day['f'] as num?)?.toInt() ?? 0) + 1;
        await box.put(dKey, day);
      }
      for (final e in read) {
        final kind = e.type == ProviderType.manga
            ? MemoryKind.manga
            : MemoryKind.novel;
        final tKey = _titleKey(profile, kind.name, '${e.sourceId}|${e.showId}');
        if (box.containsKey(tKey)) continue;
        await box.put(tKey, {
          'title': e.title,
          'kind': kind.name,
          'cover': e.cover,
          'eps': <String>[e.chapterId],
          'ms': 0,
          'last': e.updatedMs,
          'done': e.finished,
        });
        final dKey = _dayKey(
          profile,
          DateTime.fromMillisecondsSinceEpoch(e.updatedMs),
        );
        final day = Map<String, dynamic>.from(
          (box.get(dKey) as Map?) ?? const {},
        );
        day['r'] = ((day['r'] as num?)?.toInt() ?? 0) + 1;
        await box.put(dKey, day);
      }
      await box.put(flag, true);
    } catch (_) {}
  }

  // ── Reading the stats ─────────────────────────────────────────────────────

  static MemoryKind _kindFromName(String? n) {
    for (final k in MemoryKind.values) {
      if (k.name == n) return k;
    }
    return MemoryKind.series;
  }

  static MemoriesStats compute() {
    final box = _box;
    final profile = _profile;
    final titles = <MemoryTitle>[];
    final dayWatch = <DateTime, int>{};
    final dayReads = <DateTime, int>{};

    if (box != null) {
      final tPrefix = 't|$profile|';
      final dPrefix = 'd|$profile|';
      for (final key in box.keys) {
        if (key is! String) continue;
        final v = box.get(key);
        if (v is! Map) continue;
        if (key.startsWith(tPrefix)) {
          titles.add(
            MemoryTitle(
              title: '${v['title'] ?? ''}',
              kind: _kindFromName(v['kind'] as String?),
              cover: v['cover'] as String?,
              done: v['done'] == true,
              units: ((v['eps'] as List?) ?? const []).length,
              watchMs: (v['ms'] as num?)?.toInt() ?? 0,
              lastMs: (v['last'] as num?)?.toInt() ?? 0,
            ),
          );
        } else if (key.startsWith(dPrefix)) {
          final parts = key.substring(dPrefix.length).split('-');
          if (parts.length != 3) continue;
          final y = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          final d = int.tryParse(parts[2]);
          if (y == null || m == null || d == null) continue;
          final day = DateTime(y, m, d);
          final w = (v['w'] as num?)?.toInt() ?? 0;
          final r = (v['r'] as num?)?.toInt() ?? 0;
          if (w > 0) dayWatch[day] = w;
          if (r > 0) dayReads[day] = r;
        }
      }
    }

    var movies = 0, series = 0, anime = 0, manga = 0, novels = 0;
    var episodes = 0, chapters = 0, totalMs = 0;
    for (final t in titles) {
      switch (t.kind) {
        case MemoryKind.movie:
          if (t.done) movies++;
        case MemoryKind.series:
          series++;
          episodes += t.units;
        case MemoryKind.anime:
          anime++;
          episodes += t.units;
        case MemoryKind.manga:
          manga++;
          chapters += t.units;
        case MemoryKind.novel:
          novels++;
          chapters += t.units;
      }
      totalMs += t.watchMs;
    }

    final active = <DateTime>{...dayWatch.keys, ...dayReads.keys};
    final today = _midnight(DateTime.now());
    var streak = 0;
    var cursor = active.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    while (active.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var best = 0, run = 0;
    final sorted = active.toList()..sort();
    DateTime? prev;
    for (final d in sorted) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }

    titles.sort((a, b) => b.lastMs.compareTo(a.lastMs));
    return MemoriesStats(
      movies: movies,
      series: series,
      anime: anime,
      manga: manga,
      novels: novels,
      episodes: episodes,
      chapters: chapters,
      watchTime: Duration(milliseconds: totalMs),
      dayWatchMs: dayWatch,
      dayReads: dayReads,
      recent: titles.take(12).toList(),
      streak: streak,
      bestStreak: best,
    );
  }

  /// Live updates for the screen.
  static Stream<BoxEvent>? watch() => _box?.watch();
}
