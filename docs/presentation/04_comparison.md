# 04 – Comparison and Unique Value
**AI Routine Assistant** | Presentation Preparation Document

---

## Verified Facts (confirmed directly in code)

- All features attributed to this app are confirmed working in the code audit (01_project_audit.md)
- Competitor feature claims are based on publicly known capabilities; they are not verified from competitors' source code
- [FUTURE] items are scaffolded in code but not yet functional (confirmed in audit)
- No competitor feature was invented or exaggerated for this comparison

---

## 1. Comparison Table

| Feature | **AI Routine Assistant** (this app) | Digital Wellbeing (Google) | StayFree | Opal | One Sec |
|---|---|---|---|---|---|
| **On-device only (no cloud)** | ✅ Yes — INTERNET permission absent from production build | ❌ Usage data sent to Google dashboard | ❌ Syncs data to cloud | ❌ Account + cloud required | ❌ Cloud sync required |
| **AI / ML-based alert detection** | ✅ Depth-6 scikit-learn decision tree — 5 features, 3 classes | ❌ Rule-based app timer only | ❌ Rule-based app timer | ❌ Scheduled blocking only | ❌ Single-tap friction only |
| **Routine pattern recognition** | ✅ Detects 3+ day consistent hour-slot usage patterns | ❌ No pattern detection | ❌ No pattern detection | ❌ No pattern detection | ❌ No pattern detection |
| **Real-time full-screen overlay nudge** | ✅ WindowManager overlay, auto-dismiss 4 s, 4 psychology frames | ❌ | ❌ | ❌ | ✅ Brief friction screen (1 type) |
| **Configurable per-app daily limits** | ✅ Stored in SQLite; enforced every 2 s by native service | ✅ App timer (hard block) | ✅ App timer | ✅ Scheduled block | ❌ |
| **Category-level time limits** | ✅ Distracting-category default 120 min; user-configurable | ❌ | ✅ | ❌ | ❌ |
| **Pomodoro focus timer** | ✅ 4 presets (15/25/45/60 min); suppresses distraction alerts | ❌ | ❌ | ❌ | ❌ |
| **Psychology-based nudge messages** | ✅ 4 types: loss / identity / streak / implementation | ❌ | ❌ | Partial (motivational) | Partial (simple pause) |
| **Productivity score (composite)** | ✅ 0–100: distraction ratio 45% + focus 35% + routine 20% | ✅ Screen time minutes only | ✅ Time stats | ❌ | ❌ |
| **7-day trend chart** | ✅ Bar chart via fl_chart | ✅ | ✅ | ❌ | ❌ |
| **App category classification** | ✅ Seed + Android API + user override | Partial (Google's own apps) | ✅ | ✅ | ❌ |
| **Configurable quiet hours** | ✅ Any start/end hour including overnight | ✅ | ✅ | ✅ | ❌ |
| **Per-type notification muting** | ✅ Separate mute for distraction / routine alerts | ✅ | Partial | ✅ | ❌ |
| **Max alerts per day cap** | ✅ Default 20; user-configurable | ❌ | ❌ | ❌ | ❌ |
| **Weekly summary notification** | ✅ Opt-in, 7-day trend label (Improving/Steady/Declining) | ✅ | ✅ | ❌ | ❌ |
| **Data retention control** | ✅ 30/60/90 days or unlimited | ❌ | Partial | ❌ | ❌ |
| **Local data export (JSON)** | ✅ All tables, no network | ❌ | ❌ | ❌ | ❌ |
| **In-app privacy proof screen** | ✅ 4 live assertions; INTERNET shown as NOT DECLARED | ❌ | ❌ | ❌ | ❌ |
| **Interpretable AI (traceable decisions)** | ✅ Each alert stores decisionRule + treeDepth in JSON | ❌ (black box) | N/A | N/A | N/A |
| **Emotional check-in after sessions** | [FUTURE] Scaffold code exists, not wired | ❌ | ❌ | ❌ | ❌ |
| **Routine persistence (routines table)** | [FUTURE] Table created, writes not implemented | ❌ | ❌ | ❌ | ❌ |

---

## 2. Five Unique Selling Points

Each USP is tied directly to a working code artefact.

---

### USP 1 — Zero-Network, Verifiable Privacy

**What it is:** The app physically cannot make a network connection. Android blocks all outbound sockets without `INTERNET` permission. This app does not declare it in its production manifest.

**Code evidence:**
- `android/app/src/main/AndroidManifest.xml` — 53 lines; `INTERNET` is absent
- `android/app/src/debug/AndroidManifest.xml` — presence of `INTERNET` is documented with a comment saying this is Flutter hot-reload only
- `lib/presentation/screens/network_proof_screen.dart` — in-app screen displaying 4 live verifiable assertions
- `lib/services/security_service.dart` — local-only JSON export of all DB tables

**Why it's unique:** No other popular screen-time app on Android has this guarantee. All major alternatives have cloud accounts and network sync.

---

### USP 2 — On-Device Machine Learning (Interpretable AI)

**What it is:** A scikit-learn decision tree trained offline on 2,500 samples and compiled into a 40-line Dart if/else function. Every prediction is fully traceable — the exact rule that fired is stored in the notification's `trigger_conditions` JSON.

**Code evidence:**
- `ml_training/train_decision_tree.py` — scikit-learn training pipeline with metrics output
- `ml_training/decision_tree_model.json` — exported tree structure (149 lines)
- `lib/ai/decision_tree_engine.dart:118-168` — `_predictDecisionTree()` Dart compilation
- `lib/domain/models/routine_alert.dart:72-83` — `triggerConditions` stores `decisionRule`, `treeDepth: 6`, feature values

**Why it's unique:** The tree runs with zero file-loading, zero inference latency, and full interpretability. A user or auditor can open any alert and see exactly which condition triggered it.

---

### USP 3 — Dual-Speed Monitoring: Pattern Analysis + Real-Time Enforcement

**What it is:** Two independent monitoring paths running at different speeds serve different purposes. A Dart isolate does AI pattern analysis every 15 minutes. A Kotlin native service enforces hard limits every 2 seconds.

**Code evidence:**
- `lib/services/background_service.dart:71` — `Timer.periodic(const Duration(minutes: 15), ...)`
- `android/app/src/main/kotlin/.../UsageMonitorService.kt:50` — `private const val POLL_INTERVAL_MS = 2000L`
- `UsageMonitorService.kt:128-167` — `onAppForegrounded()` reads SQLite directly (WAL-safe, read-only), computes today's usage, fires overlay if limit exceeded
- Background service isolate communicates via MethodChannel; native service reads DB directly to avoid MethodChannel latency in background

**Why it's unique:** Most apps only have one monitoring path. The two-speed design means AI-level pattern intelligence and sub-2-second limit response coexist without competing.

---

### USP 4 — Four-Type Psychology-Framed Behavioral Nudges

**What it is:** Instead of a generic "You've hit your limit" message, the app selects from 4 psychology-backed message types, each designed to engage a different motivational mechanism.

**Code evidence:**
- `lib/services/usage_collector_service.dart:107-134` — `getRandomPsychologyNudge()` — 4 nudge objects with `type` and `message`
- `android/app/src/main/kotlin/.../UsageMonitorService.kt:53-58` — `NUDGE_MESSAGES` list in Kotlin with the same 4 types
- Types: `loss` (loss aversion), `identity` (identity-based habits), `implementation` (implementation intentions), `streak` (habit streaks)
- `background_service.dart:163` — `overrideNudgeType: 'loss'` used for limit-exceeded alerts

**Why it's unique:** This is the only screen-time app the author is aware of that rotates multiple psychology-principle-based messages rather than a single generic alert text.

---

### USP 5 — Composite Productivity Score with Three Independent Signals

**What it is:** A 0–100 productivity score computed from three independently measured data sources, with externally configurable weights.

**Code evidence:**
- `lib/core/constants/score_weights.dart` — `distractionRatio = 0.45`, `focusTime = 0.35`, `routineAdherence = 0.20`, `targetFocusMinutes = 120.0`
- `lib/domain/services/productivity_score_calculator.dart:16-48` — `calculateCompositeScore()` implementation
- Signal 1: distraction ratio from `usage_logs` (productive + distracting seconds)
- Signal 2: completed focus minutes from `focus_sessions` table
- Signal 3: routine adherence percentage (passed from AI engine output)
- Score thresholds: `exceptional >= 80`, `good >= 60`, `moderate >= 40`

**Why it's unique:** Other apps show raw screen-time minutes. This score integrates three behavioural signals — how much you were distracted, how much intentional focus time you completed, and how consistent your good routines were — into a single actionable number.
