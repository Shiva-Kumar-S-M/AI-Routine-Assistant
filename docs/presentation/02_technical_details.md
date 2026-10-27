# 02 – Technical Deep Dive
**AI Routine Assistant** | Presentation Preparation Document

---

## Verified Facts (confirmed directly in code)

- MethodChannel name: `"com.example.ai_routine_assistant/usage"` (MainActivity.kt:31, UsageCollectorService.dart:9)
- 8 MethodChannel calls confirmed: `checkUsagePermission`, `openUsageSettings`, `checkOverlayPermission`, `openOverlaySettings`, `showDistractionOverlay`, `hideOverlay`, `queryUsageEvents`, `classifyPackages`, `startUsageMonitorService`, `stopUsageMonitorService`
- 5 AI input features confirmed in `_predictDecisionTree()` signature (decision_tree_engine.dart:119–125)
- Tree depth hardcoded as constant `'treeDepth': 6` in `triggerConditions` JSON (decision_tree_engine.dart:82, 107)
- 4 psychology nudge message types confirmed: `loss`, `identity`, `implementation`, `streak` (UsageCollectorService.dart:108–125, UsageMonitorService.kt:53–58)
- Distraction threshold: 2,392 seconds rolling (decision_tree_engine.dart:146 — tree node threshold)
- 1-minute notification cooldown per package (UsageMonitorService.kt:51: `NOTIFICATION_COOLDOWN_MS = 60_000L`)
- INTERNET permission absent from production manifest — confirmed by code search across all `.xml` files
- INTERNET in `debug/AndroidManifest.xml` is documented as Flutter tooling only (comment at line 2)
- No HTTP client imports, no `http` or `dio` package in pubspec.yaml, no socket usage anywhere

---

## 1. End-to-End Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ANDROID OS                                           │
│  UsageStatsManager.queryEvents(startMs, endMs)                             │
│       ↓ raw MOVE_TO_FOREGROUND / MOVE_TO_BACKGROUND events                 │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │
              ┌────────────▼────────────┐
              │   MainActivity.kt       │  Kotlin
              │  getParsedUsageEvents() │
              │  • FOREGROUND+BACKGROUND│
              │    event pairs merged   │
              │  • Sessions < 30 s gap  │
              │    merged into one      │
              │  • Launchers filtered   │
              │  • App labels resolved  │
              └────────────┬────────────┘
                           │  List<Map> via MethodChannel
              ┌────────────▼────────────┐
              │UsageCollectorService.dart│ Dart
              │  collectAndSaveLogs()   │
              │  • Parses Map → UsageLog│
              │  • Calls insertUsageLogs│
              │  • autoClassifyNew...() │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │   UsageRepository.dart  │ Dart
              │  insertUsageLogs()      │
              │  • Batch INSERT IGNORE  │
              │  • Backfill stale names │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │    SQLite DB            │
              │  usage_logs table       │
              │  app_categories table   │
              └──────┬──────┬───────────┘
                     │      │
         ┌───────────▼─┐  ┌─▼──────────────────┐
         │DecisionTree │  │Limit Checker        │
         │Engine.dart  │  │(background_service) │
         │5-feature    │  │• Per-app limit from │
         │classifier   │  │  preferences table  │
         │→ class 0/1/2│  │• Fires if used mins │
         └──────┬──────┘  │  >= limit mins      │
                │          └────────┬────────────┘
         ┌──────▼────────────┐      │
         │RoutineAlert(s)    │      │
         │• distractionAlert │      │
         │• routineReminder  │◄─────┘
         └──────┬────────────┘
                │
     ┌──────────┴──────────────────────────────────┐
     │                                             │
┌────▼────────────────┐             ┌──────────────▼──────────┐
│NotificationService  │             │NativeKotlinService      │
│• 4-gate _shouldShow │             │UsageMonitorService.kt   │
│• flutter_local_notif│             │• 2-sec polling loop     │
│• 4 channels         │             │• Reads SQLite directly  │
└────┬────────────────┘             │• WindowManager overlay  │
     │ Local push notification      │• 4-sec auto-dismiss     │
     │                              └──────────────┬──────────┘
