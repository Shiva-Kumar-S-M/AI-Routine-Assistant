# 03 – Slide Content
**AI Routine Assistant** | Presentation Preparation Document

---

## Verified Facts (confirmed directly in code)

- All feature bullet points below are backed by working code confirmed in the audit (01_project_audit.md)
- Statistics cited are actual values from the codebase, not estimated
- Items marked [FUTURE] have no working code and should be clearly labelled as planned

---

## Slide-by-Slide Deck

---

### Slide 1 — Title

**Title:** AI Routine Assistant: On-Device Behavioural Screen-Time Intelligence

**Bullets:**
- Privacy-first: 100% on-device, zero cloud uploads
- Flutter + Kotlin + Python-trained Decision Tree
- Real-time nudges, habit detection, and Pomodoro focus
- Android-native usage tracking via UsageStatsManager

**Suggested Visual:** App logo/icon centred on a dark background with a subtle phone screen graphic showing the dashboard

**Speaker Notes:**
Good morning / afternoon. I'll be presenting the AI Routine Assistant — an Android app that tracks your screen time, learns your digital habits, and nudges you to stay focused. The entire AI pipeline, all data, and all computation run on your device. Nothing leaves your phone.

---

### Slide 2 — Problem Statement

**Title:** The Screen-Time Problem

**Bullets:**
- Average smartphone usage: 4–6 hours per day (general public data)
- Most of that time is habitual and unconscious, not intentional
- Distraction apps exploit behavioral psychology to maximise engagement
- Existing tools only show numbers — they don't intervene

**Suggested Visual:** Diagram showing person with phone, clock ticking away, with social media app icons circling around

**Speaker Notes:**
The core problem is not awareness — most people know they use their phones too much. The problem is the absence of real-time, contextually intelligent intervention. Showing a weekly report on Sunday does not stop the Tuesday evening Instagram spiral.

---

### Slide 3 — Motivation and Gap

**Title:** What Existing Tools Miss

**Bullets:**
- Digital Wellbeing, StayFree: post-hoc reports, no AI detection
- Opal, One Sec: app blocking only, no on-device ML
- All major tools send usage data to the cloud
- None combine routine detection + real-time overlay + on-device AI

**Suggested Visual:** Comparison table (see Slide 10 / `04_comparison.md`) with the gap column highlighted

**Speaker Notes:**
The gap is not in data collection — it is in intelligence and privacy. This app is the first (to my knowledge) to combine a locally trained ML model, a WindowManager overlay nudge, and full privacy through zero network permissions — all on one Android device.

---

### Slide 4 — Objectives

**Title:** Project Objectives

**Bullets:**
- Collect and store screen-time sessions 100% on-device
- Classify app usage as productive, distracting, or neutral automatically
- Detect behavioural patterns using a trained decision tree classifier
- Deliver real-time behavioral nudges via native overlay when limits are exceeded
- Provide an honest privacy guarantee with no network access

**Suggested Visual:** 5 numbered circles or a timeline arrow showing the objectives in sequence

**Speaker Notes:**
The objectives drove every architectural decision. On-device-only meant no cloud SDK could be used. Real-time nudges required a native Kotlin service polling every 2 seconds. The privacy guarantee meant the INTERNET permission is absent from the production app manifest entirely.

---

### Slide 5 — Proposed Solution

**Title:** The AI Routine Assistant Approach

**Bullets:**
- UsageStatsManager → Kotlin → MethodChannel → Dart: a clean data pipeline
- scikit-learn decision tree trained offline, compiled to Dart for zero-overhead inference
- Two parallel alert paths: 15-minute batch analysis + 2-second real-time monitoring
- Psychology-framed nudge messages (loss / identity / streak / implementation)
- SQLite-only storage: 7 purpose-built tables, retention configurable up to 90 days

**Suggested Visual:** High-level architecture overview (see Mermaid diagram in `06_diagrams.md`, Diagram 1)

**Speaker Notes:**
The key design insight is the two-speed monitoring strategy. The Dart background service handles the AI pattern analysis every 15 minutes. The native Kotlin service handles the hard limit enforcement every 2 seconds. This gives us both intelligent pattern recognition and immediate real-time response.

---

### Slide 6 — Key Features

**Title:** What the App Does

**Bullets:**
- Per-app and per-category daily time limits with instant overlay nudge
- 3-class AI: No Alert / Distraction Alert / Routine Reminder (depth-6 decision tree)
- Pomodoro focus timer (15/25/45/60 min) with automatic distraction-alert suppression
- Productivity score (0–100): 45% distraction ratio + 35% focus time + 20% routine adherence
- Configurable quiet hours, per-type mute, and 20-alerts/day cap

**Suggested Visual:** 4-panel phone screenshot grid: Dashboard, Focus Timer, Settings, Alert overlay

