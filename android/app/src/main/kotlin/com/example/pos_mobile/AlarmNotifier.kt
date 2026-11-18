package com.example.pos_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat

/**
 * Satu alarm pengecekan foto dari server. Isinya persis data message FCM
 * (`title`, `body`, `tag`, `target`, `id`), dibaca sama seperti
 * `PushService.show` di Dart supaya `tag` dan id notifikasinya cocok dengan
 * `PushService.cancelTag`.
 */
data class AlarmData(
    val tag: String,
    val id: Int,
    val title: String,
    val body: String,
    val target: String,
) {
    companion object {
        private const val X_TAG = "alarm_tag"
        private const val X_ID = "alarm_id"
        private const val X_TITLE = "alarm_title"
        private const val X_BODY = "alarm_body"
        private const val X_TARGET = "alarm_target"

        /** Dari data message FCM. Null bila judulnya kosong (Dart pun membuangnya). */
        fun from(data: Map<String, String>): AlarmData? {
            val title = data["title"].orEmpty()
            if (title.isEmpty()) return null
            val tag = data["tag"].orEmpty()
            val key = if (tag.isEmpty()) (data["id"] ?: title) else tag
            return AlarmData(
                tag = tag,
                id = AlarmNotifier.notificationId(key),
                title = title,
                body = data["body"].orEmpty(),
                target = data["target"].orEmpty(),
            )
        }

        fun fromIntent(intent: Intent): AlarmData? {
            val title = intent.getStringExtra(X_TITLE) ?: return null
            return AlarmData(
                tag = intent.getStringExtra(X_TAG).orEmpty(),
                id = intent.getIntExtra(X_ID, 0),
                title = title,
                body = intent.getStringExtra(X_BODY).orEmpty(),
                target = intent.getStringExtra(X_TARGET).orEmpty(),
            )
        }
    }

    fun putInto(intent: Intent): Intent = intent
        .putExtra(X_TAG, tag)
        .putExtra(X_ID, id)
        .putExtra(X_TITLE, title)
        .putExtra(X_BODY, body)
        .putExtra(X_TARGET, target)
}

/**
 * Notifikasi alarm pengecekan foto, digambar dari Kotlin supaya tidak
 * menunggu mesin Dart menyala (pesan di latar harus melewati isolate sendiri,
 * yang bisa ditunda atau ditahan HP) dan supaya bunyinya milik app, bukan
 * milik sistem.
 *
 * Dulu bunyi alarm dititipkan ke notifikasi sistem (`FLAG_INSISTENT`). Sistem
 * Android punya fitur membungkam bunyi notifikasi lewat tombol volume, jadi
 * orang yang menekan volume karena alarmnya pelan malah mematikannya. Sekarang
 * [AlarmService] memutar bunyinya lewat aliran alarm; tombol volume menaikkan
 * volume alarm, bukan membungkamnya.
 */
object AlarmNotifier {
    /** Alarm di layar (heads-up + layar penuh), TANPA bunyi: bunyinya milik AlarmService. */
    const val CH_LAYAR = "alarm_layar"

    /** Penanda "alarm sedang berbunyi" yang menempel pada AlarmService. */
    const val CH_BUNYI = "alarm_bunyi"

    /**
     * Saluran lama: sistem yang membunyikan. Hanya cadangan bila AlarmService
     * tak bisa dimulai (Android menolak layanan latar), supaya alarm tetap
     * berbunyi walau sekali dan bisa dibungkam tombol volume.
     */
    const val CH_SISTEM = "alarm"

    const val CONTROL_ID = 7001

    // Kontrak ketukan flutter_local_notifications 22.x
    // (FlutterLocalNotificationsPlugin.java): aksi SELECT_NOTIFICATION dengan
    // extra notificationId dan payload. Dengan bentuk yang sama, plugin tetap
    // meneruskan ketukan ke Dart (onDidReceiveNotificationResponse dan
    // getNotificationAppLaunchDetails) walau notifikasinya bukan buatan plugin.
    const val ACTION_SELECT = "SELECT_NOTIFICATION"
    const val EXTRA_NOTIFICATION_ID = "notificationId"
    const val EXTRA_PAYLOAD = "payload"

    /** Penanda: app dibuka oleh full-screen intent, bukan ketukan orangnya. */
    const val EXTRA_FROM_FULL_SCREEN = "alarm_full_screen"

    private val VIBRATION = longArrayOf(0, 800, 400, 800, 400, 800, 1500)

    /**
     * FNV-1a 31 bit atas unit kode UTF-16, sama persis dengan `notificationId`
     * di push_service.dart. Dicek terhadap nilai tetap di
     * test/komunikasi_tahap4_test.dart ('reminder-12' = 597222117).
     */
    fun notificationId(key: String): Int {
        var h = 0x811c9dc5L
        for (c in key) h = ((h xor c.code.toLong()) * 0x01000193L) and 0xffffffffL
        return (h and 0x7fffffffL).toInt()
    }