┌────▼────────────────────┐                        │
│   UI Layer              │   Full-screen overlay  │
│ DashboardScreen         │◄───────────────────────┘
│ • score gauge           │
│ • pie chart             │
│ • 7-day bar chart       │
│ • top 3 apps            │
│ • alert tile list       │
└─────────────────────────┘
```

### Step-by-step narrative

1. **Android collects events.** Every 15 minutes (Dart isolate) or every 2 seconds (Kotlin service), `UsageStatsManager.queryEvents()` is called with a time window.
2. **Kotlin processes events.** `MainActivity.getParsedUsageEvents()` pairs `MOVE_TO_FOREGROUND` and `MOVE_TO_BACKGROUND` events into sessions, merges sessions within 30 seconds, filters launchers and system packages, resolves app labels.
3. **MethodChannel transport.** The session list is returned as `List<Map<String, Any>>` across the Flutter MethodChannel (`"com.example.ai_routine_assistant/usage"`, method `queryUsageEvents`).
4. **Dart parsing and storage.** `UsageCollectorService` parses each Map into a `UsageLog` object and calls `UsageRepository.insertUsageLogs()`, which does a batch `INSERT OR IGNORE` into `usage_logs`.
5. **AI evaluation.** `background_service.dart` passes logs + category map to `DecisionTreeEngine.evaluateUsagePatterns()`. The engine computes the 5 features per log and returns `RoutineAlert` objects.
6. **Limit checking.** Separately, `background_service.dart` sums today's usage per package, reads configured limits from `preferences`, and fires a `RoutineAlert` if exceeded.
7. **Notification gating.** `NotificationService._shouldShow()` applies 4 gates: type-muted?, focus-active?, quiet hours?, daily-cap reached?
8. **Output:** If gates pass → local notification via `flutter_local_notifications`. If overlay permission granted → native WindowManager overlay via `UsageMonitorService`.
9. **Dashboard reads.** `DashboardScreen` calls repository methods to render the productivity score, charts, top-3 apps, and alert history.

---

## 2. The AI Engine

### Simple explanation

The app watches which apps you use, how long for, and what category they are. Using a decision tree (a chain of yes/no questions), it decides: "Should I alert the user?" If yes: is it a distraction alert or a routine reminder?

### Technical explanation

**Engine class:** `DecisionTreeEngine` (implements `RoutineEngine`)  
**File:** `lib/ai/decision_tree_engine.dart`

#### The 5 Input Features

| # | Feature Name | Type | How Computed | What It Captures |
|---|---|---|---|---|
| 1 | `hour_of_day` | int (0–23) | `log.startTime.hour` | Time of day the session started |
| 2 | `duration_seconds` | int | `log.durationSeconds` | Length of the single usage session |
| 3 | `category_code` | int (0/1/2) | 0=productive, 1=neutral, 2=distracting | Whether the app is helpful or harmful |
| 4 | `rolling_distraction_2h` | int (seconds) | Sum of distracting-app usage in past 2 hours | Cumulative distraction pressure |
| 5 | `days_used_this_hour` | int (1–7) | Distinct days in past 7 days app was used at same hour slot | Habit strength / routine regularity |

#### The 3 Output Classes

| Class | Label | Meaning | Action Taken |
|---|---|---|---|
| 0 | No Alert | Normal usage pattern | Nothing (silently logged) |
| 1 | Distraction Alert | Excessive distracting usage | Push notification + WindowManager overlay |
| 2 | Routine Reminder | Consistent habitual usage detected | Push notification |

#### Tree Decision Logic (depth 6, compiled to Dart)

```
Root: category_code <= 1.5?
  ├── YES (productive or neutral)
  │     hour_of_day <= 7.5?
  │     ├── YES: → Class 0  (early morning, no routine yet)
  │     └── NO: days_used_this_hour <= 2.5?
  │           ├── YES: → Class 0  (not yet habitual)
  │           └── NO: duration_seconds <= 298.0?
  │                 ├── YES: → Class 0  (too short)
  │                 └── NO: hour_of_day <= 22.5?
  │                       ├── YES: → Class 2  ← ROUTINE REMINDER
  │                       └── NO: → Class 0  (late night, no alert)
  │
  └── NO (distracting app, category_code > 1.5)
        rolling_distraction_2h > 2392.0?
        ├── YES: → Class 1  ← DISTRACTION ALERT (40+ min cumulative)
        └── NO: duration_seconds > 3595.5?
              ├── YES: → Class 1  ← DISTRACTION ALERT (single 60-min session)
              └── NO: hour_of_day <= 7.5?
                    ├── YES: → Class 0  (early morning)
                    └── NO: days_used_this_hour <= 2.5?
                          ├── YES: → Class 0  (not habitual)
                          └── NO: duration_seconds <= 676.5?
                                ├── YES: → Class 0  (~89% chance)
                                └── NO: → Class 2  ← ROUTINE REMINDER (~95% chance)
