# 05 – Demo Script and Q&A Preparation
**AI Routine Assistant** | Presentation Preparation Document

---

## Verified Facts (confirmed directly in code)

- Demo steps below use ONLY features confirmed Working in the project audit (01_project_audit.md)
- Features marked [NOT WORKING] or [FUTURE] in the audit are excluded from the demo script
- Q&A answers are grounded in code evidence; uncertain items are marked [NOT VERIFIED]

---

## Part 1 — Live Demo Script (3–4 minutes)

### Pre-demo checklist (do before presenting)
- [ ] Install the APK on device (debug build is fine)
- [ ] Grant USAGE_STATS permission (Settings → Apps → Special app access → Usage access)
- [ ] Grant SYSTEM_ALERT_WINDOW permission (Settings → Apps → Special app access → Display over other apps)
- [ ] Grant POST_NOTIFICATIONS permission (first launch prompt)
- [ ] Use the device for a few minutes on a distracting app (YouTube, Instagram) so the dashboard has real data
- [ ] Optionally: set Instagram/YouTube limit to 1 minute so you can trigger the overlay live

---

### Step 1 — Permission Screen (0:00–0:20)

**What to show:** Open the app fresh. The `PermissionScreen` appears.

**Say:** "The app needs two special permissions — Usage Access to read app sessions, and Display Over Other Apps for the nudge overlay. Both are required by Android's security model for this level of system integration. Notice the app explains exactly why each permission is needed."

**What to click:** Grant Usage Stats → grant Display Over Other Apps → app navigates to Dashboard automatically.

**Backup:** Screenshot of PermissionScreen with both buttons.

---

### Step 2 — Dashboard (0:20–1:10)

**What to show:** `DashboardScreen` loads with real data.

**Say:** "This is the main dashboard. The gauge at the top is a composite productivity score — 45% based on distraction ratio, 35% on focus time completed, and 20% on routine adherence. The pie chart shows today's screen time split across productive, distracting, and neutral apps. The bar chart shows the 7-day trend."

**Point out:** Top-3 apps panel (shows real app names resolved from the device). Scroll down to show the alert tile list.

**Expand one alert tile.** Say: "Every AI alert shows its decision rule — this one fired because the 2-hour rolling distraction exceeded 40 minutes, which is the decision tree's threshold. This is fully interpretable AI — you can trace any alert to the exact condition that caused it."

**Backup:** Screenshot of Dashboard with populated data.

---

### Step 3 — Settings: Set a Per-App Limit (1:10–1:40)

**What to show:** Tap Settings tab → App Categories.

**Say:** "The app automatically classifies every installed app using Android's ApplicationInfo category API, and falls back to a pre-seeded list of 22 common apps. Users can override any classification manually."

**Tap one app (e.g. YouTube) → App Limit dialog.** Set limit to 2 minutes.

**Say:** "I've just set a 2-minute daily limit. The native Kotlin service polling every 2 seconds will detect when YouTube's daily usage crosses this threshold and immediately show the overlay nudge."

**Backup:** Screenshot of Settings → App Categories screen with the limit dialog open.

---

### Step 4 — Trigger the Overlay (live) (1:40–2:10)

**What to show:** If you set a 1-minute limit on an app you already used today, open the app — the overlay should appear within 2 seconds.

**Say:** "The native Android service detected the limit was exceeded and is now displaying the WindowManager overlay. It shows a psychology-framed message — this one is using the 'loss' framing — and auto-dismisses in 4 seconds. Tapping 'Switch to Productive App' would launch a productive alternative."

**Backup:** Pre-recorded screen recording of overlay appearing, or a screenshot of the dark overlay card.

---

### Step 5 — Focus Timer (2:10–2:40)

**What to show:** Tap to Focus Session tab. Select 25-minute preset. Press Start.

**Say:** "While a focus session is running, all distraction alerts are automatically suppressed. The Pomodoro session is saved to the focus_sessions table when it completes. Completed session minutes count toward the 35% focus component of the productivity score."

