package com.example.ai_routine_assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import kotlin.random.Random

/**
 * Native foreground service for real-time foreground-app monitoring and behavioral intervention.
 *
 * Runs a continuous 2-second UsageEvents poll loop. When an app on the distracting list
 * exceeds its daily time limit, it presents an inescapable full-screen WindowManager overlay
 * with psychological hook framing, usage metrics, and a friction countdown.
 */
class UsageMonitorService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var lastForegroundPackage: String? = null
    private var overlayView: View? = null
    private var overlayTargetPackage: String? = null
    private var countdownRunnable: Runnable? = null
    private var isForegroundStarted = false

    // Guards and state tracking
    private val shownForSession = mutableSetOf<String>()

    companion object {
        @Volatile
        var isServiceRunning = false
            private set

        private val packageSnoozeUntil = ConcurrentHashMap<String, Long>()

        fun snoozePackage(pkg: String, until: Long) {
            packageSnoozeUntil[pkg] = until
        }

        private const val POLL_INTERVAL_MS = 2000L
        private const val SERVICE_NOTIFICATION_ID = 991
        private const val NOTIFICATION_CHANNEL_ID = "monitoring_channel"
        private const val FOCUS_NUDGES_CHANNEL_ID = "focus_nudges_channel"
        private const val SNOOZE_DURATION_MS = 15 * 60 * 1000L // 15 minutes

        private val HOOK_TEMPLATES = listOf(
            "loss" to "You've already spent %s on %s today. That's %s of focused energy you won't get back.",
            "future_self" to "Is opening %s right now who you want to be? The version of you that achieves your goals would close this.",
            "streak" to "You've built discipline today with a %d-day streak. Don't let an impulse session break your momentum.",
            "goal" to "Every minute spent scrolling %s is borrowed from what truly matters to you today.",
            "social_proof" to "High achievers ruthlessly guard their focus. Reclaim your time right now."
        )

        private var lastWarningHookIndex = -1

        private val EARLY_WARNING_HOOKS = listOf(
            "loss" to { app: String, _: Int, left: Int, _: Int ->
                "$left minutes left on $app. Spend them like they matter."
            },
            "future_self" to { app: String, _: Int, left: Int, _: Int ->
                "Future you is watching what you do in the next $left minutes on $app."
            },
            "goal" to { app: String, used: Int, _: Int, limit: Int ->
                "You've used $used of $limit mins on $app. Protect your remaining focus for what really matters."
            },
            "momentum" to { app: String, _: Int, left: Int, _: Int ->
                "You've held your focus all day. Don't trade it for $left more minutes of scrolling on $app."
            },
            "loss_urgency" to { app: String, _: Int, left: Int, _: Int ->
                "Only $left minutes remaining today on $app. When it runs out, the barrier drops."
            },
            "future_discipline" to { app: String, _: Int, left: Int, _: Int ->
                "Will spending your final $left minutes on $app move you closer to who you want to be?"
            },
            "momentum_streak" to { app: String, used: Int, _: Int, _: Int ->
                "You're at $used mins on $app. Pause now and keep your streak safe."
            },
            "high_achiever" to { app: String, _: Int, left: Int, _: Int ->
                "High achievers ruthlessly guard their focus. Wrap up $app with $left minutes to spare."
            }
        )
    }

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isServiceRunning) return
            checkForegroundApp()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    // ── Lifecycle ───────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        isServiceRunning = true
        startServiceInForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isServiceRunning = true
        if (!isForegroundStarted) {
            startServiceInForeground()
        }
        handler.removeCallbacks(pollRunnable)
        handler.post(pollRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        isServiceRunning = false
        isForegroundStarted = false
        handler.removeCallbacks(pollRunnable)
        hideOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Foreground Service Setup ────────────────────────────────────────────────

    private fun startServiceInForeground() {
        if (isForegroundStarted) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Monitoring",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Monitors focus and routine limits in the background"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
            }
            nm.createNotificationChannel(channel)

            val notification = Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("Focus Assistant")
                .setContentText("Focus Assistant is active")
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setVisibility(Notification.VISIBILITY_SECRET)
                .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // Android 14+ (API 34)
                startForeground(
                    SERVICE_NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(SERVICE_NOTIFICATION_ID, notification)
            }
            isForegroundStarted = true
        }
    }

    // ── Foreground Detection Loop ───────────────────────────────────────────────

    private fun checkForegroundApp() {
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return
            val now = System.currentTimeMillis()
            val events = usm.queryEvents(now - 5000, now)

            var latestPkg: String? = null
            var latestTs = 0L
            val event = UsageEvents.Event()

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND && event.timeStamp > latestTs) {
                    latestTs = event.timeStamp
                    latestPkg = event.packageName
                }
            }

            if (latestPkg != null) {
                // If user switched away from the app being overlaid, dismiss the overlay and reset session guard
                if (overlayTargetPackage != null && latestPkg != overlayTargetPackage) {
                    val prevPkg = overlayTargetPackage
                    hideOverlay()
                    if (prevPkg != null) {
                        shownForSession.remove(prevPkg)
                    }
                }

                if (latestPkg != lastForegroundPackage) {
                    val prev = lastForegroundPackage
                    lastForegroundPackage = latestPkg
                    if (prev != null && prev != latestPkg) {
                        shownForSession.remove(prev)
                    }
                    onAppForegrounded(latestPkg)
                }
            }
        } catch (_: Exception) {
            // Permission not granted or query failed — silently skip
        }
    }

    private fun onAppForegrounded(pkg: String) {
        // Skip our own app, system launchers, and packages without launch intent
        if (pkg == packageName) return
        if (pkg in UsageStatsHelper.EXCLUDED_PACKAGES) return
        try {
            if (packageManager.getLaunchIntentForPackage(pkg) == null) return
        } catch (_: Exception) { return }

        var db: SQLiteDatabase? = null
        try {
            val dbFile = getDatabasePath("ai_routine_assistant.db")
            if (!dbFile.exists()) return
            db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)

            // 1. Check category: must be "distracting"
            val category = queryString(
                db,
                "SELECT category FROM app_categories WHERE package_name = ?",
                arrayOf(pkg)
            ) ?: "neutral"

            if (category != "distracting") return

            // 2. Resolve configured limit
            var limitMins = queryString(
                db,
                "SELECT value FROM preferences WHERE key = ?",
                arrayOf("limit_pkg_$pkg")
            )?.toIntOrNull() ?: 0

            if (limitMins == 0) {
                limitMins = queryString(
                    db,
                    "SELECT value FROM preferences WHERE key = ?",
                    arrayOf("limit_cat_distracting")
                )?.toIntOrNull() ?: 120
            }
            if (limitMins <= 0) return

            // 3. Real-time usage calculation using event-pairing helper
            val usedSeconds = UsageStatsHelper.getTodayUsageSecondsForPackage(this, pkg)
            val usedMins = usedSeconds / 60

            if (usedMins >= limitMins) {
                // 4. Guards: check session guard and 15-minute snooze
                if (shownForSession.contains(pkg)) return

                val snoozeUntil = packageSnoozeUntil[pkg] ?: 0L
                if (System.currentTimeMillis() < snoozeUntil) return

                val streak = calculateProductivityStreak(db)
                val appName = UsageStatsHelper.getAppLabel(this, pkg)
                val hookPair = selectBestHook(db, pkg, usedMins, streak)

                if (hasOverlayPermission()) {
                    shownForSession.add(pkg)
                    showFullScreenOverlay(pkg, appName, usedMins, limitMins, streak, hookPair)
                }
            } else {
                // Check early warning threshold (default 80%)
                val thresholdPct = queryString(
                    db,
                    "SELECT value FROM preferences WHERE key = 'early_warning_threshold_pct'",
                    emptyArray()
                )?.toIntOrNull() ?: 80

                // Limits under 5 minutes: rounded down
                val warningMins = Math.max(1, (limitMins * thresholdPct) / 100)
                if (usedMins >= warningMins) {
                    val appName = UsageStatsHelper.getAppLabel(this, pkg)
                    checkAndSendEarlyWarningNotification(db, pkg, appName, usedMins, limitMins)
                }
            }
        } catch (_: Exception) {
            // DB or usage error — skip
        } finally {
            try { db?.close() } catch (_: Exception) {}
        }
    }

    // ── Full-Screen Overlay ─────────────────────────────────────────────────────

    private fun showFullScreenOverlay(
        pkg: String,
        appName: String,
        usedMins: Int,
        limitMins: Int,
        streak: Int,
        hookPair: Pair<String, String>
    ) {
        handler.post {
            hideOverlay()

            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            overlayTargetPackage = pkg

            val hookType = hookPair.first
            val template = hookPair.second

            val usedHours = usedMins / 60
            val usedRemMins = usedMins % 60
            val timeFormatted = if (usedHours > 0) "${usedHours}h ${usedRemMins}m" else "${usedMins}m"
            val overMins = usedMins - limitMins

            val hookMessage = when (hookType) {
                "loss" -> String.format(template, timeFormatted, appName, timeFormatted)
                "future_self" -> String.format(template, appName)
                "streak" -> String.format(template, if (streak > 0) streak else 1)
                "goal" -> String.format(template, appName)
                "social_proof" -> template
                else -> String.format("You've exceeded your daily limit for %s.", appName)
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }

            // Root scrim — pure black immersive backdrop (#0B0B0C)
            val root = LinearLayout(this@UsageMonitorService).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.parseColor("#FF0B0B0C"))
            }

            // Card container (#131314, 20dp corners, 1px #262628 border)
            val card = LinearLayout(this@UsageMonitorService).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dpToPx(24), dpToPx(28), dpToPx(24), dpToPx(24))
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#131314"))
                    cornerRadius = dpToPx(20).toFloat()
                    setStroke(dpToPx(1), Color.parseColor("#262628"))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    setMargins(dpToPx(20), 0, dpToPx(20), 0)
                }
            }

            // App Icon
            val appIcon = UsageStatsHelper.getAppIcon(this@UsageMonitorService, pkg)
            if (appIcon != null) {
                card.addView(ImageView(this@UsageMonitorService).apply {
                    setImageDrawable(appIcon)
                    layoutParams = LinearLayout.LayoutParams(dpToPx(48), dpToPx(48)).apply {
                        setMargins(0, 0, 0, dpToPx(12))
                    }
                })
            }

            // App Name Tracked Label
            card.addView(TextView(this@UsageMonitorService).apply {
                text = appName.uppercase()
                setTextColor(Color.parseColor("#8E8E93"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                letterSpacing = 0.12f
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dpToPx(6))
            })

            // Big clean numbers for time over limit
            card.addView(TextView(this@UsageMonitorService).apply {
                text = "+${overMins}m"
                setTextColor(Color.parseColor("#F5F5F5"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 44f)
                setTypeface(Typeface.create("sans-serif-light", Typeface.NORMAL))
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dpToPx(2))
            })

            // Subtitle Stat
            card.addView(TextView(this@UsageMonitorService).apply {
                text = "OVER DAILY LIMIT · $timeFormatted USED"
                setTextColor(Color.parseColor("#8E8E93"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
                letterSpacing = 0.1f
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dpToPx(18))
            })

            // Psychological Hook Message
            card.addView(TextView(this@UsageMonitorService).apply {
                text = hookMessage
                setTextColor(Color.parseColor("#F5F5F5"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setLineSpacing(dpToPx(3).toFloat(), 1.25f)
                gravity = Gravity.CENTER
                setPadding(dpToPx(6), 0, dpToPx(6), dpToPx(24))
            })

            // ── Action Buttons ──────────────────────────────────────────────────────

            val buttonContainer = LinearLayout(this@UsageMonitorService).apply {
                orientation = LinearLayout.VERTICAL
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            }

            // Button 1: "Take me back" (Primary — Solid White with Black text)
            val btnTakeBack = Button(this@UsageMonitorService).apply {
                text = "Take me back"
                setTextColor(Color.parseColor("#000000"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setTypeface(typeface, Typeface.BOLD)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#FFFFFF"))
                    cornerRadius = dpToPx(14).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dpToPx(48)
                ).apply {
                    setMargins(0, 0, 0, dpToPx(10))
                }
                setOnClickListener {
                    logIntervention(pkg, "turn_back", usedMins, limitMins, hookType)
                    hideOverlay()
                    // Navigate to Home Screen
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    startActivity(homeIntent)
                }
            }

            // Button 2: "Brain challenge instead" (Surface Raised)
            val btnBrainChallenge = Button(this@UsageMonitorService).apply {
                text = "Brain challenge instead"
                setTextColor(Color.parseColor("#F5F5F5"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                setTypeface(typeface, Typeface.BOLD)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#1A1A1C"))
                    cornerRadius = dpToPx(14).toFloat()
                    setStroke(dpToPx(1), Color.parseColor("#262628"))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dpToPx(46)
                ).apply {
                    setMargins(0, 0, 0, dpToPx(10))
                }
                setOnClickListener {
                    logIntervention(pkg, "brain_challenge", usedMins, limitMins, hookType)
                    hideOverlay()
                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                    if (launchIntent != null) {
                        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        launchIntent.putExtra("route", "math_sprint")
                        startActivity(launchIntent)
                    }
                }
            }

            // Button 3: "Continue anyway" (Friction Countdown, Outlined 1px)
            var countdownSeconds = 5
            val btnContinue = Button(this@UsageMonitorService).apply {
                text = "Pause: 5s"
                setTextColor(Color.parseColor("#48484A"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                isEnabled = false
                alpha = 0.6f
                background = GradientDrawable().apply {
                    setColor(Color.TRANSPARENT)
                    cornerRadius = dpToPx(14).toFloat()
                    setStroke(dpToPx(1), Color.parseColor("#262628"))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dpToPx(44)
                )
                setOnClickListener {
                    packageSnoozeUntil[pkg] = System.currentTimeMillis() + SNOOZE_DURATION_MS
                    logIntervention(pkg, "bypass", usedMins, limitMins, hookType)
                    hideOverlay()
                }
            }

            countdownRunnable = object : Runnable {
                override fun run() {
                    countdownSeconds--
                    if (countdownSeconds > 0) {
                        btnContinue.text = "Pause: ${countdownSeconds}s"
                        handler.postDelayed(this, 1000L)
                    } else {
                        btnContinue.text = "Continue anyway"
                        btnContinue.setTextColor(Color.parseColor("#F5F5F5"))
                        btnContinue.isEnabled = true
                        btnContinue.alpha = 1.0f
                    }
                }
            }
            handler.postDelayed(countdownRunnable!!, 1000L)

            buttonContainer.addView(btnTakeBack)
            buttonContainer.addView(btnBrainChallenge)
            buttonContainer.addView(btnContinue)

            card.addView(buttonContainer)
            root.addView(card)
            root.alpha = 0f
            overlayView = root

            try {
                wm.addView(overlayView, params)
                root.animate().alpha(1f).setDuration(250).start()
            } catch (_: Exception) {
                overlayView = null
                overlayTargetPackage = null
            }
        }
    }

    private fun hideOverlay() {
        countdownRunnable?.let { handler.removeCallbacks(it) }
        countdownRunnable = null

        val view = overlayView ?: return
        overlayView = null
        overlayTargetPackage = null
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(view)
        } catch (_: Exception) {}
    }

    // ── Intervention Logging ────────────────────────────────────────────────────

    private fun logIntervention(
        pkg: String,
        actionType: String,
        usedMins: Int,
        limitMins: Int,
        hookType: String
    ) {
        Thread {
            var db: SQLiteDatabase? = null
            try {
                val dbFile = getDatabasePath("ai_routine_assistant.db")
                if (!dbFile.exists()) return@Thread
                db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)

                val values = ContentValues().apply {
                    put("type", actionType)
                    put("package_name", pkg)
                    put("message", "Overlay action: $actionType (used: ${usedMins}m, limit: ${limitMins}m)")
                    put("timestamp", System.currentTimeMillis())
                    put(
                        "trigger_conditions",
                        """{"usedMins":$usedMins,"limitMins":$limitMins,"hook":"$hookType"}"""
                    )
                }
                db.insert("notifications_log", null, values)

                val feedback = ContentValues().apply {
                    put("package_name", pkg)
                    put("hook_type", hookType)
                    put("action", actionType)
                    put("timestamp", System.currentTimeMillis())
                }
                db.insert("hook_feedback", null, feedback)
            } catch (_: Exception) {
            } finally {
                try { db?.close() } catch (_: Exception) {}
            }
        }.start()
    }

    // ── Helpers ─────────────────────────────────────────────────────────────────

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true
    }

    private fun queryString(db: SQLiteDatabase, sql: String, args: Array<String>): String? {
        return db.rawQuery(sql, args).use { if (it.moveToFirst()) it.getString(0) else null }
    }

    private fun calculateProductivityStreak(db: SQLiteDatabase): Int {
        return try {
            val thirtyDaysAgo = System.currentTimeMillis() - 30L * 86400000L
            val cursor = db.rawQuery(
                """
                SELECT strftime('%Y-%m-%d', start_time / 1000, 'unixepoch', 'localtime') as day,
                       SUM(duration_seconds) as total_seconds
                FROM usage_logs
                WHERE start_time >= ?
                GROUP BY day
                ORDER BY day DESC
                LIMIT 30
                """.trimIndent(),
                arrayOf(thirtyDaysAgo.toString())
            )
            var streak = 0
            cursor.use {
                while (it.moveToNext()) {
                    val sec = it.getInt(1)
                    if (sec > 0) streak++ else break
                }
            }
            if (streak > 0) streak else 1
        } catch (_: Exception) {
            1
        }
    }

    private fun selectBestHook(db: SQLiteDatabase, pkg: String, usedMins: Int, streak: Int): Pair<String, String> {
        try {
            val cursor = db.rawQuery(
                """
                SELECT hook_type,
                       SUM(CASE WHEN action = 'turn_back' THEN 1 ELSE 0 END) * 1.0 / COUNT(*) as win_rate
                FROM hook_feedback
                WHERE package_name = ?
                GROUP BY hook_type
                HAVING COUNT(*) >= 2
                ORDER BY win_rate DESC
                LIMIT 1
                """.trimIndent(),
                arrayOf(pkg)
            )
            val favoredType = cursor.use {
                if (it.moveToFirst() && it.getDouble(1) >= 0.5) it.getString(0) else null
            }
            if (favoredType != null) {
                val match = HOOK_TEMPLATES.find { it.first == favoredType }
                if (match != null) return match
            }
        } catch (_: Exception) {}

        val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        return when {
            usedMins >= 120 -> HOOK_TEMPLATES.first { it.first == "loss" }
            streak >= 3 -> HOOK_TEMPLATES.first { it.first == "streak" }
            currentHour >= 21 || currentHour < 5 -> HOOK_TEMPLATES.first { it.first == "future_self" }
            Random.nextBoolean() -> HOOK_TEMPLATES.first { it.first == "goal" }
            else -> HOOK_TEMPLATES.first { it.first == "social_proof" }
        }
    }

    private fun queryInt(db: SQLiteDatabase, sql: String, args: Array<String>): Int {
        return db.rawQuery(sql, args).use { if (it.moveToFirst()) it.getInt(0) else 0 }
    }

    private fun selectRotatingEarlyWarningHook(
        appName: String,
        usedMins: Int,
        minutesLeft: Int,
        limitMins: Int
    ): Pair<String, String> {
        val eligible = EARLY_WARNING_HOOKS.indices.filter { it != lastWarningHookIndex }
        val chosenIndex = if (eligible.isNotEmpty()) eligible.random() else 0
        lastWarningHookIndex = chosenIndex
        val hookPair = EARLY_WARNING_HOOKS[chosenIndex]
        val message = hookPair.second(appName, usedMins, minutesLeft, limitMins)
        return Pair(hookPair.first, message)
    }

    private fun checkAndSendEarlyWarningNotification(
        db: SQLiteDatabase,
        pkg: String,
        appName: String,
        usedMins: Int,
        limitMins: Int
    ) {
        // 1. Check if snooze is active
        val snoozeUntil = packageSnoozeUntil[pkg] ?: 0L
        if (System.currentTimeMillis() < snoozeUntil) return

        // 2. Check mute distraction toggle
        val muteDistraction = queryString(db, "SELECT value FROM preferences WHERE key = 'mute_distraction'", emptyArray()) == "true"
        if (muteDistraction) return

        // 3. Check quiet hours
        val currentHour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val quietStart = queryString(db, "SELECT value FROM preferences WHERE key = 'quiet_hours_start'", emptyArray())?.toIntOrNull() ?: 22
        val quietEnd = queryString(db, "SELECT value FROM preferences WHERE key = 'quiet_hours_end'", emptyArray())?.toIntOrNull() ?: 7
        val inQuietHours = if (quietStart > quietEnd) {
            currentHour >= quietStart || currentHour < quietEnd
        } else {
            currentHour in quietStart until quietEnd
        }
        if (inQuietHours) return

        // 4. Check daily alert cap
        val maxAlerts = queryString(db, "SELECT value FROM preferences WHERE key = 'max_alerts_day'", emptyArray())?.toIntOrNull() ?: 20
        val todayStart = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        val todayAlerts = queryInt(
            db,
            "SELECT COUNT(*) FROM notifications_log WHERE timestamp >= ?",
            arrayOf(todayStart.toString())
        ) + queryInt(
            db,
            "SELECT COUNT(*) FROM early_warning_notifications WHERE timestamp >= ?",
            arrayOf(todayStart.toString())
        )
        if (todayAlerts >= maxAlerts) return

        // 5. Check deduplication for today
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val alreadySent = queryInt(
            db,
            "SELECT COUNT(*) FROM early_warning_notifications WHERE package_name = ? AND date_str = ?",
            arrayOf(pkg, todayStr)
        ) > 0
        if (alreadySent) return

        // 6. Select hook without repeating last hook
        val minutesLeft = Math.max(1, limitMins - usedMins)
        val hook = selectRotatingEarlyWarningHook(appName, usedMins, minutesLeft, limitMins)

        // 7. Store in SQLite table to deduplicate
        val cv = ContentValues().apply {
            put("package_name", pkg)
            put("date_str", todayStr)
            put("used_minutes", usedMins)
            put("limit_minutes", limitMins)
            put("hook_type", hook.first)
            put("hook_message", hook.second)
            put("timestamp", System.currentTimeMillis())
        }
        db.insertWithOnConflict("early_warning_notifications", null, cv, SQLiteDatabase.CONFLICT_IGNORE)

        // 8. Post notification to channel "Focus nudges"
        sendEarlyWarningNotification(pkg, appName, usedMins, limitMins, hook.second)
    }

    private fun sendEarlyWarningNotification(
        pkg: String,
        appName: String,
        usedMins: Int,
        limitMins: Int,
        message: String
    ) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                FOCUS_NUDGES_CHANNEL_ID,
                "Focus nudges",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Early-warning psychological nudges when approaching app limits"
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
            }
            nm.createNotificationChannel(channel)
        }

        val notificationId = Math.abs(pkg.hashCode())

        val backIntent = Intent(this, EarlyWarningActionReceiver::class.java).apply {
            action = "com.example.ai_routine_assistant.ACTION_BACK_TO_WORK"
            putExtra("package_name", pkg)
            putExtra("notification_id", notificationId)
            putExtra("used_minutes", usedMins)
            putExtra("limit_minutes", limitMins)
        }
        val backPendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId * 2 + 1,
            backIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val snoozeIntent = Intent(this, EarlyWarningActionReceiver::class.java).apply {
            action = "com.example.ai_routine_assistant.ACTION_SNOOZE_NUDGE"
            putExtra("package_name", pkg)
            putExtra("notification_id", notificationId)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId * 2 + 2,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val backAction = Notification.Action.Builder(
            null,
            "Back to work",
            backPendingIntent
        ).build()

        val snoozeAction = Notification.Action.Builder(
            null,
            "Snooze 15 min",
            snoozePendingIntent
        ).build()

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, FOCUS_NUDGES_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val notification = builder
            .setContentTitle("$appName limit approaching")
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setAutoCancel(true)
            .addAction(backAction)
            .addAction(snoozeAction)
            .build()

        nm.notify(notificationId, notification)
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(), resources.displayMetrics
        ).toInt()
    }
}
