# 06 – Diagram Data (Mermaid)
**AI Routine Assistant** | Presentation Preparation Document

---

## Verified Facts (confirmed directly in code)

- All nodes and edges in these diagrams represent real components confirmed in the codebase
- MethodChannel name verified: `"com.example.ai_routine_assistant/usage"` (MainActivity.kt:31)
- Table names and column names verified in `AppDatabase._createDB()` (app_database.dart)
- Service names and class names match actual Kotlin/Dart source files
- No speculative or planned components are included unless labelled [FUTURE]

---

## Diagram 1 — System Architecture

```mermaid
graph TB
    subgraph ANDROID_OS["Android OS Layer"]
        USM["UsageStatsManager\n(queryEvents)"]
        WM["WindowManager\n(overlay layer)"]
        NM["NotificationManager\n(local notifications)"]
    end

    subgraph KOTLIN["Kotlin Layer (MainActivity.kt + UsageMonitorService.kt)"]
        MA["MainActivity\nMethodChannel Handler\nOverlay UI builder"]
        UMS["UsageMonitorService\n2s polling loop\nSQLite direct read\nFull-screen overlay"]
    end

    subgraph CHANNEL["Flutter MethodChannel\n'com.example.ai_routine_assistant/usage'"]
        MC[["8 Methods:\nqueryUsageEvents\nclassifyPackages\nshowDistractionOverlay\nhideOverlay\ncheckUsagePermission\nopenUsageSettings\nstartUsageMonitorService\nstopUsageMonitorService"]]
    end

    subgraph DART["Dart Layer"]
        subgraph SERVICES["Services"]
            BG["BackgroundService\n15-min tick isolate"]
            UCS["UsageCollectorService\nMethodChannel bridge"]
            NS["NotificationService\n4 gates + 4 channels"]
        end
        subgraph AI["AI Engine"]
            DTE["DecisionTreeEngine\n5 features, depth 6\n3 output classes"]
        end
        subgraph REPOS["Repositories"]
            UR["UsageRepository"]
            CR["CategoryRepository"]
            PR["PreferencesRepository"]
            FR["FocusRepository"]
        end
        subgraph UI["Presentation Layer"]
            DS["DashboardScreen\n(score, charts, alerts)"]
            HS["HistoryScreen\n(logs + focus tabs)"]
            IS["InsightsScreen\n(streak, sessions)"]
            SS["SettingsScreen\n(categories + prefs)"]
            FT["FocusSessionScreen\n(Pomodoro timer)"]
            NPS["NetworkProofScreen\n(privacy assertions)"]
        end
    end

    subgraph DB["SQLite Database\n(ai_routine_assistant.db)"]
        UL[("usage_logs")]
        AC[("app_categories")]
        NL[("notifications_log")]
        PREF[("preferences")]
        FS[("focus_sessions")]
        EL[("emotional_logs\n[FUTURE]")]
        RT[("routines\n[FUTURE]")]
    end

    USM -->|"FOREGROUND/BACKGROUND events"| MA
    USM -->|"5s window poll"| UMS
    MA <-->|"MethodChannel calls"| MC
    MC <-->|"Dart calls"| UCS
    UCS --> UR
    UR --> UL
    BG --> UCS
    BG --> DTE
    DTE -->|"RoutineAlert list"| BG
    BG --> NS
    BG --> PR
    PR --> PREF
    NS --> NM
    UMS -->|"WAL-safe read"| UL
    UMS -->|"read"| PREF
    UMS --> WM
    MA --> WM
    UR --> UL
    UR --> AC
    CR --> AC
    FR --> FS
    DS --> UR
    DS --> FR
    HS --> UR
    IS --> UR
    SS --> CR
    SS --> PR
    FT --> FR
    FT --> PR
```

---

## Diagram 2 — Data Flow