**Backup:** Screenshot of Focus Session screen with timer running.

---

### Step 6 — Privacy Proof Screen (2:40–3:10)

**What to show:** Settings tab → scroll to Privacy section → tap "Network-Proof Verification".

**Say:** "This screen shows four live verifiable assertions about the app's privacy. The most important: INTERNET permission — NOT DECLARED. Without this permission, Android's kernel blocks all outbound TCP/UDP connections at the OS level. Your usage data physically cannot leave this device. There is no server, no account, no cloud sync."

**Backup:** Screenshot of NetworkProofScreen showing all 4 green assertions.

---

### Step 7 — Insights Screen (3:10–3:30)

**What to show:** Tap Insights tab.

**Say:** "The Insights screen shows your productivity streak — consecutive days with a score of 60 or above — completed focus sessions, and today's distraction versus productive minutes. This data is all computed locally from the SQLite database."

**Backup:** Screenshot of Insights screen.

---

## Part 2 — Fallback Plan (if live demo fails)

### Priority fallback screens to show as screenshots:

| Priority | Screen | What it proves |
|---|---|---|
| 1 | NetworkProofScreen | Privacy claim — most impactful single screen |
| 2 | Dashboard (populated) | Core value: working AI + charts |
| 3 | Overlay screenshot | Real-time nudge capability |
| 4 | Settings — App Categories | Classification + limit system |
| 5 | Focus Timer | Complete Pomodoro feature |

### If APK won't install or permission can't be granted:
- Show the `AndroidManifest.xml` source code directly — point to the absent INTERNET permission
- Show `decision_tree_engine.dart` — walk through the if/else tree logic
- Show `UsageMonitorService.kt` — walk through the 2-second polling loop

---

## Part 3 — Q&A Preparation (20 Questions)

---

### Q1: Why a decision tree and not a neural network?

**Answer:** A decision tree was the correct choice for three reasons. First, interpretability: every prediction can be traced to a specific rule — which is essential for a behaviour-change app where users need to trust and understand why they are being nudged. Second, zero inference overhead: the tree compiles to a 40-line Dart function with no model loading, no tensor operations, and microsecond execution. Third, scale: with 5 features and 3 output classes on a 2,500-sample synthetic dataset, a neural network would be massively over-parameterised and would not generalise better. The decision tree is not a compromise — it is the right tool for this problem.

---

### Q2: How accurate is the model?

**Answer:** [NOT VERIFIED — the training script could not be executed during this documentation session. Run `python3 ml_training/train_decision_tree.py` to get the real numbers before presenting.]

What I can say from the code: the training script outputs Train Accuracy, Test Accuracy, and a per-class classification report. Because the dataset is **synthetically generated using the same rules the tree is trying to learn**, test accuracy is expected to be very high (likely > 95%). However, this does not reflect real-world accuracy on actual user behaviour, which has not been measured. I will be transparent about this limitation if asked.

---

### Q3: Is the training data real user data?

**Answer:** No — and this is by design. The training dataset is **synthetically generated** by `train_decision_tree.py` using `numpy.random` with a fixed seed (`np.random.seed(42)`). Labels are assigned by the same behavioural rules the tree is learning — for example, "label = Distraction Alert if category_code == 2 and (rolling_2h >= 2400 or duration >= 3600)". This avoids any privacy risk during development but means the model has not been validated on real user behaviour.

---

### Q4: How do you handle battery usage?

**Answer:** The app uses two complementary strategies to minimise battery impact. The Dart background isolate runs every 15 minutes — well within Android's Doze-mode exemptions for foreground services. The Kotlin `UsageMonitorService` polls every 2 seconds but only calls `usageStatsManager.queryEvents()` over a 5-second window — a very lightweight system call. The WAKE_LOCK permission keeps the CPU awake only during active polling; between polls the CPU is free to sleep. The foreground service shows a persistent (low-importance) notification, which is the standard Android pattern for persistent background work.

No battery benchmarks were performed — [NOT VERIFIED].

---

