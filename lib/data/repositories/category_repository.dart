import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/seed_data.dart';
import '../../domain/models/app_category.dart';
import '../../domain/repositories/category_repository_interface.dart';

class CategoryRepository implements CategoryRepositoryInterface {
  final AppDatabase _dbProvider = AppDatabase.instance;

  @override
  Future<Map<String, String>> getCategoriesMap() async {
    final db = await _dbProvider.database;
    final maps = await db.query('app_categories');
    final Map<String, String> result = {};
    for (final row in maps) {
      result[row['package_name'] as String] = row['category'] as String;
    }
    return result;
  }

  @override
  Future<List<AppCategory>> getAllCategories() async {
    final db = await _dbProvider.database;
    final maps = await db.query('app_categories', orderBy: 'package_name ASC');

    // Pick the best resolved app name for each package from usage_logs.
    // Use two passes:
    //   1. Prefer any row where app_name != package_name (i.e. a resolved label).
    //   2. Fall back to any non-empty app_name if no resolved label exists.
    // This ensures 'Instagram' always wins over 'com.instagram.android'.
    final resolvedRows = await db.rawQuery(
      "SELECT package_name, app_name "
      "FROM usage_logs "
      "WHERE app_name != package_name AND app_name != '' "
      "GROUP BY package_name",
    );
    final Map<String, String> pkgToNameMap = {};
    for (final row in resolvedRows) {
      final pkg = row['package_name'] as String?;
      final name = row['app_name'] as String?;
      if (pkg != null && name != null && name.isNotEmpty) {
        pkgToNameMap[pkg] = name;
      }
    }

    // For packages with no resolved label yet, fall back to any non-empty name.
    final fallbackRows = await db.rawQuery(
      "SELECT package_name, app_name "
      "FROM usage_logs "
      "WHERE app_name != '' "
      "GROUP BY package_name",
    );
    for (final row in fallbackRows) {
      final pkg = row['package_name'] as String?;
      final name = row['app_name'] as String?;
      if (pkg != null && name != null && name.isNotEmpty && !pkgToNameMap.containsKey(pkg)) {
        pkgToNameMap[pkg] = name;
      }
    }

    return maps.map((map) {
      final pkg = map['package_name'] as String;
      final appName = pkgToNameMap[pkg];
      return AppCategory.fromMap(map, appName: appName);
    }).toList();
  }

  @override
  Future<void> updateCategory(String packageName, String newCategory) async {
    final db = await _dbProvider.database;
    await db.insert(
      'app_categories',
      {
        'package_name': packageName,
        'category': newCategory,
        'is_custom': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> resetToDefault(String packageName) async {
    final db = await _dbProvider.database;
    final defaultCategory = defaultAppCategories[packageName] ?? 'neutral';
    await db.insert(
      'app_categories',
      {
        'package_name': packageName,
        'category': defaultCategory,
        'is_custom': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserts an auto-detected category only if no row exists for this package.
  /// Uses ConflictAlgorithm.ignore so manual overrides and seed data are preserved.
  Future<void> insertAutoCategoryIfAbsent(String packageName, String category) async {
    final db = await _dbProvider.database;
    await db.insert(
      'app_categories',
      {
        'package_name': packageName,
        'category': category,
        'is_custom': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}

