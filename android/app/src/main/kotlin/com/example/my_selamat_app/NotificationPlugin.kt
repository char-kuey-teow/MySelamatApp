package com.example.my_selamat_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class NotificationPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val CHANNEL_ID = "selamat_app_channel"
    private val CHANNEL_NAME = "Selamat App Notifications"
    private val CHANNEL_DESCRIPTION = "Notifications for My Selamat App"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "selamat_app/notifications")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        createNotificationChannel()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "showNotification" -> {
                try {
                    // Handle both Int and Long types for ID - more robust type checking
                    val idValue = call.argument<Any>("id")
                    val idLong = when (idValue) {
                        is Long -> idValue
                        is Int -> idValue.toLong()
                        is Double -> idValue.toLong()
                        is String -> idValue.toLongOrNull() ?: 0L
                        else -> 0L
                    }
                    val id = idLong.toInt()
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val payload = call.argument<String>("payload")
                    
                    android.util.Log.d("NotificationPlugin", "Received notification request:")
                    android.util.Log.d("NotificationPlugin", "ID Value: $idValue, ID Long: $idLong, ID Int: $id")
                    android.util.Log.d("NotificationPlugin", "Title: $title, Body: $body")
                    
                    showNotification(id, title, body, payload)
                    android.util.Log.d("NotificationPlugin", "Notification shown successfully")
                    result.success(null)
                } catch (e: Exception) {
                    android.util.Log.e("NotificationPlugin", "Error showing notification: ${e.message}", e)
                    result.error("NOTIFICATION_ERROR", "Failed to show notification: ${e.message}", null)
                }
            }
            "scheduleNotification" -> {
                try {
                    // Handle both Int and Long types for ID - more robust type checking
                    val idValue = call.argument<Any>("id")
                    val idLong = when (idValue) {
                        is Long -> idValue
                        is Int -> idValue.toLong()
                        is Double -> idValue.toLong()
                        is String -> idValue.toLongOrNull() ?: 0L
                        else -> 0L
                    }
                    val id = idLong.toInt()
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val scheduledDate = call.argument<Long>("scheduledDate") ?: 0L
                    val payload = call.argument<String>("payload")
                    
                    android.util.Log.d("NotificationPlugin", "Scheduling notification with ID: $id")
                    scheduleNotification(id, title, body, scheduledDate, payload)
                    result.success(null)
                } catch (e: Exception) {
                    android.util.Log.e("NotificationPlugin", "Error scheduling notification: ${e.message}", e)
                    result.error("NOTIFICATION_ERROR", "Failed to schedule notification: ${e.message}", null)
                }
            }
            "cancelNotification" -> {
                val id = call.argument<Int>("id") ?: 0
                cancelNotification(id)
                result.success(null)
            }
            "cancelAllNotifications" -> {
                cancelAllNotifications()
                result.success(null)
            }
            "getPendingNotifications" -> {
                val pendingNotifications = getPendingNotifications()
                result.success(pendingNotifications)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableVibration(true)
                enableLights(true)
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showNotification(id: Int, title: String, body: String, payload: String?) {
        try {
            android.util.Log.d("NotificationPlugin", "Creating notification with ID: $id")
            
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                putExtra("payload", payload)
            }
            
            val pendingIntent = PendingIntent.getActivity(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVibrate(longArrayOf(0, 1000, 500, 1000))
                .build()

            with(NotificationManagerCompat.from(context)) {
                notify(id, notification)
                android.util.Log.d("NotificationPlugin", "Notification displayed with ID: $id")
            }
        } catch (e: Exception) {
            android.util.Log.e("NotificationPlugin", "Error in showNotification: ${e.message}", e)
            throw e
        }
    }

    private fun scheduleNotification(id: Int, title: String, body: String, scheduledDate: Long, payload: String?) {
        // For now, we'll show the notification immediately
        // In a real implementation, you would use AlarmManager or WorkManager
        showNotification(id, title, body, payload)
    }

    private fun cancelNotification(id: Int) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(id)
    }

    private fun cancelAllNotifications() {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancelAll()
    }

    private fun getPendingNotifications(): List<Map<String, Any>> {
        // This is a simplified implementation
        // In a real app, you would track pending notifications
        return emptyList()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

