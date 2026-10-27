import '../models/app_category.dart';

abstract class CategoryRepositoryInterface {
  Future<Map<String, String>> getCategoriesMap();
  Future<List<AppCategory>> getAllCategories();
  Future<void> updateCategory(String packageName, String newCategory);
  /// Reverts a custom override back to the seed default.
  Future<void> resetToDefault(String packageName);
}