```

**Key thresholds (verified from code):**
- Distraction alert triggers if rolling 2h distraction >= **2,392 seconds (~39.9 min)**
- Or single session duration >= **3,595.5 seconds (~59.9 min)**
- Routine reminder requires **>2.5 days** (i.e. 3+) of consistent usage at same hour slot, sessions **>298 seconds**, between **07:30–22:30**

#### How the Model is Loaded

The tree is **not dynamically parsed from the JSON at runtime**. The JSON in `ml_training/decision_tree_model.json` was exported for documentation and reproducibility. The actual tree logic is **compiled directly into `DecisionTreeEngine._predictDecisionTree()` as a Dart if/else function**. This means:
- Zero parsing overhead at runtime
- Zero JSON loading, zero file I/O in the AI path
- The JSON and Dart code match each other (verified by comparing thresholds)

---

## 3. ML Pipeline

### Training Script: `ml_training/train_decision_tree.py`

**Step 1 — Synthetic Dataset Generation** (`generate_synthetic_dataset(2500)`)

The dataset is **synthetically generated**, not collected from real users. Labels are assigned by rule:

```python
# Label 1: Distraction Alert
if category_code == 2 and (rolling_distraction_2h >= 2400 or duration_seconds >= 3600):
    label = 1
# Label 2: Routine Reminder  
elif days_used_this_hour >= 3 and (8 <= hour_of_day <= 22) and duration_seconds > 300:
    label = 2
# Label 0: No Alert
else:
    label = 0
