# AI Routine Assistant — Project Context

## Overview
Flutter + Kotlin Android app. 100% on-device, zero-network screen-time & behavioral routine
tracker powered by an on-device decision tree ML engine.

## Stack
- **Frontend**: Flutter (Dart) — `lib/`
- **Native Bridge**: Kotlin (`android/app/src/main/kotlin/…/MainActivity.kt`)
  - `UsageStatsManager` via `MethodChannel("com.example.ai_routine_assistant/usage")`
  - `WindowManager` overlay (TYPE_APPLICATION_OVERLAY) for nudge UI
- **Storage**: SQLite via `sqflite` — schema in `AppDatabase._createDB`
- **Background**: `flutter_background_service` — `background_service.dart`
- **ML**: Decision tree JSON (`ml_training/decision_tree_model.json`) loaded at runtime

## Architecture (DO NOT reorganize)
```
lib/
├── main.dart
├── ai/          routine_engine.dart · decision_tree_engine.dart · rule_based_engine.dart
├── data/        database/ · repositories/
├── domain/      models/ · services/ · repositories/
├── presentation/ screens/ · widgets/
└── services/    usage_collector_service.dart · notification_service.dart
                 background_service.dart · security_service.dart
android/app/src/main/kotlin/com/example/ai_routine_assistant/MainActivity.kt
ml_training/    train_decision_tree.py · decision_tree_model.json
```

## Key Invariants
- `packageName` is the stable primary key for all DB writes, app_categories lookups,
  and per-app limit matching. Never swap to appName as key.
- `appName` is display-only; always fall back to packageName if empty.
- No new architecture layers, no state-management swaps.
- Every change must be additive or a targeted fix — no full file rewrites.

## Current Milestone — v1 Bug Fixes (Session 2026-09-27)

### OUTCOME A: App name resolution
Dashboard/history/insights show human-readable app names, not raw package IDs.

### OUTCOME B: Background alert reliability
Background service evaluates daily limits every 15 min and fires:
(a) Android notification via notification_service.dart
(b) Full-screen overlay via WindowManager in MainActivity.kt

## Task Backlog
| # | Task | Status |
|---|------|--------|
| 1 | App name resolution (Outcome A) | DONE |
| 2 | Diagnose background evaluation gap (Outcome B root cause) | PENDING |
| 3 | Fix permissions blocking alerts | PENDING |
| 4 | Wire actual alert trigger (notification + overlay) | PENDING |
