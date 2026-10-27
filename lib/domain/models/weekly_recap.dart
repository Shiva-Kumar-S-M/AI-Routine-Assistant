class WeeklyRecap {
  final int winsCount;
  final int xpGained;
  final int timeReclaimedMinutes;
  final String bestDayName;
  final String smartTip;
  final List<String> topBadgesUnlocked;

  const WeeklyRecap({
    required this.winsCount,
    required this.xpGained,
    required this.timeReclaimedMinutes,
    required this.bestDayName,
    required this.smartTip,
    this.topBadgesUnlocked = const [],
  });

  String get formattedTimeReclaimed {
    if (timeReclaimedMinutes < 60) {
      return '${timeReclaimedMinutes}m';
    }
    return '${timeReclaimedMinutes ~/ 60}h ${timeReclaimedMinutes % 60}m';
  }
}

