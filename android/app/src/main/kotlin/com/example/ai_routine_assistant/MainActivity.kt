package com.example.ai_routine_assistant

import android.app.AppOpsManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.ai_routine_assistant/usage"
    private var methodChannel: MethodChannel? = null
    private var pendingRoute: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleLaunchIntent(intent)
    }

    private fun handleLaunchIntent(intent: Intent?) {
        val route = intent?.getStringExtra("route")
        if (route != null) {
            pendingRoute = route
            methodChannel?.invokeMethod("onDeepLinkRoute", route)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannels()

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getLaunchRoute" -> {
                    val route = pendingRoute
                    pendingRoute = null
                    result.success(route)
                }
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
                "checkBatteryOptimizationIgnored" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pm?.isIgnoringBatteryOptimizations(packageName) ?: false
                    } else {
                        true
                    }
                    result.success(isIgnored)
                }
                "requestBatteryOptimization" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } catch (_: Exception) {
                            try {
                                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            } catch (_: Exception) {}
                        }
                    }
                    result.success(true)
                }
                "showDistractionOverlay" -> {
                    // Unified overlay is handled directly by UsageMonitorService
                    result.success(true)
                }
                "hideOverlay" -> {
                    result.success(true)
                }
                "queryUsageEvents" -> {
                    val startTime = call.argument<Long>("startTime") ?: (System.currentTimeMillis() - 86400000)
                    val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                    val events = UsageStatsHelper.getParsedUsageEvents(this, startTime, endTime)
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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
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

            val monitorChannel = NotificationChannel(
                "usage_monitor_service_channel",
                "Routine Focus Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors screen-time limits in real-time"
                setShowBadge(false)
            }

            notificationManager.createNotificationChannel(bgChannel)
            notificationManager.createNotificationChannel(distractionChannel)
            notificationManager.createNotificationChannel(routineChannel)
            notificationManager.createNotificationChannel(monitorChannel)
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
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
            } catch (_: Exception) {
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
            else -> "neutral"
        }
    }
}