**Speaker Notes:**
Every feature listed here is verified working in code. The productivity score is not an arbitrary number — it is a weighted composite of three independently measured signals, all computed from local data.

---

### Slide 7 — System Architecture

**Title:** System Architecture

**Bullets:**
- 3-layer stack: Kotlin native / Flutter Dart / SQLite
- MethodChannel bridges the Kotlin and Dart layers (named channel)
- flutter_background_service runs a Dart isolate as a foreground service
- UsageMonitorService.kt runs as a separate Android Service (independent lifecycle)
- All data stays in the Android app-private SQLite sandbox

**Suggested Visual:** Three-column architecture diagram (see Mermaid Diagram 1 in `06_diagrams.md`)

**Speaker Notes:**
The architecture deliberately avoids a server layer. Every box you see here runs on the phone. The MethodChannel is the only communication bridge — and it only carries data within the device, between the Kotlin and Dart runtimes in the same process.

---

### Slide 8 — Data Flow

**Title:** How Data Moves

**Bullets:**
- UsageStatsManager events → Kotlin session builder → MethodChannel → Dart UsageLog objects
- Sessions merged if gap < 30 seconds; launchers and system apps filtered out
- Batch INSERT OR IGNORE into SQLite (unique index prevents duplicates)
- AI engine reads from DB; output written back to notifications_log table
- Dashboard queries read from the same DB: zero network at any point

**Suggested Visual:** Linear data-flow diagram (see Mermaid Diagram 2 in `06_diagrams.md`)

**Speaker Notes:**
Notice the direction of data: always inward, never outward. Data originates in Android's UsageStatsManager, moves through Kotlin, through the MethodChannel, into Dart, into SQLite. It never goes up to a server. The AI reads from SQLite and writes alerts back into the same local database.

---

### Slide 9 — AI / ML Approach

**Title:** The On-Device Decision Tree

**Bullets:**
- 5 input features: hour of day, session duration, category code, 2h rolling distraction, days used at same hour slot
- 3 output classes: No Alert (0), Distraction Alert (1), Routine Reminder (2)
- max_depth=6 trained offline with scikit-learn on 2,500 synthetic samples
- Tree compiled to 40-line Dart if/else — zero JSON parsing, zero file I/O at inference
- Psychology nudge type matched to alert class (loss framing for limit exceeded)

**Suggested Visual:** Decision tree diagram (first 2–3 branches drawn visually as a tree)

**Speaker Notes:**
A decision tree was chosen because it is fully interpretable. You can look at any prediction and trace exactly which 3–4 conditions were true. For a privacy-sensitive app, this interpretability matters — users can understand and trust the logic. The tree is also microseconds to evaluate, with no model loading cost at runtime.

---

### Slide 10 — Tech Stack

**Title:** Technology Stack

**Bullets:**
- Flutter / Dart: 9 screens, 6 widgets, 4 repositories, 4 services
- Kotlin: 2 files — MainActivity (MethodChannel) + UsageMonitorService (polling)
- Python 3 + scikit-learn: offline training pipeline (one-time)
- SQLite via sqflite: 7 tables, ~12 preference keys, UNIQUE index on usage
- flutter_local_notifications + flutter_background_service for persistence

**Suggested Visual:** Tech stack logo grid (Flutter, Android, Python, SQLite)

**Speaker Notes:**
The stack is deliberately minimal. No cloud SDK, no analytics library, no database server. Flutter gives us a rich cross-platform UI. Kotlin gives us direct Android API access that Dart cannot provide. Python gave us the model, which was then hard-coded into Dart so there is no Python dependency at runtime.

---

### Slide 11 — Database Design

**Title:** Database Design (7 Tables)

**Bullets:**
- usage_logs: every app session (package, start, end, duration) — unique-indexed
- app_categories: 3-bucket classification with user-override flag
- notifications_log: full audit trail with JSON trigger conditions
- preferences: all user settings as key-value (limits, quiet hours, caps)
- focus_sessions: Pomodoro sessions with completion flag
- emotional_logs [FUTURE]: post-session mood check-in (scaffold, not yet wired)
- routines [FUTURE]: detected routine persistence (table created, not written)

**Suggested Visual:** ER diagram (see Mermaid Diagram 4 in `06_diagrams.md`)

**Speaker Notes:**
Seven tables for a privacy-first app might seem like a lot, but each serves a clear purpose. The unique index on usage_logs is a particularly important detail — it means the app can safely re-query the last 24 hours on every background tick without ever creating duplicate rows.

---

### Slide 12 — Implementation Highlights

**Title:** Technical Challenges Solved

**Bullets:**
- ForegroundServiceDidNotStartInTimeException fixed: isolate checks `isRunning()` before `startService()`
- Background MethodChannel limitation: UsageMonitorService reads SQLite directly (bypass)
- App-name resolution: two-pass SQL backfill for rows where app_name = package_name
- 30-second session merge: avoids counting rapid screen-off/on as separate sessions
- Notification 1-minute cooldown per package in Kotlin (prevents alert spam)

