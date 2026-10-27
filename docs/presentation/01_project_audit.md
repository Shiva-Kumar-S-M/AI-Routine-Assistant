# 01 – Project Audit
**AI Routine Assistant** | Presentation Preparation Document

---

## Verified Facts (confirmed directly in code)

- App package: `com.example.ai_routine_assistant` (AndroidManifest.xml + build.gradle.kts)
- Flutter SDK constraint: `>=3.0.0 <4.0.0` (pubspec.yaml)
- Min Android SDK: **26** (Android 8.0); Target / Compile SDK: **36** (build.gradle.kts)
- 7 SQLite tables confirmed in `app_database.dart`
- 2 Kotlin files: `MainActivity.kt` (472 lines), `UsageMonitorService.kt` (352 lines)
- Native polling interval: **2 seconds** (`POLL_INTERVAL_MS = 2000L`, UsageMonitorService.kt:50)
- Dart background-service tick: **15 minutes** (`Timer.periodic`, background_service.dart:71)
- **No `INTERNET` permission** in production `AndroidManifest.xml`; only in `debug/` + `profile/` (Flutter tooling)
- AI: `DecisionTreeEngine` — scikit-learn depth-6 tree compiled to Dart if/else (decision_tree_engine.dart:118)
- Model serialised in `ml_training/decision_tree_model.json` (149 lines, 11 nodes + leaves)
- Training: `train_decision_tree.py` — 2,500-sample **synthetic** dataset, 80/20 split

---

## 1. Folder Structure

```
Major project/
├── android/
│   ├── app/
│   │   ├── build.gradle.kts          Gradle config (minSdk 26, targetSdk 36, Kotlin JVM 17, desugaring ON)
│   │   └── src/
│   │       ├── main/
│   │       │   ├── AndroidManifest.xml   Production permissions (NO INTERNET)
│   │       │   └── kotlin/.../
│   │       │       ├── MainActivity.kt        MethodChannel handler, overlay UI (472 lines)
│   │       │       └── UsageMonitorService.kt Native 2-s polling service (352 lines)
│   │       ├── debug/AndroidManifest.xml  INTERNET for hot-reload only
│   │       └── profile/AndroidManifest.xml INTERNET for profiling only
│
├── lib/
│   ├── main.dart                   Entry point: theme, notification init, background service boot
│   ├── ai/
│   │   ├── routine_engine.dart     Abstract RoutineEngine interface (2 implementations)
│   │   ├── decision_tree_engine.dart  PRIMARY AI: depth-6 if/else tree (170 lines)
│   │   └── rule_based_engine.dart  Legacy threshold engine (NOT wired to background service)
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart     Brand colour palette
│   │   │   └── score_weights.dart  distraction 0.45, focus 0.35, routine 0.20; thresholds 40/60/80
│   │   └── theme/app_theme.dart    Material3 light theme
│   ├── data/
│   │   ├── database/
│   │   │   ├── app_database.dart   SQLite singleton — 7 CREATE TABLE statements + seed batch
│   │   │   └── seed_data.dart      22 hardcoded package→category entries
│   │   └── repositories/
│   │       ├── usage_repository.dart       CRUD + analytics (trend, top apps, streak, limits)
│   │       ├── category_repository.dart    CRUD + auto-classify + seed reset
│   │       ├── focus_repository.dart       CRUD focus sessions; today's minutes
│   │       └── preferences_repository.dart KV wrapper: limits, quiet hours, flags
│   ├── domain/
│   │   ├── models/
│   │   │   ├── usage_log.dart       package, appName, start, end, duration, category
│   │   │   ├── routine_alert.dart   AlertType enum + JSON trigger conditions
│   │   │   ├── app_category.dart    package, category, isCustom flag
│   │   │   ├── focus_session.dart   start, end, durationMinutes, isCompleted
│   │   │   └── emotional_log.dart   Scaffold model (no active UI flow)
│   │   ├── repositories/            Abstract interface contracts
│   │   └── services/
│   │       ├── productivity_score_calculator.dart  3-signal composite score 0–100
│   │       ├── retention_policy.dart               30/60/90-day log pruning
│   │       └── weekly_summary_service.dart         7-day avg score + trend label
│   ├── presentation/
│   │   ├── screens/
│   │   │   ├── splash_screen.dart           Logo + version; routes to permission/main
│   │   │   ├── permission_screen.dart       USAGE_STATS + SYSTEM_ALERT_WINDOW grant UI
│   │   │   ├── main_navigation_screen.dart  Bottom nav (4 tabs)
│   │   │   ├── dashboard_screen.dart        Score gauge, charts, top apps, alerts (942 lines)
│   │   │   ├── history_screen.dart          Tabbed usage + focus history, search/filter (577 lines)
│   │   │   ├── insights_screen.dart         Streak, sessions, pattern insights (480 lines)
│   │   │   ├── focus_session_screen.dart    Pomodoro timer 15/25/45/60 min (314 lines)
│   │   │   ├── settings_screen.dart         Category manager + prefs (744 lines)
│   │   │   └── network_proof_screen.dart    4-assertion static privacy screen (173 lines)
│   │   └── widgets/
│   │       ├── category_chart.dart          Pie chart: prod/distract/neutral
│   │       ├── trend_chart.dart             7-day bar chart (fl_chart)
│   │       ├── alert_tile.dart              Alert row with expand/collapse
│   │       ├── app_limit_dialog.dart        Per-app limit picker
│   │       ├── category_picker_dialog.dart  Category override dialog
│   │       └── post_session_check_in_dialog.dart  Emotional check-in (scaffold, not wired)
│   └── services/
│       ├── background_service.dart         Dart isolate: 15-min tick, AI eval, limit checks
│       ├── notification_service.dart       4 channels, quiet hours, mute, focus, daily-cap gates
│       ├── usage_collector_service.dart    MethodChannel bridge + psychology nudge generator
│       └── security_service.dart          Local JSON export of all DB tables
│
├── ml_training/
│   ├── train_decision_tree.py      Python: generate dataset → train → export JSON (98 lines)
│   └── decision_tree_model.json    Exported tree structure (149 lines)
│
├── generate_paper_figures.py       Standalone research figure script (25 KB)
├── pubspec.yaml                    Flutter package manifest
└── README.md                       Default Flutter boilerplate (not updated)
```