```

Feature ranges:
- `hour_of_day`: random int 0–23
- `duration_seconds`: random int 10–7200
- `category_code`: random choice [0,1,2] with probabilities [0.3, 0.3, 0.4]
- `rolling_distraction_2h`: random int 0–5400
- `days_used_this_hour`: random int 1–7

**Step 2 — Train/Test Split:** 80% train (2,000 samples), 20% test (500 samples), `random_state=42`

**Step 3 — Model Training:** `DecisionTreeClassifier(max_depth=6, random_state=42)`

**Step 4 — Export:** Tree structure serialised to `decision_tree_model.json` via custom recursive `export_tree_to_json()` function.

### ML Metrics

> **[NOT VERIFIED — script could not be executed in this environment]**
>
> The training script (`train_decision_tree.py`) prints `train_accuracy`, `test_accuracy`, a `confusion_matrix`, and a full `classification_report`. However, the shell execution tool encountered a connection error during this session. **Metrics below are NOT real outputs and should not be used in the presentation.**
>
> **To get real numbers before your presentation, run:**
> ```bash
> cd "/home/shivu/Major project"
> python3 ml_training/train_decision_tree.py
> ```
> This will print Train Accuracy, Test Accuracy, Confusion Matrix, and a per-class Precision/Recall/F1 report.

**What the script is designed to output:**
- `Train Accuracy: XX.XX%`
- `Test Accuracy: XX.XX%`
- Confusion matrix (3×3: No Alert / Distraction Alert / Routine Reminder)
- Classification report with per-class Precision, Recall, F1-Score

**Important caveat to mention honestly:** Because the labels in the synthetic dataset are generated by the **same rules** the tree is trying to learn, test accuracy is expected to be very high (likely > 95%). This **does not reflect real-world accuracy on actual user behaviour data**, which has not been measured.

---

## 4. App Names, Categories, and Filtering

### Three-tier classification pipeline

**Tier 1 — Seed data** (`seed_data.dart`):  
22 hardcoded entries set at database creation time. These are never overwritten by auto-classification. Priority = highest.

**Tier 2 — Android ApplicationInfo.category** (Kotlin):  
`MainActivity.classifyPackagesByAndroidCategory()` maps Android OS category constants:

| Android Constant | Bucket |
|---|---|
| `CATEGORY_GAME` | `distracting` |
| `CATEGORY_VIDEO` | `distracting` |
| `CATEGORY_SOCIAL` | `distracting` |
| `CATEGORY_PRODUCTIVITY` | `productive` |
| `CATEGORY_AUDIO`, `CATEGORY_IMAGE`, `CATEGORY_NEWS`, `CATEGORY_MAPS` | `neutral` |
| `CATEGORY_UNDEFINED` or unknown | `neutral` |

`UsageCollectorService.autoClassifyNewPackages()` runs this for every new package not yet in `app_categories`, then calls `CategoryRepository.insertAutoCategoryIfAbsent()` which uses `ConflictAlgorithm.ignore` — preserving manual and seed entries.

**Tier 3 — User override** (Settings screen):  
User can pick productive/neutral/distracting for any app via `CategoryPickerDialog`. Stored with `is_custom=1`.

### System / Launcher Filtering

Two-layer filter in `MainActivity.getParsedUsageEvents()`:

1. **Hardcoded exclusion set** (`EXCLUDED_PACKAGES`): Samsung Launcher, Nexus Launcher, MIUI Home, OPPO Launcher, Android Launcher (2/3), SystemUI, Samsung SystemUI, InCallUI, Telecom.
2. **Dynamic filter**: Any package for which `packageManager.getLaunchIntentForPackage(pkg) == null` is excluded — catches any system service without a user-launchable UI.

App label resolution uses a **per-cycle cache** (`appNameCache`) to avoid repeated `PackageManager` calls within one fetch.

---

## 5. Alerts: Limits, Notifications, and Overlay

### Path 1: AI Pattern Detection (every 15 min via Dart isolate)

1. `background_service.dart` tick fires
2. `UsageCollectorService.collectAndSaveLogs()` fetches 24-h window
3. `DecisionTreeEngine.evaluateUsagePatterns()` produces alerts
4. Each alert: `UsageRepository.insertNotification()` → stored in `notifications_log`
5. `NotificationService.showAlertNotification(alert)` called → `_shouldShow()` gate

### Path 2: Real-time Limit Monitoring (every 2 s via Kotlin service)

1. `UsageMonitorService.checkForegroundApp()` polls last 5-second event window
2. On app-foreground change → `onAppForegrounded(pkg)`:
   - Opens DB read-only (`SQLiteDatabase.OPEN_READONLY`, WAL-safe)
   - Resolves category from `app_categories`
   - Resolves per-app limit (falls back to category limit for distracting apps)
   - Sums today's usage from `usage_logs`
   - If `usedMins >= limitMins` → `triggerAlert()`
3. `triggerAlert()` → `showFullScreenOverlay()` + `showLimitNotification()`

### Notification Gating (`NotificationService._shouldShow()`)

Applied in strict order:

| Gate | Condition | Blocks when... |
|---|---|---|
| 1. Type mute | `isDistractionMuted()` / `isRoutineMuted()` | User toggled off that alert type in Settings |
| 2. Focus active | `isFocusActive()` (distraction only) | Pomodoro timer is running |
| 3. Quiet hours | `_isInQuietHours(now, start, end)` | Current hour is within the quiet window |
| 4. Daily cap | SQL COUNT >= `getMaxAlertsPerDay()` | Today's notification count hit the cap (default 20) |

Quiet hours support overnight windows (e.g., 22:00–07:00) via the overnight wrap-around check.

Notification cooldown in Kotlin service: 1 minute per package (`NOTIFICATION_COOLDOWN_MS = 60_000L`).

### Overlay Behavior

**From `UsageMonitorService.kt`:**
- Full-screen dark scrim (`#E6101018` = ~90% opacity)
- Centred card with app icon (⚡), title, nudge badge, message
- Tap-anywhere to dismiss
- **Auto-dismiss after 4 seconds** (`handler.postDelayed({ hideOverlay() }, 4000L)`)

