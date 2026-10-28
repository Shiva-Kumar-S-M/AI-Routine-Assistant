import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';
import '../database/seed_data.dart';
import '../../domain/models/app_category.dart';
import '../../domain/repositories/category_repository_interface.dart';
import '../../services/app_label_helper.dart';

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

    final packageList = maps.map((m) => m['package_name'] as String).toList();
    // Resolve all app names via the 4-tier hierarchy (in-memory -> DB -> PackageManager -> clean fallback)
    final labelMap = await AppLabelHelper.getAppLabels(packageList);

    return maps.map((map) {
      final pkg = map['package_name'] as String;
      final storedName = map['app_name'] as String?;
      final resolvedName = labelMap[pkg] ??
          (storedName != null && storedName.isNotEmpty && storedName != pkg
              ? storedName
              : AppLabelHelper.cleanPackageName(pkg));

      return AppCategory.fromMap(map, appName: resolvedName);
    }).toList();
  }

  @override
  Future<void> updateCategory(String packageName, String newCategory) async {
    final db = await _dbProvider.database;
    final appName = await AppLabelHelper.getAppLabel(packageName);
    await db.insert(
      'app_categories',
      {
        'package_name': packageName,
        'app_name': appName,
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
    final appName = await AppLabelHelper.getAppLabel(packageName);
    await db.insert(
      'app_categories',
      {
        'package_name': packageName,
        'app_name': appName,
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
    final appName = await AppLabelHelper.getAppLabel(packageName);
    await db.insert(
      'app_categories',
      {
        'package_name': packageName,
        'app_name': appName,
        'category': category,
        'is_custom': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}

