package com.example.sport_platform

import android.Manifest
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationResult: MethodChannel.Result? = null

    private fun notificationsGranted(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        return Build.VERSION.SDK_INT < 24 ||
            getSystemService(NotificationManager::class.java).areNotificationsEnabled()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pace/workout_notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isGranted" -> result.success(notificationsGranted())
                    "requestPermission" -> {
                        if (notificationsGranted()) {
                            result.success(true)
                        } else if (notificationResult != null) {
                            result.error("request_pending", "Permission request already pending", null)
                        } else if (Build.VERSION.SDK_INT >= 33) {
                            notificationResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4812)
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4812) {
            notificationResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            notificationResult = null
        }
    }

    override fun onDestroy() {
        notificationResult?.success(false)
        notificationResult = null
        super.onDestroy()
    }
}
