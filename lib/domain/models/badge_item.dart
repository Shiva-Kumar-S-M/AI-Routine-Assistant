class BadgeItem {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final String category;
  final int maxProgress;
  final int currentProgress;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const BadgeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.category,
    required this.maxProgress,
    this.currentProgress = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  double get progressFraction {
    if (maxProgress <= 0) return 1.0;
    return (currentProgress / maxProgress).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'icon_name': iconName,
      'category': category,
      'max_progress': maxProgress,
      'current_progress': currentProgress,
      'is_unlocked': isUnlocked ? 1 : 0,
      'unlocked_at': unlockedAt?.millisecondsSinceEpoch,
    };
  }

  factory BadgeItem.fromMap(Map<String, dynamic> map) {
    return BadgeItem(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      iconName: map['icon_name'] as String? ?? 'shield',
      category: map['category'] as String? ?? 'general',
      maxProgress: (map['max_progress'] as num?)?.toInt() ?? 1,
      currentProgress: (map['current_progress'] as num?)?.toInt() ?? 0,
      isUnlocked: (map['is_unlocked'] as num?)?.toInt() == 1,
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['unlocked_at'] as num).toInt())
          : null,
    );
  }

  BadgeItem copyWith({
    int? currentProgress,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return BadgeItem(
      id: id,
      title: title,
      description: description,
      iconName: iconName,
      category: category,
      maxProgress: maxProgress,
      currentProgress: currentProgress ?? this.currentProgress,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}
