package com.example.ai_routine_assistant

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import java.util.Calendar

data class RawUsageSession(val packageName: String, val startTime: Long, val endTime: Long)

object UsageStatsHelper {

    val EXCLUDED_PACKAGES = setOf(
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
        "com.android.server.telecom"
    )

    /**
     * Returns midnight (00:00:00.000) of the current day in milliseconds.
     */
    fun getTodayStartMs(): Long {
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }

    /**
     * Pairs MOVE_TO_FOREGROUND and MOVE_TO_BACKGROUND events, merges sessions
     * within 30 seconds (< 30,000 ms), and includes any currently running active foreground session.
     */
    fun queryMergedSessions(
        context: Context,
        startTime: Long,
        endTime: Long
    ): List<RawUsageSession> {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return emptyList()

        val usageEvents = usm.queryEvents(startTime, endTime)
        val rawSessions = mutableListOf<RawUsageSession>()
        val activeForegrounds = mutableMapOf<String, Long>()

        val event = UsageEvents.Event()
        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            val pkg = event.packageName ?: continue

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    activeForegrounds[pkg] = event.timeStamp
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val start = activeForegrounds.remove(pkg)
                    if (start != null && event.timeStamp > start) {
                        rawSessions.add(RawUsageSession(pkg, start, event.timeStamp))
                    }
                }
            }
        }

        // Include the currently running session if still in foreground
        for ((pkg, start) in activeForegrounds) {
            if (endTime > start) {
                rawSessions.add(RawUsageSession(pkg, start, endTime))
            }
        }

        // Sort by start time
        rawSessions.sortBy { it.startTime }

        // Session Merging: Merge sessions for the same package if gap <= 30 seconds
        val mergedSessions = mutableListOf<RawUsageSession>()
        for (session in rawSessions) {
            if (mergedSessions.isEmpty()) {
                mergedSessions.add(session)
            } else {
                val last = mergedSessions.last()
                if (last.packageName == session.packageName && (session.startTime - last.endTime) <= 30000L) {
                    // Extend the previous session
                    mergedSessions[mergedSessions.size - 1] =
                        RawUsageSession(last.packageName, last.startTime, session.endTime)
                } else {
                    mergedSessions.add(session)
                }
            }
        }

        return mergedSessions
    }

    /**
     * Calculates today's real-time total usage in seconds for a specific package
     * from midnight to now, including the currently active session.
     */
    fun getTodayUsageSecondsForPackage(context: Context, targetPackage: String): Int {
        val todayStartMs = getTodayStartMs()
        val now = System.currentTimeMillis()
        val sessions = queryMergedSessions(context, todayStartMs, now)

        var totalSeconds = 0
        for (session in sessions) {
            if (session.packageName == targetPackage) {
                val durSec = ((session.endTime - session.startTime) / 1000).toInt()
                if (durSec > 0) {
                    totalSeconds += durSec
                }
            }
        }
        return totalSeconds
    }

    /**
     * Used by MainActivity for MethodChannel("queryUsageEvents").
     * Filters out system UI, launchers, and packages without launch intents,
     * and returns structured maps with resolved app labels.
     */
    fun getParsedUsageEvents(
        context: Context,
        startTime: Long,
        endTime: Long
    ): List<Map<String, Any>> {
        val mergedSessions = queryMergedSessions(context, startTime, endTime)
        val pm = context.packageManager
        val myPackage = context.packageName

        val resultList = mutableListOf<Map<String, Any>>()
        val appNameCache = mutableMapOf<String, String>()
        val excludedCache = mutableMapOf<String, Boolean>()

        for (session in mergedSessions) {
            val pkg = session.packageName

            val isExcluded = excludedCache.getOrPut(pkg) {
                pkg in EXCLUDED_PACKAGES ||
                pkg == myPackage ||
                pm.getLaunchIntentForPackage(pkg) == null
            }
            if (isExcluded) continue

            val durationSeconds = ((session.endTime - session.startTime) / 1000).toInt()
            if (durationSeconds <= 0) continue

            val appName = appNameCache.getOrPut(pkg) {
                getAppLabel(context, pkg)
            }

            resultList.add(
                mapOf(
                    "packageName" to pkg,
                    "appName" to appName,
                    "startTime" to session.startTime,
                    "endTime" to session.endTime,
                    "durationSeconds" to durationSeconds
                )
            )
        }

        return resultList
    }

    fun getAppLabel(context: Context, packageName: String): String {
        return try {
            val pm = context.packageManager
            val ai = pm.getApplicationInfo(packageName, 0)
            val label = pm.getApplicationLabel(ai).toString().trim()
            if (label.isNotEmpty()) label else packageName
        } catch (_: Exception) {
            packageName
        }
    }

    fun getAppIcon(context: Context, packageName: String): Drawable? {
        return try {
            context.packageManager.getApplicationIcon(packageName)
        } catch (_: Exception) {
            null
        }
    }
}
