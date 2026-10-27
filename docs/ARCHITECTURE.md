# AI Routine Assistant — Architecture & Technical Specification

## 1. System Overview
**AI Routine Assistant** is a privacy-first, on-device productivity app for Android built with Flutter.
It operates with **zero cloud dependencies** and **zero network calls**.

All telemetry, app usage stats, categorization data, detected routines, and focus session records are stored locally in an embedded SQLite database.

```
+-------------------------------------------------------------------+
|                        Android OS Layer                           |
|                      (UsageStatsManager)                          |
+---------------------------------+---------------------------------+
                                  |
                        MethodChannel (Kotlin)
                                  v
+---------------------------------+---------------------------------+
|                       Usage Collector                            |
|             (Merges <30s sessions, inserts to DB)                |
+---------------------------------+---------------------------------+
                                  |
                                  v
+---------------------------------+---------------------------------+
|                       SQLite Local DB                             |
|    (usage_logs, app_categories, routines, preferences, etc.)     |
+---------------------------------+---------------------------------+
                                  |
                                  v
+---------------------------------+---------------------------------+
|                     Decision Engine Interface                     |
|            (Phase 1: Rule-Based / Phase 2: ML Model)              |
+---------------------------------+---------------------------------+
                                  |
                 +----------------+----------------+
                 |                                 |
                 v                                 v
+---------------------------------+   +-----------------------------+
|      Notification Service       |   |     Dashboard & Focus UI    |
|   (Distraction / Routine Alert) |   |   (FL Charts & Controls)    |
+---------------------------------+   +-----------------------------+
```

---

## 2. Directory Structure
```
lib/
├── main.dart
├── core/
│   ├── constants/
│   └── theme/
├── data/
│   ├── database/
│   │   ├── app_database.dart
│   │   └── seed_data.dart
│   └── repositories/
│       ├── usage_repository.dart
│       ├── category_repository.dart
│       └── focus_repository.dart
├── domain/
│   ├── models/
│   │   ├── usage_log.dart
│   │   ├── app_category.dart
│   │   ├── routine_alert.dart
│   │   └── focus_session.dart
│   └── repositories/
├── ai/
│   ├── routine_engine.dart
│   └── rule_based_engine.dart
├── services/
│   ├── usage_collector_service.dart
│   ├── notification_service.dart
│   └── background_service.dart
└── presentation/
    ├── screens/
    │   ├── permission_screen.dart
    │   ├── dashboard_screen.dart
    │   └── focus_session_screen.dart
    └── widgets/
        ├── category_chart.dart
        ├── trend_chart.dart
        └── alert_tile.dart
```

---

## 3. SQLite Database Schema (Section 10 Spec)

### `usage_logs`
- `id` INTEGER PRIMARY KEY AUTOINCREMENT
- `package_name` TEXT NOT NULL
- `app_name` TEXT NOT NULL
- `start_time` INTEGER NOT NULL (Unix epoch MS)
- `end_time` INTEGER NOT NULL (Unix epoch MS)
- `duration_seconds` INTEGER NOT NULL
- Index: `idx_usage_pkg_time` ON `usage_logs(package_name, start_time)`

### `app_categories`
- `package_name` TEXT PRIMARY KEY
- `category` TEXT NOT NULL ('productive', 'distracting', 'neutral')
- `is_custom` INTEGER DEFAULT 0

### `routines`
- `id` INTEGER PRIMARY KEY AUTOINCREMENT
- `package_name` TEXT NOT NULL
- `time_of_day_minute` INTEGER NOT NULL (0..1439)
- `confidence_score` REAL NOT NULL
- `detected_at` INTEGER NOT NULL

### `notifications_log`
- `id` INTEGER PRIMARY KEY AUTOINCREMENT
- `type` TEXT NOT NULL ('distraction_alert', 'routine_reminder')
- `package_name` TEXT NOT NULL
- `message` TEXT NOT NULL
- `timestamp` INTEGER NOT NULL

### `preferences`
- `key` TEXT PRIMARY KEY
- `value` TEXT NOT NULL

### `focus_sessions`
- `id` INTEGER PRIMARY KEY AUTOINCREMENT
- `start_time` INTEGER NOT NULL
- `end_time` INTEGER NOT NULL
- `duration_minutes` INTEGER NOT NULL
- `is_completed` INTEGER NOT NULL

---

## 4. Decision Engine Contract (Section 11 Spec)

```dart
abstract class RoutineEngine {
  Future<List<RoutineAlert>> evaluateUsagePatterns({
    required List<UsageLog> recentLogs,
    required Map<String, String> appCategories,
  });
}
```

---

## 5. Privacy & Security Constraints
- **Zero Network Calls:** No HTTP, REST, WebSocket, or analytics SDKs allowed.
- **Local Sandbox:** SQLite storage sandboxed strictly inside application private storage.
- **Permission Boundary:** Only Android `PACKAGE_USAGE_STATS` requested via native settings deep-link.