---

## 2. Tech Stack

### Languages & Frameworks

| Layer | Technology | Version | Purpose |
|---|---|---|---|
| UI + Logic | Flutter / Dart | >=3.0.0 | All UI screens, repositories, services, AI engine |
| Native Android | Kotlin | JVM 17 target | UsageStatsManager, WindowManager overlay, MethodChannel |
| Build | Gradle (Kotlin DSL) | compileSdk 36 | Android compilation and packaging |
| ML Training | Python 3 + scikit-learn | Offline one-shot | Train decision tree; export as JSON and Dart |

### Flutter Packages (pubspec.yaml)

| Package | Version | Purpose |
|---|---|---|
| `sqflite` | ^2.3.0 | All local SQLite storage — the only data store actually used |
| `path` | ^1.8.3 | File-path join for database location |
| `flutter_background_service` | ^5.0.0 | Persistent foreground Dart isolate |
| `flutter_local_notifications` | ^17.0.0 | 4 notification channels (bg, distraction, routine, weekly) |
| `fl_chart` | ^0.68.0 | Bar chart (7-day trend) + pie chart (category breakdown) |
| `flutter_riverpod` | ^2.5.1 | State management — **imported but not used in screens** |
| `permission_handler` | ^11.3.0 | Runtime permissions — **imported; requests done via MethodChannel instead** |
| `intl` | ^0.19.0 | Date/time formatting in history_screen.dart |
| `shared_preferences` | ^2.2.3 | KV storage — **imported; all settings use SQLite preferences table** |
| `cupertino_icons` | ^1.0.6 | iOS icon set |

### Android Native Dependency

| Dependency | Purpose |
|---|---|
| `com.android.tools:desugar_jdk_libs:2.1.5` | Java 8+ API desugaring needed by `flutter_local_notifications` |

---

## 3. Android Permissions

| Permission | Location | Why Needed |
|---|---|---|
| `PACKAGE_USAGE_STATS` | Production manifest | Read per-app foreground time via `UsageStatsManager`. Requires user grant in Settings |
| `POST_NOTIFICATIONS` | Production manifest | High-priority alerts (Android 13+ runtime grant) |
| `SYSTEM_ALERT_WINDOW` | Production manifest | Draw nudge overlay using `TYPE_APPLICATION_OVERLAY` |
| `FOREGROUND_SERVICE` | Production manifest | Run Dart isolate as foreground service (Android 8+ requirement) |
| `FOREGROUND_SERVICE_DATA_SYNC` | Production manifest | Declare service type = `dataSync` (Android 14+ strict enforcement) |
| `WAKE_LOCK` | Production manifest | Keep CPU awake during 2-second background polling |
| `QUERY_ALL_PACKAGES` | Production manifest | Resolve app labels; filter launcher/system packages |
| `INTERNET` | **debug + profile manifests only** | Flutter hot-reload tooling — absent from production builds |