**Suggested Visual:** Code snippets for 1–2 of these fixes in side-by-side before/after format

**Speaker Notes:**
These were real bugs found and fixed during development. The foreground service crash, for example, is a known Flutter background-service edge case. The fix — checking whether the service is already running before calling startService — is documented in the code with a comment explaining exactly why it is necessary.

---

### Slide 13 — Results and Demo

**Title:** Live Demo

**Bullets:**
- Live: grant permissions → dashboard loads real usage data
- Live: set a 1-minute limit on any installed app → trigger overlay in demo
- Live: start a 25-min Pomodoro → distraction alerts suppressed
- AI audit trail: expand any alert tile to see which decision rule fired
- Privacy proof screen: 4 live assertions including "INTERNET: NOT DECLARED"

**Suggested Visual:** Live phone demo (or screenshots — see `05_demo_and_qa.md` fallback plan)

**Speaker Notes:**
I will now demonstrate the app live. If any step does not work as expected I have fallback screenshots ready. The most impressive single moment to show is opening the privacy screen — it is a verifiable, in-app proof that no network permission is declared.

---

### Slide 14 — Privacy and Security

**Title:** Privacy Guarantee

**Bullets:**
- INTERNET permission absent from production AndroidManifest.xml — verified in code
- No HTTP client library, no analytics SDK (no Firebase, no Mixpanel, no AdMob)
- All data sandboxed in app-private SQLite — unreadable by other apps
- Local JSON export via SecurityService — user owns their data
- Configurable data retention: 30/60/90 days or unlimited

**Suggested Visual:** Shield icon with the 4 assertions from NetworkProofScreen displayed

**Speaker Notes:**
Privacy is not a marketing claim in this app — it is an architectural constraint enforced at the OS level. Android cannot make an outbound TCP connection without the INTERNET permission. Since we do not declare it, zero data can leave the device, regardless of what code runs.

---

### Slide 15 — Limitations and Challenges

**Title:** Honest Limitations

**Bullets:**
- Decision tree trained on synthetic data — real-world accuracy [NOT VERIFIED on real users]
- Background service may be killed by aggressive Android battery optimisation on some OEMs
- PACKAGE_USAGE_STATS and SYSTEM_ALERT_WINDOW require manual settings-page grants (cannot be runtime-requested)
- routines table and emotional check-in are scaffold features — not yet functional
- flutter_riverpod imported but not yet wired into the state management layer

**Suggested Visual:** Table listing limitation + mitigation strategy

**Speaker Notes:**
I want to be transparent about what is not yet complete. The synthetic training data is the most significant limitation — the model learns rules that perfectly match its own training labels, so test accuracy looks high, but that does not tell us how it performs on real, messy user patterns. Real-world evaluation would require user testing.

---

### Slide 16 — Future Scope

**Title:** Future Work

**Bullets:**
- Real user data collection (opt-in, on-device differential privacy) for model retraining
- Wire emotional_logs table to post-session check-in UI
- Implement Riverpod state management properly for reactive UI
- Cross-day routine persistence (write to routines table)
- iOS port: replicate UsageStatsManager equivalent via Screen Time API

**Suggested Visual:** Roadmap timeline with the 5 items

**Speaker Notes:**
The strongest next step is replacing synthetic training data with real opt-in user patterns. A federated or on-device incremental learning approach would let the model adapt to each individual's unique behaviour without any data ever leaving the phone — preserving the privacy guarantee.

---

### Slide 17 — Conclusion

**Title:** Summary

**Bullets:**
- Fully working on-device screen-time intelligence app for Android
- Privacy-first by architecture: INTERNET permission not declared in production
- AI engine: scikit-learn decision tree → compiled Dart (zero loading cost)
- Dual-speed alert system: 15-min pattern analysis + 2-second limit enforcement
- Configurable, privacy-respecting, open for extension

**Suggested Visual:** Recap architecture diagram highlighting the zero-network boundary

**Speaker Notes:**
To summarise: this project demonstrates that useful, personalised AI-driven behaviour change can be delivered entirely on-device. The app is not a proof-of-concept — it is a working system with production-quality concerns addressed: deduplication, notification gating, background service stability, and data retention.

---

### Slide 18 — Thank You / Q&A

**Title:** Thank You

**Bullets:**
- Source code and ML training script available for review
- Privacy proof verifiable live on any Android device with the APK
- Decision tree logic is fully interpretable — trace any alert to exact conditions
- Prepared for questions on model choice, battery usage, permissions, and limitations

**Suggested Visual:** QR code linking to repo (or APK), email/contact info

**Speaker Notes:**
Thank you for your attention. I am happy to walk through any part of the code, demonstrate the app, or explain any design decision in detail. Please feel free to ask the hardest questions first.
