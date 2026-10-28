package com.example.ai_routine_assistant

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class EarlyWarningActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val pkg = intent.getStringExtra("package_name") ?: return
        val notificationId = intent.getIntExtra("notification_id", -1)

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if (notificationId != -1) {
            nm?.cancel(notificationId)
        }

        val dbFile = context.getDatabasePath("ai_routine_assistant.db")
        if (!dbFile.exists()) return

        var db: SQLiteDatabase? = null
        try {
            db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
            val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

            when (action) {
                "com.example.ai_routine_assistant.ACTION_BACK_TO_WORK" -> {
                    val usedMins = intent.getIntExtra("used_minutes", 0)
                    val limitMins = intent.getIntExtra("limit_minutes", 0)

                    // 1. Send user to Home screen
                    val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                        addCategory(Intent.CATEGORY_HOME)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(homeIntent)

                    // 2. Log in notifications_log with rewarded = 0 (syncFromUnrewardedInterventions awards +20 XP)
                    val values = ContentValues().apply {
                        put("type", "turn_back")
                        put("package_name", pkg)
                        put("message", "Turned back from 80% nudge ($usedMins/$limitMins mins)")
                        put("timestamp", System.currentTimeMillis())
                        put("trigger_conditions", """{"hook":"warning_80","usedMins":$usedMins,"limitMins":$limitMins}""")
                        put("rewarded", 0)
                    }
                    db.insert("notifications_log", null, values)

                    // 3. Update early_warning_notifications
                    val updateValues = ContentValues().apply {
                        put("action_taken", "turn_back")
                    }
                    db.update(
                        "early_warning_notifications",
                        updateValues,
                        "package_name = ? AND date_str = ?",
                        arrayOf(pkg, todayStr)
                    )
                }
                "com.example.ai_routine_assistant.ACTION_SNOOZE_NUDGE" -> {
                    // Update early_warning_notifications
                    val updateValues = ContentValues().apply {
                        put("action_taken", "snooze")
                    }
                    db.update(
                        "early_warning_notifications",
                        updateValues,
                        "package_name = ? AND date_str = ?",
                        arrayOf(pkg, todayStr)
                    )
                }
            }
        } catch (_: Exception) {
        } finally {
            try { db?.close() } catch (_: Exception) {}
        }
    }
}

