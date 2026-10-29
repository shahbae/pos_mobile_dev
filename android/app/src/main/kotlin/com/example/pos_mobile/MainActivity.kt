package com.example.pos_mobile

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        showOverLockIfAlarm(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        showOverLockIfAlarm(intent)
    }

    // Layar kembali terkunci seperti biasa begitu app tidak lagi terlihat:
    // izin tampil di atas kunci layar hanya untuk alarm yang sedang dibuka.
    override fun onStop() {
        super.onStop()
        setShowOverLock(false)
    }

    // Alarm permintaan pengecekan foto (Tahap 4) membuka app lewat full-screen
    // intent di atas kunci layar. Atributnya sengaja tidak dipasang permanen di
    // manifest: kalau dipasang, layar POS bisa dibuka tanpa membuka kunci HP.
    // Payload notifikasi alarm diawali "alarm|" (lihat PushService).
    private fun showOverLockIfAlarm(intent: Intent?) {
        if (intent?.action == "SELECT_NOTIFICATION" &&
            intent.getStringExtra("payload")?.startsWith("alarm|") == true
        ) {
            setShowOverLock(true)
        }
    }

    private fun setShowOverLock(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    // Kartu "Notifikasi siap?" di Profil: hal-hal yang tidak dibuka plugin.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "estehcandi/notif")
            .setMethodCallHandler { call, result ->
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "canUseFullScreenIntent" -> result.success(
                        Build.VERSION.SDK_INT < 34 || nm.canUseFullScreenIntent()
                    )
                    "openFullScreenIntentSettings" -> {
                        if (Build.VERSION.SDK_INT >= 34) {
                            open(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")))
                        }
                        result.success(null)
                    }
                    "channelEnabled" -> {
                        val id = call.argument<String>("id") ?: ""
                        val ch = if (Build.VERSION.SDK_INT >= 26) nm.getNotificationChannel(id) else null
                        // Saluran yang belum dibuat dianggap menyala: app yang
                        // membuatnya saat pertama dibuka.
                        result.success(ch == null || ch.importance != NotificationManager.IMPORTANCE_NONE)
                    }
                    "openChannelSettings" -> {
                        val id = call.argument<String>("id") ?: ""
                        if (Build.VERSION.SDK_INT >= 26) {
                            open(
                                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                    .putExtra(Settings.EXTRA_CHANNEL_ID, id)
                            )
                        }
                        result.success(null)
                    }
                    "openAppNotificationSettings" -> {
                        if (Build.VERSION.SDK_INT >= 26) {
                            open(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        } else {
                            open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        }
                        result.success(null)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        open(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "setShowOverLock" -> {
                        setShowOverLock(call.argument<Boolean>("on") == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun open(intent: Intent) {
        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {
            // Sebagian merek HP tidak punya layar pengaturan itu; jatuh ke
            // halaman info app, tempat semua pengaturan app bisa dicapai.
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}