### Q5: What if the user denies permissions?

**Answer:** The app handles all permission states gracefully. If `PACKAGE_USAGE_STATS` is denied, `UsageCollectorService.collectAndSaveLogs()` returns an empty list immediately — the app continues to run but with no data. If `SYSTEM_ALERT_WINDOW` is denied, `showNudgeOverlay()` returns false and the app falls back to notifications only. If `POST_NOTIFICATIONS` is denied, `flutter_local_notifications` silently fails — no crash. The `PermissionScreen` guides users through both main permissions and re-checks them via `WidgetsBindingObserver.didChangeAppLifecycleState()` when the user returns from Settings.

---

### Q6: How is the app different from Digital Wellbeing?

**Answer:** Three key differences. First: privacy — this app has no INTERNET permission; Digital Wellbeing is a Google product connected to your Google account. Second: AI — this app uses a trained decision tree to detect patterns; Digital Wellbeing uses a simple timer. Third: intervention — this app shows a full-screen WindowManager overlay with psychology-framed messages; Digital Wellbeing greys out the app icon. See the comparison table in `04_comparison.md` for the full side-by-side.

---

### Q7: Why Flutter and not a purely native Android app?

**Answer:** Flutter gives us a rich, cross-platform UI layer in Dart while still allowing direct native Android API access through MethodChannel. All the parts that require native Android APIs — `UsageStatsManager`, `WindowManager`, `ApplicationInfo.category` — are implemented in Kotlin. Flutter handles the UI, repositories, AI engine, and background service logic. This separation is clean: Kotlin owns the Android-specific APIs; Dart owns everything that can be portable.

---

### Q8: How does the background service survive being closed?

**Answer:** The `flutter_background_service` package configures the Dart isolate as an Android foreground service (`isForegroundMode: true`). A foreground service displays a persistent notification and cannot be killed by the system's memory manager — only by the user or the app itself. The service is configured with `autoStart: true`, so it restarts on device boot. The `UsageMonitorService.kt` uses `START_STICKY` return value, which asks Android to restart it if it is killed.

---

### Q9: What is the QUERY_ALL_PACKAGES permission for?

**Answer:** Without this permission, the `PackageManager.getLaunchIntentForPackage()` call returns null for many apps in Android 11+, due to package visibility restrictions. We need to call this method for two purposes: (1) to filter out system packages that have no launcher intent, and (2) to resolve human-readable app labels from package names. The permission is declared with `tools:ignore="QueryAllPackagesPermission"` to acknowledge the Play Store review requirement.

---

### Q10: Can the user customise what counts as "distracting"?

**Answer:** Yes, fully. The `settings_screen.dart` shows every app in `app_categories` with a search bar. Tapping any app opens `CategoryPickerDialog` which allows the user to set the category to productive, neutral, or distracting. This updates the `app_categories` table with `is_custom = 1`. Custom overrides are never reset by the auto-classification pipeline — `insertAutoCategoryIfAbsent()` uses `ConflictAlgorithm.ignore`, which preserves existing entries.

---

### Q11: How does the app know which app is in the foreground right now?

**Answer:** `UsageMonitorService.kt` calls `UsageStatsManager.queryEvents()` over the last 5 seconds every 2 seconds. It scans for the most recent `MOVE_TO_FOREGROUND` event and tracks the last known foreground package name. When the package changes, `onAppForegrounded(pkg)` is called, which looks up the limit and usage total and fires the alert if needed.

---

### Q12: Is there any data validation or error handling?

**Answer:** Yes. The `UNIQUE INDEX idx_usage_unique (package_name, start_time)` prevents duplicate rows. `ConflictAlgorithm.ignore` is used on all INSERT calls that might conflict. The background service wraps each operation in try/catch blocks and continues on failure. The Kotlin service wraps its DB access in try/finally to guarantee the database is closed even on exception. The notification service has a `_shouldShow()` gate that gracefully returns false on any failure.

---

### Q13: What happens when the 90-day retention window is reached?

