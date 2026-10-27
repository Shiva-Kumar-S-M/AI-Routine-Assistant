package com.example.ai_routine_assistant

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.ai_routine_assistant/usage"
    private var methodChannel: MethodChannel? = null
    private var overlayView: View? = null

    companion object {
        private val EXCLUDED_PACKAGES = setOf(
            "com.sec.android.app.launcher",
            "com.google.android.apps.nexuslauncher",
            "com.miui.home",
            "com.huawei.android.launcher",
            "com.oppo.launcher",
            "com.android.launcher",
            "com.android.launcher2",
            "com.android.launcher3",
            "com.android.systemui",
            "com.samsung.android.systemui",
            "com.android.incallui",
            "com.samsung.android.incallui",
            "com.android.server.telecom",
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannels()

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "openUsageSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }
                "checkOverlayPermission" -> {
                    result.success(hasOverlayPermission())
                }
                "openOverlaySettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "showDistractionOverlay" -> {
                    val appName = call.argument<String>("appName") ?: "Distracting App"
                    val nudgeType = call.argument<String>("nudgeType") ?: "loss"
                    val nudgeMessage = call.argument<String>("nudgeMessage") ?: "Pause and consider your focus goals."
                    val targetPackage = call.argument<String>("targetProductivePackage") ?: "com.android.settings"

                    val shown = showNudgeOverlay(appName, nudgeType, nudgeMessage, targetPackage)
                    result.success(shown)
                }
                "hideOverlay" -> {
                    hideOverlay()
                    result.success(true)
                }
                "queryUsageEvents" -> {
                    val startTime = call.argument<Long>("startTime") ?: (System.currentTimeMillis() - 86400000)
                    val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                    val events = getParsedUsageEvents(startTime, endTime)
                    result.success(events)
                }
                "classifyPackages" -> {
                    val packages = call.argument<List<String>>("packages") ?: emptyList()
                    val classified = classifyPackagesByAndroidCategory(packages)
                    result.success(classified)
                }
                "startUsageMonitorService" -> {
                    startUsageMonitorService()
                    result.success(true)
                }
                "stopUsageMonitorService" -> {
                    stopUsageMonitorService()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        if (hasUsageStatsPermission()) {
            startUsageMonitorService()
        }
    }

    override fun onResume() {
        super.onResume()
        if (hasUsageStatsPermission()) {
            startUsageMonitorService()
        }
    }

    private fun startUsageMonitorService() {
        try {
            val intent = Intent(this, UsageMonitorService::class.java)
            startService(intent)
        } catch (_: Exception) {}
    }

    private fun stopUsageMonitorService() {
        try {
            val intent = Intent(this, UsageMonitorService::class.java)
            stopService(intent)
        } catch (_: Exception) {}
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val bgChannel = NotificationChannel(
                "bg_routine_channel",
                "AI Routine Assistant Active",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitoring usage routines and limits in background"
            }

            val distractionChannel = NotificationChannel(
                "distraction_alerts",
                "Distraction Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for screen time distraction limits"
            }

            val routineChannel = NotificationChannel(
                "routine_reminders",
                "Routine Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for detected app routine patterns"
            }

            notificationManager.createNotificationChannel(bgChannel)
            notificationManager.createNotificationChannel(distractionChannel)
            notificationManager.createNotificationChannel(routineChannel)
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun hideOverlay() {
        if (overlayView != null) {
            val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            try {
                windowManager.removeView(overlayView)
            } catch (e: Exception) {
                // View already detached
            }
            overlayView = null
        }
    }

    private fun showNudgeOverlay(
        appName: String,
        nudgeType: String,
        nudgeMessage: String,
        targetProductivePackage: String
    ): Boolean {
        if (!hasOverlayPermission()) return false

        hideOverlay()

        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
            x = 0
            y = 0
        }

        // Build overlay layout programmatically
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dpToPx(24), dpToPx(24), dpToPx(24), dpToPx(24))

            val bgDrawable = GradientDrawable().apply {
                setColor(Color.parseColor("#1E1E2C"))
                cornerRadius = dpToPx(20).toFloat()
                setStroke(dpToPx(1), Color.parseColor("#3F3F56"))
            }
            background = bgDrawable
        }

        // Title
        val titleText = TextView(this).apply {
            text = "⚡ Focus Nudge — $appName"
            setTextColor(Color.parseColor("#FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTypeface(typeface, android.graphics.Typeface.BOLD)
        }

        // Nudge Type Badge
        val badgeText = TextView(this).apply {
            text = "NUDGE FRAME: ${nudgeType.uppercase()}"
            setTextColor(Color.parseColor("#80D8FF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setPadding(0, dpToPx(4), 0, dpToPx(8))
        }

        // Message
        val messageText = TextView(this).apply {
            text = nudgeMessage
            setTextColor(Color.parseColor("#E0E0E0"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setLineSpacing(dpToPx(4).toFloat(), 1.1f)
            setPadding(0, dpToPx(8), 0, dpToPx(20))
        }

        // Action Buttons Row
        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
        }

        val btnSwitch = Button(this).apply {
            text = "Switch to Productive App"
            setTextColor(Color.parseColor("#121212"))
            setBackgroundColor(Color.parseColor("#80D8FF"))
            setOnClickListener {
                hideOverlay()
                // Log action back to Flutter
                methodChannel?.invokeMethod("onOverlayAction", mapOf(
                    "action" to "switch_productive",
                    "appName" to appName
                ))
                // Launch target productive app
                try {
                    val launchIntent = packageManager.getLaunchIntentForPackage(targetProductivePackage)
                    if (launchIntent != null) {
                        startActivity(launchIntent)
                    }
                } catch (e: Exception) {
                    // Fallback
                }
            }
        }

        val btnDismiss = Button(this).apply {
            text = "Dismiss"
            setTextColor(Color.parseColor("#B0BEC5"))
            setBackgroundColor(Color.TRANSPARENT)
            setOnClickListener {
                hideOverlay()
                // Log dismissal data point back to Flutter
                methodChannel?.invokeMethod("onOverlayAction", mapOf(
                    "action" to "dismiss",
                    "appName" to appName
                ))
            }
        }

        buttonRow.addView(btnDismiss)
        buttonRow.addView(btnSwitch)

        container.addView(titleText)
        container.addView(badgeText)
        container.addView(messageText)
        container.addView(buttonRow)

        overlayView = container

        try {
            windowManager.addView(overlayView, layoutParams)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun dpToPx(dp: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            dp.toFloat(),
            resources.displayMetrics
        ).toInt()
    }

    private fun getParsedUsageEvents(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)

        val rawSessions = mutableListOf<RawSession>()
        val activeForegrounds = mutableMapOf<String, Long>()

        val event = UsageEvents.Event()
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val pkg = event.packageName ?: continue

            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                activeForegrounds[pkg] = event.timeStamp
            } else if (event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND) {
                val start = activeForegrounds.remove(pkg)
                if (start != null && event.timeStamp > start) {
                    rawSessions.add(RawSession(pkg, start, event.timeStamp))
                }
            }
        }

        // Sort sessions by start time
        rawSessions.sortBy { it.startTime }

        // Session Merging: Merge sessions for same package if < 30 seconds (30000 ms) apart
        val mergedSessions = mutableListOf<RawSession>()
        for (session in rawSessions) {
            if (mergedSessions.isEmpty()) {
                mergedSessions.add(session)
            } else {
                val last = mergedSessions.last()
                if (last.packageName == session.packageName && (session.startTime - last.endTime) <= 30000) {
                    // Extend last session
                    mergedSessions[mergedSessions.size - 1] = RawSession(last.packageName, last.startTime, session.endTime)
                } else {
                    mergedSessions.add(session)
                }
            }
        }

        val packageManager = packageManager
        val resultList = mutableListOf<Map<String, Any>>()
        
        // Cache package app labels per fetch cycle to prevent repeated PackageManager calls
        val appNameCache = mutableMapOf<String, String>()
        // Cache exclusion checks per package to avoid repeated PackageManager lookups
        val excludedCache = mutableMapOf<String, Boolean>()

        for (session in mergedSessions) {
            val pkg = session.packageName

            // Filter out non-user-facing packages: launchers, system UI, and
            // any package without a launch intent (system-only services).
            val isExcluded = excludedCache.getOrPut(pkg) {
                pkg in EXCLUDED_PACKAGES ||
                pkg == packageName ||
                packageManager.getLaunchIntentForPackage(pkg) == null
            }
            if (isExcluded) continue

            val durationSeconds = ((session.endTime - session.startTime) / 1000).toInt()
            if (durationSeconds <= 0) continue

            val appName = appNameCache.getOrPut(session.packageName) {
                try {
                    val appInfo = packageManager.getApplicationInfo(session.packageName, 0)
                    val label = packageManager.getApplicationLabel(appInfo).toString().trim()
                    if (label.isNotEmpty()) label else session.packageName
                } catch (e: Exception) {
                    session.packageName
                }
            }

            val map = mapOf(
                "packageName" to session.packageName,
                "appName" to appName,
                "startTime" to session.startTime,
                "endTime" to session.endTime,
                "durationSeconds" to durationSeconds
            )
            resultList.add(map)
        }

        return resultList
    }

    private fun classifyPackagesByAndroidCategory(packages: List<String>): Map<String, String> {
        val result = mutableMapOf<String, String>()
        for (pkg in packages) {
            try {
                val appInfo = packageManager.getApplicationInfo(pkg, 0)
                val category = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appInfo.category
                } else {
                    ApplicationInfo.CATEGORY_UNDEFINED
                }
                result[pkg] = mapAndroidCategoryToBucket(category)
            } catch (e: Exception) {
                result[pkg] = "neutral"
            }
        }
        return result
    }

    private fun mapAndroidCategoryToBucket(category: Int): String {
        return when (category) {
            ApplicationInfo.CATEGORY_GAME -> "distracting"
            ApplicationInfo.CATEGORY_AUDIO -> "neutral"
            ApplicationInfo.CATEGORY_VIDEO -> "distracting"
            ApplicationInfo.CATEGORY_IMAGE -> "neutral"
            ApplicationInfo.CATEGORY_SOCIAL -> "distracting"
            ApplicationInfo.CATEGORY_NEWS -> "neutral"
            ApplicationInfo.CATEGORY_MAPS -> "neutral"
            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productive"
            else -> "neutral"  // CATEGORY_UNDEFINED and unknown
        }
    }

    data class RawSession(val packageName: String, val startTime: Long, val endTime: Long)
}

