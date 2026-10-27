package com.example.ai_routine_assistant

import android.app.Notification
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
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
import android.widget.LinearLayout
import android.widget.TextView
import java.util.Calendar
import kotlin.random.Random

/**
 * Native service for real-time foreground-app monitoring.
 *
 * Polls UsageEvents every 2 seconds. When a limit-exceeded app is detected
 * in the foreground, it immediately shows a full-screen overlay nudge and
 * fires a notification.
 *
 * Reads limits and usage totals directly from the SQLite database (read-only,
 * WAL-safe). Runs as a non-foreground started service; relies on
 * flutter_background_service's foreground service in the same process to
 * keep the process alive.
 */
class UsageMonitorService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var lastForegroundPackage: String? = null
    private var overlayView: View? = null
    private var isRunning = false
    private val lastNotificationTimes = mutableMapOf<String, Long>()

    companion object {
        private const val POLL_INTERVAL_MS = 2000L         // 2-second polling
        private const val NOTIFICATION_COOLDOWN_MS = 60_000L // 1-min cooldown per package

        private val NUDGE_MESSAGES = listOf(
            "loss"           to "You've exceeded your limit on %s. Every extra minute here is borrowed from your goals.",
            "identity"       to "Is opening %s right now who you want to be? The focused version of you would close this.",
            "streak"         to "You've been building discipline today — don't let %s break your streak.",
            "implementation" to "You set a limit on %s for a reason. Pause 3 seconds, then switch to something meaningful.",
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
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
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

    // ── Core polling logic ──────────────────────────────────────────────────────

    private fun checkForegroundApp() {
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
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

            if (latestPkg != null && latestPkg != lastForegroundPackage) {
                lastForegroundPackage = latestPkg
                onAppForegrounded(latestPkg)
            }
        } catch (_: Exception) {
            // Usage permission may not be granted yet — silently skip
        }
    }

    private fun onAppForegrounded(pkg: String) {
        // Skip our own app and system-only packages
        if (pkg == packageName) return
        try {
            if (packageManager.getLaunchIntentForPackage(pkg) == null) return
        } catch (_: Exception) { return }

        var db: SQLiteDatabase? = null
        try {
            val dbFile = getDatabasePath("ai_routine_assistant.db")
            if (!dbFile.exists()) return
            db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)

            // 1. Resolve app category
            val category = queryString(db,
                "SELECT category FROM app_categories WHERE package_name = ?", arrayOf(pkg)
            ) ?: "neutral"

            // 2. Resolve per-app limit (fallback to category limit for distracting apps)
            var limitMins = queryString(db,
                "SELECT value FROM preferences WHERE key = ?", arrayOf("limit_pkg_$pkg")
            )?.toIntOrNull() ?: 0

            if (limitMins == 0 && category == "distracting") {
                limitMins = queryString(db,
                    "SELECT value FROM preferences WHERE key = ?", arrayOf("limit_cat_distracting")
                )?.toIntOrNull() ?: 120
            }
            if (limitMins <= 0) return  // No limit configured

            // 3. Sum today's usage for this package
            val todayMs = todayStartMs()
            val usedSec = queryInt(db,
                "SELECT COALESCE(SUM(duration_seconds),0) FROM usage_logs WHERE package_name = ? AND start_time >= ?",
                arrayOf(pkg, todayMs.toString())
            )
            val usedMins = usedSec / 60

            if (usedMins >= limitMins) {
                val appName = getAppLabel(pkg)
                triggerAlert(pkg, appName, usedMins, limitMins)
            }
        } catch (_: Exception) {
            // DB not ready or other error — skip silently
        } finally {
            try { db?.close() } catch (_: Exception) {}
        }
    }

    // ── Alert actions ───────────────────────────────────────────────────────────

    private fun triggerAlert(pkg: String, appName: String, usedMins: Int, limitMins: Int) {
        // Primary: full-screen overlay (if permission granted)
        if (hasOverlayPermission()) {
            showFullScreenOverlay(appName)
        }
        // Secondary: notification (with per-package cooldown)
        showLimitNotification(pkg, appName, usedMins, limitMins)
    }

    // ── Full-screen overlay ─────────────────────────────────────────────────────

    private fun showFullScreenOverlay(appName: String) {
        handler.post {
            hideOverlay()

            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val nudge = NUDGE_MESSAGES[Random.nextInt(NUDGE_MESSAGES.size)]
            val nudgeType = nudge.first
            val nudgeText = String.format(nudge.second, appName)

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            )

            // ── Root: full-screen dark scrim, tap-to-dismiss ──
            val root = LinearLayout(this@UsageMonitorService).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.parseColor("#E6101018"))
                setOnClickListener { hideOverlay() }
            }

            // ── Card ──
            val card = LinearLayout(this@UsageMonitorService).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dpToPx(28), dpToPx(32), dpToPx(28), dpToPx(24))
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#1E1E2C"))
                    cornerRadius = dpToPx(24).toFloat()
                    setStroke(dpToPx(1), Color.parseColor("#3F3F56"))
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply { setMargins(dpToPx(24), 0, dpToPx(24), 0) }
            }

            // Icon
            card.addView(TextView(this@UsageMonitorService).apply {
                text = "\u26A1"  // ⚡
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 48f)
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dpToPx(12))
            })

            // Title
            card.addView(TextView(this@UsageMonitorService).apply {
                text = "Focus Nudge — $appName"
                setTextColor(Color.WHITE)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 20f)
                setTypeface(typeface, Typeface.BOLD)
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dpToPx(6))
            })

            // Badge
            card.addView(TextView(this@UsageMonitorService).apply {
                text = nudgeType.uppercase()
                setTextColor(Color.parseColor("#80D8FF"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dpToPx(16))
            })

            // Message
            card.addView(TextView(this@UsageMonitorService).apply {
                text = nudgeText
                setTextColor(Color.parseColor("#E0E0E0"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                setLineSpacing(dpToPx(3).toFloat(), 1.15f)
                gravity = Gravity.CENTER
                setPadding(dpToPx(4), 0, dpToPx(4), dpToPx(20))
            })

            // Dismiss hint
            card.addView(TextView(this@UsageMonitorService).apply {
                text = "Tap anywhere to dismiss \u00B7 auto-closes in 4s"
                setTextColor(Color.parseColor("#666680"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                gravity = Gravity.CENTER
            })

            root.addView(card)
            overlayView = root

            try {
                wm.addView(overlayView, params)
                // Auto-dismiss after 4 seconds
                handler.postDelayed({ hideOverlay() }, 4000L)
            } catch (e: Exception) {
                overlayView = null
            }
        }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        overlayView = null
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(view)
        } catch (_: Exception) {}
    }

    // ── Notification ────────────────────────────────────────────────────────────

    private fun showLimitNotification(pkg: String, appName: String, usedMins: Int, limitMins: Int) {
        val now = System.currentTimeMillis()
        val last = lastNotificationTimes[pkg] ?: 0L
        if (now - last < NOTIFICATION_COOLDOWN_MS) return
        lastNotificationTimes[pkg] = now

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val notification = Notification.Builder(this, "distraction_alerts")
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setContentTitle("\u26A0 Limit Exceeded: $appName")
                .setContentText("${usedMins}m used today (limit: ${limitMins}m)")
                .setAutoCancel(true)
                .build()
            nm.notify(pkg.hashCode() and 0x7FFFFFFF, notification)
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────────

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true
    }

    private fun queryString(db: SQLiteDatabase, sql: String, args: Array<String>): String? {
        return db.rawQuery(sql, args).use { if (it.moveToFirst()) it.getString(0) else null }
    }

    private fun queryInt(db: SQLiteDatabase, sql: String, args: Array<String>): Int {
        return db.rawQuery(sql, args).use { if (it.moveToFirst()) it.getInt(0) else 0 }
    }

    private fun todayStartMs(): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    private fun getAppLabel(pkg: String): String {
        return try {
            val ai = packageManager.getApplicationInfo(pkg, 0)
            val label = packageManager.getApplicationLabel(ai).toString().trim()
            if (label.isNotEmpty()) label else pkg
        } catch (_: Exception) { pkg }
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, dp.toFloat(), resources.displayMetrics
        ).toInt()
    }
}