```mermaid
sequenceDiagram
    participant OS as Android OS<br/>(UsageStatsManager)
    participant KT as Kotlin<br/>(MainActivity)
    participant CH as MethodChannel
    participant CS as UsageCollectorService<br/>(Dart)
    participant UR as UsageRepository<br/>(Dart)
    participant DB as SQLite DB
    participant AI as DecisionTreeEngine
    participant NS as NotificationService
    participant BG as BackgroundService<br/>(Dart isolate)

    Note over BG: Every 15 minutes
    BG->>CS: collectAndSaveLogs(window: 24h)
    CS->>CH: queryUsageEvents(startTime, endTime)
    CH->>KT: invoke 'queryUsageEvents'
    KT->>OS: queryEvents(startMs, endMs)
    OS-->>KT: raw FOREGROUND/BACKGROUND events
    KT->>KT: pair events → sessions
    KT->>KT: merge sessions (gap < 30s)
    KT->>KT: filter launchers + system apps
    KT->>KT: resolve app labels (with cache)
    KT-->>CH: List<Map<String,Any>>
    CH-->>CS: List<dynamic>
    CS->>CS: parse → List<UsageLog>
    CS->>UR: insertUsageLogs(logs)
    UR->>DB: BATCH INSERT OR IGNORE → usage_logs
    CS->>CS: autoClassifyNewPackages()
    CS->>CH: classifyPackages(unknownPackages)
    CH->>KT: invoke 'classifyPackages'
    KT->>KT: ApplicationInfo.category lookup
    KT-->>CS: Map<pkg, category>
    CS->>DB: INSERT IGNORE → app_categories

    BG->>DB: query usage_logs + app_categories
    DB-->>BG: logs + categories
    BG->>AI: evaluateUsagePatterns(logs, categories)
    AI->>AI: compute 5 features per log
    AI->>AI: _predictDecisionTree(...)
    AI-->>BG: List<RoutineAlert>
    BG->>DB: INSERT → notifications_log
    BG->>NS: showAlertNotification(alert)
    NS->>NS: _shouldShow() → 4 gates
    NS->>NS: flutter_local_notifications.show()

    Note over BG: Also checks daily limits
    BG->>DB: sum today's usage per pkg
    BG->>DB: read limit from preferences
    alt limit exceeded
        BG->>NS: showAlertNotification(limitAlert)
        BG->>CS: showDistractionOverlay(appName, pkg)
        CS->>CH: invoke 'showDistractionOverlay'
        CH->>KT: showNudgeOverlay(...)
        KT->>KT: WindowManager.addView(overlayView)
    end
```

---

## Diagram 3 — Alert Trigger Flowchart

