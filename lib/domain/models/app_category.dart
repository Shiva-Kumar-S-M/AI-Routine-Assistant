class AppCategory {
  final String packageName;
  final String appName;
  final String category; // 'productive', 'distracting', 'neutral'
  final bool isCustom;

  AppCategory({
    required this.packageName,
    String? appName,
    required this.category,
    this.isCustom = false,
  }) : appName = (appName != null && appName.isNotEmpty) ? appName : packageName;

  Map<String, dynamic> toMap() {
    return {
      'package_name': packageName,
      'category': category,
      'is_custom': isCustom ? 1 : 0,
    };
  }

  factory AppCategory.fromMap(Map<String, dynamic> map, {String? appName}) {
    final pkg = map['package_name'] as String;
    return AppCategory(
      packageName: pkg,
      appName: appName ?? pkg,
      category: map['category'] as String,
      isCustom: (map['is_custom'] as int?) == 1,
    );
  }
}