    private fun manager(ctx: Context) =
        ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun alarmAttributes(): AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    /** Idempotent: aman dipanggil tiap app dibuka maupun dari layanan. */
    fun ensureChannels(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = manager(ctx)

        nm.createNotificationChannel(
            NotificationChannel(CH_LAYAR, "Alarm pengecekan foto", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Permintaan foto kebersihan tampil di layar, juga di atas kunci layar. " +
                    "Bunyinya diputar app lewat volume alarm."
                setSound(null, null)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_BUNYI, "Alarm sedang berbunyi", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Penanda selama alarm berbunyi, dengan tombol Matikan bunyi."
                setSound(null, null)
                enableVibration(false)
            }
        )
        // Nama diperbarui supaya tidak kembar dengan CH_LAYAR di pengaturan HP
        // (saluran ini sudah ada di HP yang memasang versi sebelumnya).
        nm.createNotificationChannel(
            NotificationChannel(CH_SISTEM, "Alarm cadangan (bunyi sistem)", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Dipakai hanya bila alarm tak bisa berbunyi lewat app. Berbunyi walau HP senyap."
                setSound(Settings.System.DEFAULT_ALARM_ALERT_URI, alarmAttributes())
                vibrationPattern = VIBRATION
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )
    }

    private fun launchIntent(ctx: Context): Intent =
        ctx.packageManager.getLaunchIntentForPackage(ctx.packageName) ?: Intent()

    private fun activity(ctx: Context, requestCode: Int, intent: Intent): PendingIntent =
        PendingIntent.getActivity(ctx, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    /**
     * Notifikasi satu alarm. [bunyiSistem] salah (biasa): tanpa bunyi, bunyinya
     * dari AlarmService. Benar: cadangan, sistem yang membunyikan.
     */
    fun build(ctx: Context, a: AlarmData, bunyiSistem: Boolean): Notification {
        val select = { fromFullScreen: Boolean ->
            Intent(launchIntent(ctx))
                .setAction(ACTION_SELECT)
                .putExtra(EXTRA_NOTIFICATION_ID, a.id)
                .putExtra(EXTRA_PAYLOAD, "alarm|${a.target}")
                .putExtra(EXTRA_FROM_FULL_SCREEN, fromFullScreen)
        }
        val dismissed = PendingIntent.getBroadcast(
            ctx,
            a.id,
            Intent(ctx, AlarmActionReceiver::class.java)
                .setAction(AlarmActionReceiver.ACTION_DISMISSED)
                .putExtra(AlarmActionReceiver.EXTRA_TAG, a.tag)
                .putExtra(AlarmActionReceiver.EXTRA_ID, a.id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val b = NotificationCompat.Builder(ctx, if (bunyiSistem) CH_SISTEM else CH_LAYAR)
            .setSmallIcon(R.drawable.ic_notif)
            .setContentTitle(a.title)
            .setContentText(a.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(a.body))
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(activity(ctx, a.id, select(false)))
            // Requestcode berbeda: PendingIntent dikenali dari aksi + kode, bukan
            // dari extra, jadi tanpa ini kedua intent saling menimpa.
            .setFullScreenIntent(activity(ctx, a.id.inv(), select(true)), true)
            .setDeleteIntent(dismissed)
        if (bunyiSistem && Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            b.setSound(Settings.System.DEFAULT_ALARM_ALERT_URI, AudioManager.STREAM_ALARM)
            b.setVibrate(VIBRATION)
        }
        val n = b.build()
        // FLAG_INSISTENT: bunyi sistem berulang sampai notifikasinya disentuh.
        if (bunyiSistem) n.flags = n.flags or Notification.FLAG_INSISTENT
        return n
    }

    /** Penanda foreground untuk AlarmService: alarm sedang berbunyi + tombol Matikan bunyi. */
    fun buildControl(ctx: Context): Notification {
        val silence = PendingIntent.getBroadcast(
            ctx,
            CONTROL_ID,
            Intent(ctx, AlarmActionReceiver::class.java).setAction(AlarmActionReceiver.ACTION_SILENCE),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(ctx, CH_BUNYI)
            .setSmallIcon(R.drawable.ic_notif)
            .setContentTitle("Alarm sedang berbunyi")
            .setContentText("Buka pengecekannya, atau matikan bunyinya.")
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(activity(ctx, CONTROL_ID, launchIntent(ctx)))
            .addAction(0, "Matikan bunyi", silence)
            .build()
    }

    /** Gambar alarm lewat saluran tanpa bunyi (jalan normal). */
    fun post(ctx: Context, a: AlarmData) = notify(ctx, a, build(ctx, a, bunyiSistem = false))

    /** Cadangan: sistem yang membunyikan. Dipakai bila AlarmService tak bisa mulai. */
    fun postSystemSound(ctx: Context, a: AlarmData) {
        ensureChannels(ctx)
        notify(ctx, a, build(ctx, a, bunyiSistem = true))
    }

    private fun notify(ctx: Context, a: AlarmData, n: Notification) =
        manager(ctx).notify(a.tag.ifEmpty { null }, a.id, n)

    fun cancel(ctx: Context, tag: String, id: Int) = manager(ctx).cancel(tag.ifEmpty { null }, id)
}