**From `MainActivity.kt` (triggered by Dart via MethodChannel):**
- Smaller card overlay, not full-screen
- Two buttons: "Switch to Productive App" (launches target package) and "Dismiss"
- Button actions report back to Flutter via `methodChannel.invokeMethod("onOverlayAction", ...)`

### Psychology-Message Logic

4 message frames, each backed by a behavioural psychology principle:

| Type | Principle | Message Template |
|---|---|---|
| `loss` | Loss aversion (Kahneman) | "Trading 45 mins of your future goals for short-term scrolling on %s..." |
| `identity` | Identity-based habits (Clear) | "Is opening %s right now aligned with the focused, disciplined person you are becoming?" |
| `implementation` | Implementation intention (Gollwitzer) | "When you feel the urge to scroll %s, pause 10 seconds and switch to your productive task." |
| `streak` | Habit streak motivation | "You have maintained your focus momentum today! Don't break your streak..." |

The Kotlin service selects randomly from all 4. The Dart service uses `getRandomPsychologyNudge()` which also supports `overrideType` for limit-exceeded alerts (forces `loss` framing from `background_service.dart:163`).

---

## 6. Privacy Proof

### Search Results: Network Usage

A code search for `http`, `socket`, `INTERNET`, `HttpClient`, `dio` across all `.dart`, `.kt`, and `.xml` files found:

| Match | File | Verdict |
|---|---|---|
| `xmlns:android="http://...` | All XML files | XML namespace declaration — not a network call |
| `INTERNET` permission | `debug/AndroidManifest.xml` (line 6) | Flutter hot-reload only — **documented** as such in the comment at lines 2–4 |
| `INTERNET` permission | `profile/AndroidManifest.xml` (line 6) | Flutter profiling only — identical comment |
| `INTERNET` in `network_proof_screen.dart` | `network_proof_screen.dart:71` | UI text displaying "NOT DECLARED" — **not** an actual permission declaration |
| No `http` package in pubspec.yaml | `pubspec.yaml` | Verified — no `http`, `dio`, `retrofit`, or any HTTP client |
| No `HttpClient` | All `.dart` files | Not found |
| No socket usage | All `.dart` + `.kt` files | Not found |
| No Firebase / Analytics | `pubspec.yaml` | No `firebase_core`, `firebase_analytics`, `mixpanel_flutter`, `amplitude` |

### Conclusion

**The "zero network" claim holds for production builds.**

- The production `AndroidManifest.xml` (`src/main/`) does **not** declare `android.permission.INTERNET`
- Without this permission, Android's kernel blocks all outbound sockets at OS level — no data can leave the device
- The `INTERNET` entries in `debug/` and `profile/` manifests are standard Flutter SDK tooling additions and are **never packaged in a release APK/AAB**
- No HTTP client library, no analytics SDK, no cloud service dependency in the codebase

The app's `NetworkProofScreen` correctly states 4 verifiable assertions:
1. `android.permission.INTERNET` — NOT DECLARED (in production)
2. Active outbound HTTP sockets — 0
3. Telemetry & log storage — Sandboxed SQLite Only
4. Third-party analytics SDKs — None installed