---

## 4. Database Schema

**File:** `ai_routine_assistant.db` | SQLite via sqflite singleton (`AppDatabase.instance`)

### Table 1: `usage_logs`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Row ID |
| `package_name` | TEXT NOT NULL | e.g. `com.instagram.android` |
| `app_name` | TEXT NOT NULL | Resolved label e.g. `Instagram` |
| `start_time` | INTEGER NOT NULL | Unix epoch ms |
| `end_time` | INTEGER NOT NULL | Unix epoch ms |
| `duration_seconds` | INTEGER NOT NULL | Session length |

**Unique index:** `idx_usage_unique (package_name, start_time)` — deduplication on re-query.

### Table 2: `app_categories`

| Column | Type | Notes |
|---|---|---|
| `package_name` | TEXT PRIMARY KEY | Android package name |
| `category` | TEXT NOT NULL | `productive` / `distracting` / `neutral` |
| `is_custom` | INTEGER DEFAULT 0 | 1 = user override; 0 = seeded or auto |

Pre-seeded: 9 productive (Google Docs, Gmail, Notion, Todoist, Slack, Duolingo, Wikipedia, Word, Excel), 9 distracting (Instagram, TikTok, Facebook, Twitter, Snapchat, YouTube, Netflix, Reddit, Pinterest), 4 neutral (Chrome, Phone, Maps, WhatsApp).

### Table 3: `routines`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Row ID |
| `package_name` | TEXT NOT NULL | App |
| `time_of_day_minute` | INTEGER NOT NULL | Minute of day (0–1439) |
| `confidence_score` | REAL NOT NULL | AI confidence |
| `detected_at` | INTEGER NOT NULL | Unix epoch ms |

> **[NOT WORKING]** Created but never written to. Scaffold for future persistence of detected routines.

### Table 4: `notifications_log`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Row ID |
| `type` | TEXT NOT NULL | `distraction_alert` or `routine_reminder` |
| `package_name` | TEXT NOT NULL | Triggering app |
| `message` | TEXT NOT NULL | Human-readable alert text |
| `timestamp` | INTEGER NOT NULL | Unix epoch ms |
| `trigger_conditions` | TEXT | JSON: hourOfDay, durationMins, decisionRule, treeDepth |

### Table 5: `preferences`

| Column | Type | Notes |
|---|---|---|
| `key` | TEXT PRIMARY KEY | e.g. `quiet_hours_start`, `limit_pkg_com.instagram.android` |
| `value` | TEXT NOT NULL | String-encoded value |

Active keys: `quiet_hours_start`, `quiet_hours_end`, `mute_distraction`, `mute_routine`, `max_alerts_day`, `weekly_summary`, `retention_days`, `focus_active`, `last_prune_ms`, `last_weekly_summary_ms`, `limit_pkg_*`, `limit_cat_distracting`.

### Table 6: `focus_sessions`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Row ID |
| `start_time` | INTEGER NOT NULL | Unix epoch ms |
| `end_time` | INTEGER NOT NULL | Unix epoch ms |
| `duration_minutes` | INTEGER NOT NULL | Preset: 15, 25, 45, or 60 |
| `is_completed` | INTEGER NOT NULL | 1 = completed; 0 = abandoned |

### Table 7: `emotional_logs`

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | Row ID |
| `usage_log_id` | INTEGER | Soft FK to `usage_logs.id` (not enforced) |
| `package_name` | TEXT NOT NULL | App |
| `trigger_emotion` | TEXT NOT NULL | User-reported emotion |
| `timestamp` | INTEGER NOT NULL | Unix epoch ms |

> **[NOT WORKING]** Table exists; DB method exists; dialog widget exists; no UI wires them.

### Relationships (all soft — no SQLite FK enforcement)

```
usage_logs ──┬── app_categories  (package_name join)
             └── emotional_logs  (id → usage_log_id join)
notifications_log ── app_categories (package_name join)
focus_sessions ─── standalone
preferences ─── standalone (KV)
routines ─── orphan (not written)
```

---

## 5. Feature Status Table

