import 'package:flutter/services.dart';
import '../data/database/app_database.dart';
import '../data/database/seed_data.dart';

class AppLabelHelper {
  static const MethodChannel _channel =
      MethodChannel('com.example.ai_routine_assistant/usage');

  // In-memory cache pre-seeded with known human app names
  static final Map<String, String> _cache =
      Map<String, String>.from(defaultAppNames);

  /// Synchronous fallback cleaner: turns raw package IDs into human-readable app names.
  /// Examples:
  ///   - 'com.android.chrome' -> 'Chrome'
  ///   - 'com.instagram.android' -> 'Instagram'
  ///   - 'org.telegram.messenger' -> 'Telegram'
  ///   - 'com.zhiliaoapp.musically' -> 'TikTok'
  ///   - 'com.google.android.youtube' -> 'YouTube'
  ///   - 'com.matiks.app' -> 'Matiks'
  static String cleanPackageName(String packageName) {
    final raw = packageName.trim();
    if (raw.isEmpty) return '';

    // 1. Check known seeded apps first
    if (defaultAppNames.containsKey(raw)) {
      return defaultAppNames[raw]!;
    }

    // 2. Filter reverse domain prefixes and noise segments
    const noisePrefixes = {
      'com',
      'org',
      'net',
      'io',
      'co',
      'edu',
      'gov',
      'in',
      'uk',
      'de',
      'fr',
      'jp',
      'cn',
    };
    const noiseWords = {
      'android',
      'app',
      'apps',
      'mobile',
      'client',
      'ui',
      'internal',
      'release',
      'messenger',
      'music',
      'audio',
      'video',
      'news',
      'reader',
      'service',
      'services',
      'lite',
    };

    final parts = raw.split('.').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return raw;

    final filtered = <String>[];
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].toLowerCase();
      if (parts.length > 1 && (i == 0 || i == parts.length - 1) && noisePrefixes.contains(part)) {
        continue;
      }
      if (noiseWords.contains(part)) continue;
      filtered.add(parts[i]);
    }

    final target = filtered.isNotEmpty ? filtered.last : parts.last;

    // Split on underscores, hyphens, or camelCase boundaries
    final spaced = target
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll(RegExp(r'[_+\-]+'), ' ')
        .trim();

    final words = spaced.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return raw;

    return words.map((w) {
      if (w.length <= 1) return w.toUpperCase();
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Resolves an app's display name using the strict fallback hierarchy:
  ///   1. In-memory cache
  ///   2. SQLite DB cache (app_categories / usage_logs)
  ///   3. PackageManager query via MethodChannel
  ///   4. Readable fallback derived from package name
  static Future<String> getAppLabel(String packageName) async {
    final pkg = packageName.trim();
    if (pkg.isEmpty) return '';

    // 1. In-memory cache
    if (_cache.containsKey(pkg)) {
      final cached = _cache[pkg]!;
      if (cached != pkg && cached.isNotEmpty) {
        return cached;
      }
    }

    // 2. DB cache check
    try {
      final db = await AppDatabase.instance.database;

      // Check app_categories table first
      final catRows = await db.query(
        'app_categories',
        columns: ['app_name'],
        where: "package_name = ? AND app_name IS NOT NULL AND app_name != '' AND app_name != package_name",
        whereArgs: [pkg],
        limit: 1,
      );
      if (catRows.isNotEmpty) {
        final name = catRows.first['app_name'] as String?;
        if (name != null && name.isNotEmpty && name != pkg) {
          _cache[pkg] = name;
          return name;
        }
      }

      // Check usage_logs table
      final logRows = await db.query(
        'usage_logs',
        columns: ['app_name'],
        where: "package_name = ? AND app_name IS NOT NULL AND app_name != '' AND app_name != package_name",
        whereArgs: [pkg],
        limit: 1,
      );
      if (logRows.isNotEmpty) {
        final name = logRows.first['app_name'] as String?;
        if (name != null && name.isNotEmpty && name != pkg) {
          _cache[pkg] = name;
          return name;
        }
      }
    } catch (_) {}

    // 3. Android PackageManager query via MethodChannel
    try {
      final label = await _channel.invokeMethod<String>('getAppLabel', {'package': pkg});
      if (label != null && label.isNotEmpty && label != pkg) {
        _cache[pkg] = label;
        _persistLabel(pkg, label);
        return label;
      }
    } catch (_) {}

    // 4. Readable fallback derived from the package name
    final fallback = cleanPackageName(pkg);
    _cache[pkg] = fallback;
    return fallback;
  }

  /// Batch resolves labels for multiple packages without blocking the UI.
  static Future<Map<String, String>> getAppLabels(List<String> packageNames) async {
    final Map<String, String> results = {};
    final List<String> toQueryNative = [];

    for (final pkg in packageNames) {
      if (_cache.containsKey(pkg) && _cache[pkg] != pkg) {
        results[pkg] = _cache[pkg]!;
      } else {
        toQueryNative.add(pkg);
      }
    }

    if (toQueryNative.isEmpty) return results;

    // Check DB cache for remaining
    try {
      final db = await AppDatabase.instance.database;
      final placeholders = List.filled(toQueryNative.length, '?').join(',');
      final rows = await db.rawQuery(
        "SELECT package_name, app_name FROM app_categories "
        "WHERE package_name IN ($placeholders) AND app_name IS NOT NULL AND app_name != '' AND app_name != package_name",
        toQueryNative,
      );
      for (final r in rows) {
        final pkg = r['package_name'] as String?;
        final name = r['app_name'] as String?;
        if (pkg != null && name != null && name != pkg) {
          results[pkg] = name;
          _cache[pkg] = name;
          toQueryNative.remove(pkg);
        }
      }
    } catch (_) {}

    if (toQueryNative.isEmpty) return results;

    // Query PackageManager in batch
    try {
      final nativeMap = await _channel.invokeMethod<Map>(
        'getAppLabels',
        {'packages': toQueryNative},
      );
      if (nativeMap != null) {
        nativeMap.forEach((k, v) {
          final pkg = k.toString();
          final label = v.toString();
          if (label.isNotEmpty && label != pkg) {
            results[pkg] = label;
            _cache[pkg] = label;
            _persistLabel(pkg, label);
          }
        });
      }
    } catch (_) {}

    // Fill remaining with readable fallback
    for (final pkg in packageNames) {
      if (!results.containsKey(pkg)) {
        final fallback = cleanPackageName(pkg);
        results[pkg] = fallback;
        _cache[pkg] = fallback;
      }
    }

    return results;
  }

  /// Persists a resolved label to app_categories and usage_logs in background.
  static void _persistLabel(String packageName, String appName) {
    AppDatabase.instance.database.then((db) async {
      try {
        await db.update(
          'app_categories',
          {'app_name': appName},
          where: "package_name = ? AND (app_name IS NULL OR app_name = '' OR app_name = package_name)",
          whereArgs: [packageName],
        );
        await db.update(
          'usage_logs',
          {'app_name': appName},
          where: "package_name = ? AND (app_name IS NULL OR app_name = '' OR app_name = package_name)",
          whereArgs: [packageName],
        );
      } catch (_) {}
    }).catchError((_) {});
  }

  /// Backfills real names for all apps stored with raw package names.
  static Future<void> backfillAllStoredLabels() async {
    try {
      final db = await AppDatabase.instance.database;

      // 1. Seed defaults into app_categories
      for (final entry in defaultAppNames.entries) {
        _cache[entry.key] = entry.value;
        await db.update(
          'app_categories',
          {'app_name': entry.value},
          where: "package_name = ? AND (app_name IS NULL OR app_name = '' OR app_name = package_name)",
          whereArgs: [entry.key],
        );
        await db.update(
          'usage_logs',
          {'app_name': entry.value},
          where: "package_name = ? AND (app_name IS NULL OR app_name = '' OR app_name = package_name)",
          whereArgs: [entry.key],
        );
      }

      // 2. Find any remaining packages in app_categories with raw names
      final staleCategories = await db.query(
        'app_categories',
        columns: ['package_name'],
        where: "app_name IS NULL OR app_name = '' OR app_name = package_name",
      );
      final pkgs = staleCategories
          .map((r) => r['package_name'] as String?)
          .whereType<String>()
          .toList();

      if (pkgs.isNotEmpty) {
        final labels = await getAppLabels(pkgs);
        for (final entry in labels.entries) {
          await db.update(
            'app_categories',
            {'app_name': entry.value},
            where: 'package_name = ?',
            whereArgs: [entry.key],
          );
        }
      }
    } catch (_) {}
  }
}