**Answer:** `RetentionPolicy.runPruneIfNeeded()` is called every 96 background ticks (approximately once per 24 hours). It checks whether the configured retention days have elapsed and calls `UsageRepository.pruneLogsOlderThan(age: Duration(days: option.days))`, which runs a `DELETE FROM usage_logs WHERE start_time < ?` query. The last prune timestamp is saved in the `preferences` table so the prune is never run more than once per 24 hours.

---

### Q14: How does the productivity streak work?

**Answer:** `UsageRepository.getProductivityStreak()` iterates backward from today over up to 30 days. For each day, it fetches logs, computes the composite score using `ProductivityScoreCalculator`, and checks whether it is >= 60 (the `ScoreWeights.good` threshold). It counts consecutive days meeting this threshold and breaks on the first failure.

---

### Q15: What is the `rule_based_engine.dart` and why isn't it being used?

**Answer:** `RuleBasedEngine` is a legacy implementation of the same `RoutineEngine` interface. It uses simple threshold rules: distraction alert if 2h rolling usage >= 40 minutes; routine reminder if the same hour slot is used 3+ days in 7. It was an earlier version before the ML model was trained. The `background_service.dart` was updated to use `DecisionTreeEngine` instead. The `RuleBasedEngine` is kept in the codebase as a fallback and for comparison purposes — the decision tree was trained to approximate and improve on these exact rules.

---

### Q16: Can the app tell which content you were looking at — not just which app?

**Answer:** No. The app only accesses `UsageStatsManager`, which reports package names and session timestamps — not content, URLs, keystrokes, or any in-app activity. This is an Android security boundary; no app can read what you are doing inside another app. The app is intentionally designed around this boundary — it is a feature, not a limitation, for a privacy-first product.

---

### Q17: How do the psychology nudge messages work technically?

**Answer:** `UsageCollectorService.getRandomPsychologyNudge()` returns one of 4 map objects, each with a `type` string and a `message` template string with `%s` for the app name. The selection is random by default but can be overridden with a type string — for example, `background_service.dart` forces the `loss` type for limit-exceeded alerts. The Kotlin service has a parallel list (`NUDGE_MESSAGES`) using `Random.nextInt(NUDGE_MESSAGES.size)` for its full-screen overlay — the two implementations are independent.

---

### Q18: Why is the `routines` table empty?

**Answer:** The `routines` table was designed as a persistence layer for detected routine patterns — once the AI fires a Routine Reminder, the intent was to also write a record to `routines` for long-term tracking and trend analysis. This was scaffolded but not implemented before the submission deadline. Currently, all alerts (including routine reminders) go to `notifications_log` instead. This is an honest limitation — acknowledged in the audit.

---

### Q19: How does the overlay not violate Android 12+ restrictions on background overlays?

**Answer:** Android 12+ restricts `TYPE_APPLICATION_OVERLAY` windows from appearing over certain types of content, but still allows them for apps that have been granted `SYSTEM_ALERT_WINDOW`. The code explicitly handles the API version split: on Android O (API 26) and above it uses `TYPE_APPLICATION_OVERLAY`; on older versions it uses the deprecated `TYPE_PHONE`. The `SYSTEM_ALERT_WINDOW` permission must be granted by the user from the Special App Access settings page — it cannot be silently granted.

---

### Q20: What are the three biggest weaknesses of this project?

**Answer:** I am glad to be direct about this.

1. **Synthetic training data.** The model has never seen real user behaviour. The "high accuracy" on test data is circular — the test set is generated by the same rules as the training set. Real-world validation is missing.

2. **Background service reliability on aggressive OEMs.** On Xiaomi, Huawei, and some Samsung devices, OEM battery optimisation aggressively kills background services. The `START_STICKY` flag and foreground mode help but are not guaranteed. A user on such a device may not receive timely alerts.

3. **Two incomplete features.** The `routines` table is never written to, and the `emotional_logs` table has no active UI path. These are scaffolded features that did not reach completion — presenting them as working would be inaccurate.
