package com.example.ai_routine_assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
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
import java.util.Calendar
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
    private var isRunning = false

    // Guards and state tracking
    private val shownForSession = mutableSetOf<String>()
    private val packageSnoozeUntil = mutableMapOf<String, Long>()

    companion object {
        private const val POLL_INTERVAL_MS = 2000L
        private const val SERVICE_NOTIFICATION_ID = 991
        private const val NOTIFICATION_CHANNEL_ID = "usage_monitor_service_channel"
        private const val SNOOZE_DURATION_MS = 15 * 60 * 1000L // 15 minutes

        private val HOOK_TEMPLATES = listOf(
            "loss" to "You've already spent %s on %s today. That's %s of focused energy you won't get back.",
            "future_self" to "Is opening %s right now who you want to be? The version of you that achieves your goals would close this.",
            "streak" to "You've built discipline today with a %d-day streak. Don't let an impulse session break your momentum.",
            "goal" to "Every minute spent scrolling %s is borrowed from what truly matters to you today.",
            "social_proof" to "High achievers ruthlessly guard their focus. Reclaim your time right now."
        )
    }

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isRunning) return
            checkForegroundApp()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    // ── Lifecycle ───────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        startServiceInForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        startServiceInForeground()
        handler.removeCallbacks(pollRunnable)
        handler.post(pollRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacks(pollRunnable)
        hideOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Foreground Service Setup ────────────────────────────────────────────────

    private fun startServiceInForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Routine Focus Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors screen-time limits in real-time"
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)

            val notification = Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("Routine Focus Active")
                .setContentText("Monitoring screen-time limits and habits on-device")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setOngoing(true)
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

                if (hasOverlayPermission()) {
                    shownForSession.add(pkg)
                    showFullScreenOverlay(pkg, appName, usedMins, limitMins, streak)
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
        streak: Int
    ) {
        handler.post {
            hideOverlay()

            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            overlayTargetPackage = pkg

            val hookPair = HOOK_TEMPLATES[Random.nextInt(HOOK_TEMPLATES.size)]
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

            // Root scrim — dark immersive backdrop
            val root = LinearLayout(this@UsageMonitorService).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.parseColor("#F50A0A12"))
                // No tap-to-dismiss on root
            }

            // Card container
            val card = LinearLayout(this@UsageMonitorService).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dpToPx(24), dpToPx(28), dpToPx(24), dpToPx(24))
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#1C1C2A"))
                    cornerRadius = dpToPx(24).toFloat()
                    setStroke(dpToPx(1), Color.parseColor("#38384E"))
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
                    layoutParams = LinearLayout.LayoutParams(dpToPx(56), dpToPx(56)).apply {
                        setMargins(0, 0, 0, dpToPx(12))
                    }
                })
            } else {
                card.addView(TextView(this@UsageMonitorService).apply {
                    text = "⚡"
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 44f)
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, dpToPx(10))
                })
            }

            // App Name & Title
            card.addView(TextView(this@UsageMonitorService).apply {
                text = "Limit Reached: $appName"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dpToPx(4))
            })

            // Today's Usage vs Limit Stat
            val statText = "$timeFormatted used  ·  ${overMins}m over limit"
            card.addView(TextView(this@UsageMonitorService).apply {
                text = statText
                setTextColor(Color.parseColor("#FF6E6E"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dpToPx(16))
            })

            // Psychological Hook Message
            card.addView(TextView(this@UsageMonitorService).apply {
                text = hookMessage
                setTextColor(Color.parseColor("#E0E0E8"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                setLineSpacing(dpToPx(3).toFloat(), 1.2f)
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

            // Button 1: "Take me back" (Primary)
            val btnTakeBack = Button(this@UsageMonitorService).apply {
                text = "Take me back"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                setTypeface(typeface, Typeface.BOLD)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#3D5AFE"))
                    cornerRadius = dpToPx(16).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dpToPx(50)
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

            // Button 2: "Brain challenge instead" (Stage 4 hook / stub)
            val btnBrainChallenge = Button(this@UsageMonitorService).apply {
                text = "🧠 Brain challenge instead"
                setTextColor(Color.parseColor("#EDE7F6"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
                setTypeface(typeface, Typeface.BOLD)
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#5E35B1"))
                    cornerRadius = dpToPx(16).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dpToPx(48)
                ).apply {
                    setMargins(0, 0, 0, dpToPx(10))
                }
                setOnClickListener {
                    logIntervention(pkg, "brain_challenge", usedMins, limitMins, hookType)
                    hideOverlay()
                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                    if (launchIntent != null) {
                        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(launchIntent)
                    }
                }
            }

            // Button 3: "Continue anyway" (Friction Countdown)
            var countdownSeconds = 5
            val btnContinue = Button(this@UsageMonitorService).apply {
                text = "Wait 5s..."
                setTextColor(Color.parseColor("#8E8EA8"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                isEnabled = false
                alpha = 0.5f
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#252538"))
                    cornerRadius = dpToPx(16).toFloat()
                    setStroke(dpToPx(1), Color.parseColor("#3B3B52"))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dpToPx(46)
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
                        btnContinue.text = "Wait ${countdownSeconds}s..."
                        handler.postDelayed(this, 1000L)
                    } else {
                        btnContinue.text = "Continue anyway"
                        btnContinue.setTextColor(Color.parseColor("#C5CAE9"))
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
            overlayView = root

            try {
                wm.addView(overlayView, params)
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

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(), resources.displayMetrics
        ).toInt()
    }
}