```mermaid
flowchart TD
    START([App foregrounded OR 15-min tick fires]) --> PATH{Which path?}

    PATH -->|"Native Kotlin 2-second poll"| KP1["checkForegroundApp()"]
    KP1 --> KP2{New foreground app?}
    KP2 -->|No| WAIT1([Wait 2s, repeat])
    KP2 -->|Yes| KP3["onAppForegrounded(pkg)"]
    KP3 --> KP4{Has launch intent?\n(not system/launcher)}
    KP4 -->|No| WAIT1
    KP4 -->|Yes| KP5["Read app_categories\nfrom SQLite"]
    KP5 --> KP6{"category ==\n'distracting'?"}
    KP6 -->|No| KP7["limitMins = pkg limit\nfrom preferences"]
    KP6 -->|Yes| KP8["limitMins = pkg limit\nOR category limit (120 min default)"]
    KP7 --> KP9{limitMins > 0?}
    KP8 --> KP9
    KP9 -->|No| WAIT1
    KP9 -->|Yes| KP10["SUM today usage\nfrom usage_logs"]
    KP10 --> KP11{usedMins >= limitMins?}
    KP11 -->|No| WAIT1
    KP11 -->|Yes| KP12["triggerAlert(pkg, appName, used, limit)"]
    KP12 --> KP13{Has SYSTEM_ALERT_WINDOW\npermission?}
    KP13 -->|Yes| KP14["showFullScreenOverlay(appName)\n(auto-dismiss 4s)"]
    KP13 -->|No| KP15
    KP14 --> KP15["showLimitNotification(pkg, appName)"]
    KP15 --> KP16{Within 1-min\ncooldown?}
    KP16 -->|Yes| DONE1([Done])
    KP16 -->|No| KP17["NotificationManager.notify()"]
    KP17 --> DONE1

    PATH -->|"Dart 15-min AI analysis"| DP1["collectAndSaveLogs()"]
    DP1 --> DP2["DecisionTreeEngine\n.evaluateUsagePatterns()"]
    DP2 --> DP3["_predictDecisionTree()\nfor each UsageLog"]
    DP3 --> DP4{Predicted class?}
    DP4 -->|"0 = No Alert"| DONE2([No action])
    DP4 -->|"1 = Distraction Alert"| DP5["RoutineAlert(distractionAlert)"]
    DP4 -->|"2 = Routine Reminder"| DP6["RoutineAlert(routineReminder)"]
    DP5 --> DP7["insertNotification() → notifications_log"]
    DP6 --> DP7
    DP7 --> DP8["NotificationService._shouldShow()"]
    DP8 --> GATE1{Type muted?}
    GATE1 -->|Yes| BLOCKED([Blocked])
    GATE1 -->|No| GATE2{Focus active?\n(distraction only)}
    GATE2 -->|Yes| BLOCKED
    GATE2 -->|No| GATE3{Quiet hours?}
    GATE3 -->|Yes| BLOCKED
    GATE3 -->|No| GATE4{Daily cap\nreached?}
    GATE4 -->|Yes| BLOCKED
    GATE4 -->|No| SEND["flutter_local_notifications.show()"]
    SEND --> DONE3([Notification sent])
```

---

## Diagram 4 — Database ER Diagram

```mermaid
erDiagram
    USAGE_LOGS {
        INTEGER id PK
        TEXT package_name
        TEXT app_name
        INTEGER start_time
        INTEGER end_time
        INTEGER duration_seconds
    }

    APP_CATEGORIES {
        TEXT package_name PK
        TEXT category
        INTEGER is_custom
    }

    NOTIFICATIONS_LOG {
        INTEGER id PK
        TEXT type
        TEXT package_name
        TEXT message
        INTEGER timestamp
        TEXT trigger_conditions
    }

    PREFERENCES {
        TEXT key PK
        TEXT value
    }

    FOCUS_SESSIONS {
        INTEGER id PK
        INTEGER start_time
        INTEGER end_time
        INTEGER duration_minutes
        INTEGER is_completed
    }

    EMOTIONAL_LOGS {
        INTEGER id PK
        INTEGER usage_log_id
        TEXT package_name
        TEXT trigger_emotion
        INTEGER timestamp
    }

    ROUTINES {
        INTEGER id PK
        TEXT package_name
        INTEGER time_of_day_minute
        REAL confidence_score
        INTEGER detected_at
    }

    USAGE_LOGS ||--o{ EMOTIONAL_LOGS : "id → usage_log_id (soft FK)"
    USAGE_LOGS }o--|| APP_CATEGORIES : "package_name join (no FK)"
    NOTIFICATIONS_LOG }o--|| APP_CATEGORIES : "package_name join (no FK)"
    ROUTINES }o--|| APP_CATEGORIES : "package_name join (not written)"
```

> **Notes on diagram:**
> - All foreign key relationships are soft (no SQLite FK enforcement)
> - `ROUTINES` table: created, never written to — [FUTURE]
> - `EMOTIONAL_LOGS` table: created, DB method exists, UI not wired — [FUTURE]
> - `PREFERENCES` is standalone (no joins with other tables)
> - `FOCUS_SESSIONS` is standalone (queried independently by WeeklySummaryService)