| Feature | Status | Evidence (file : function) |
|---|---|---|
| Usage collection (UsageStatsManager → Dart) | ✅ Working | `MainActivity.kt:getParsedUsageEvents()`, `UsageCollectorService:collectAndSaveLogs()` |
| Session merging (gap < 30 s) | ✅ Working | `MainActivity.kt:375–389` merge loop |
| Launcher / system app filtering | ✅ Working | `EXCLUDED_PACKAGES` + `getLaunchIntentForPackage==null` guard |
| SQLite storage (7 tables) | ✅ Working | `AppDatabase._createDB()` |
| Duplicate-insert prevention | ✅ Working | `UNIQUE INDEX idx_usage_unique`; `ConflictAlgorithm.ignore` |
| App category seeding (22 apps) | ✅ Working | `seed_data.dart` + batch on DB create |
| Android auto-classification (ApplicationInfo.category) | ✅ Working | `MainActivity:classifyPackagesByAndroidCategory()` + `autoClassifyNewPackages()` |
| User category override | ✅ Working | `CategoryRepository:updateCategory()` (is_custom=1) + settings UI |
| Decision tree AI (5 features, depth 6) | ✅ Working | `DecisionTreeEngine:_predictDecisionTree()` |
| Distraction alerts (AI → notification) | ✅ Working | `background_service.dart:89–97` |
| Routine reminders (AI → notification) | ✅ Working | `background_service.dart:89–97` |
| Per-app daily time limits | ✅ Working | `background_service.dart:119–166` + `UsageMonitorService.kt:140–161` |
| Category limits (default 120 min for distracting) | ✅ Working | `UsageMonitorService.kt:144–147`; `PreferencesRepository:getCategoryLimitMinutes()` |
| Full-screen nudge overlay (WindowManager) | ✅ Working | `UsageMonitorService:showFullScreenOverlay()` — auto-dismiss 4 s |
| Psychology nudges (4 types: loss/identity/streak/impl.) | ✅ Working | `UsageCollectorService:getRandomPsychologyNudge()` |
| Local push notifications (4 channels) | ✅ Working | `NotificationService:showAlertNotification()` |
| Notification gating (quiet hours, mute, focus, cap) | ✅ Working | `NotificationService:_shouldShow()` — 4 sequential gates |
| Quiet hours (configurable) | ✅ Working | `PreferencesRepository:getQuietHoursStart/End()`; settings UI |
| Per-type mute toggles | ✅ Working | `isDistractionMuted()` / `isRoutineMuted()` |
| Max alerts/day cap (default 20) | ✅ Working | SQL COUNT check in `_shouldShow()` |
| Pomodoro focus timer (15/25/45/60 min) | ✅ Working | `FocusSessionScreen:_startTimer()` / `_completeSession()` |
| Focus-mode muting (suppresses distraction alerts) | ✅ Working | `setFocusActive(true)` gate in `_shouldShow()` |
| Productivity score (3-signal, 0–100) | ✅ Working | `ProductivityScoreCalculator:calculateCompositeScore()` |
| 7-day screen-time trend chart | ✅ Working | `UsageRepository:get7DayScreenTimeTrend()` + `TrendChart` widget |
| Category breakdown chart (pie) | ✅ Working | `getCategoryScreenTimeForToday()` + `CategoryChart` widget |
| Top-3 apps today | ✅ Working | `UsageRepository:getTopAppsForToday()` |
| Productivity streak (consecutive days >= 60) | ✅ Working | `UsageRepository:getProductivityStreak()` — 30-day lookback |
| Usage history + search/filter | ✅ Working | `HistoryScreen` — search + category filter tabs |
| Weekly summary notification (opt-in) | ✅ Working | `WeeklySummaryService:computeSummary()` + `showWeeklySummaryNotification()` |
| Data retention (30/60/90/unlimited) | ✅ Working | `RetentionPolicy:runPruneIfNeeded()` — 24 h rate-limited |
| Privacy proof screen (4 assertions) | ✅ Working | `NetworkProofScreen` |
| Local data export (JSON, no network) | ✅ Working | `SecurityService:exportAppDataAsJson()` |
| Background service (15-min tick) | ✅ Working | `flutter_background_service` foreground mode |
| Native 2-second polling | ✅ Working | `UsageMonitorService.kt` Handler loop |
| Permission onboarding screen | ✅ Working | `PermissionScreen` + `WidgetsBindingObserver` |
| `flutter_riverpod` state management | ⚠️ Partially Working | Imported; screens use `setState` — Riverpod not wired |
| `shared_preferences` storage | ⚠️ Partially Working | Imported; all settings go to SQLite `preferences` table |
| `permission_handler` package | ⚠️ Partially Working | Imported; actual requests done via MethodChannel |
| Insights predictability index | ⚠️ Partially Working | Hard-coded formula `(75+streak*3).clamp(65,96)` — not the composite score |
| `routines` table writes | ❌ Not Working | Table created; no INSERT anywhere in codebase |
| Emotional check-in flow | ❌ Not Working | Dialog widget + DB method exist; no UI flow connects them |
