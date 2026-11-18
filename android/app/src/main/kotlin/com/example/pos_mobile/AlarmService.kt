package com.example.pos_mobile

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.util.Log
import kotlin.math.ceil

/**
 * Pemutar bunyi alarm pengecekan foto.
 *
 * Bunyinya diputar app sendiri lewat aliran ALARM (MediaPlayer, `USAGE_ALARM`)
 * dan berulang sampai: reminder dibuka atau dijawab (`PushService.cancelTag`),
 * notifikasinya diketuk, "Matikan bunyi" ditekan, notifikasinya digeser, atau
 * [MAX_RING_MS] lewat. Tombol volume HP menaikkan volume alarm; ia TIDAK
 * membungkamnya, tidak seperti bunyi notifikasi sistem.
 *
 * Layanan ini dimulai dari [AlarmMessagingService] saat pesan FCM berprioritas
 * tinggi tiba, tanpa menunggu mesin Dart. Semua status disentuh dari thread
 * utama saja (siklus hidup layanan, kanal Flutter, penerima siaran).
 */
class AlarmService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val alarms = LinkedHashMap<Int, AlarmData>()
    private var player: MediaPlayer? = null
    private var ringtone: Ringtone? = null
    private var ringing = false
    private val ceiling = Runnable {
        Log.i(TAG, "batas waktu bunyi tercapai, dimatikan")
        silenceNow()
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        AlarmNotifier.ensureChannels(this)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val alarm = intent?.let(AlarmData::fromIntent)
        // Setiap startForegroundService wajib dijawab startForeground, bahkan
        // bila datanya tak terbaca; kalau tidak, Android mematikan app.
        try {
            enterForeground()
        } catch (e: Exception) {
            // Android menolak layanan latar (izin dicabut, ROM ketat). Alarm
            // tetap harus sampai: jatuh ke notifikasi bunyi-sistem.
            Log.w(TAG, "tidak bisa menjadi layanan latar: $e")
            if (alarm != null) AlarmNotifier.postSystemSound(this, alarm)
            stopSelf()
            return START_NOT_STICKY
        }
        if (alarm == null && alarms.isEmpty()) {
            silenceNow()
            return START_NOT_STICKY
        }
        if (alarm != null) {
            alarms[alarm.id] = alarm
            AlarmNotifier.post(this, alarm)
        }
        startRinging()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(ceiling)
        stopSound()
        stopVibration()
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun enterForeground() {
        val n = AlarmNotifier.buildControl(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(AlarmNotifier.CONTROL_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(AlarmNotifier.CONTROL_ID, n)
        }
    }

    private fun startRinging() {
        handler.removeCallbacks(ceiling)
        handler.postDelayed(ceiling, MAX_RING_MS)
        if (ringing) return
        ringing = true
        raiseAlarmVolume()
        startSound()
        startVibration()
    }

    /**
     * Alarm yang terlalu pelan sama dengan alarm yang tidak berbunyi, dan
     * volume alarm HP jarang disentuh orang. Dinaikkan sampai [VOLUME_FLOOR]
     * dari maksimum, hanya bila lebih rendah; yang lebih keras dibiarkan.
     */
    private fun raiseAlarmVolume() {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val floor = ceil(am.getStreamMaxVolume(AudioManager.STREAM_ALARM) * VOLUME_FLOOR).toInt()
            if (am.getStreamVolume(AudioManager.STREAM_ALARM) < floor) {
                am.setStreamVolume(AudioManager.STREAM_ALARM, floor, 0)
            }
        } catch (e: Exception) {
            Log.w(TAG, "volume alarm tidak bisa dinaikkan: $e")
        }
    }

    private fun alarmUri(): Uri =
        RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: Settings.System.DEFAULT_ALARM_ALERT_URI

    private fun startSound() {
        val uri = alarmUri()
        try {
            val mp = MediaPlayer()
            player = mp
            mp.setAudioAttributes(AlarmNotifier.alarmAttributes())
            mp.setDataSource(this, uri)
            mp.isLooping = true
            mp.setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
            mp.setOnPreparedListener { it.start() }
            mp.setOnErrorListener { p, what, extra ->
                Log.w(TAG, "MediaPlayer galat what=$what extra=$extra, pindah ke Ringtone")
                p.release()
                if (player === p) player = null
                playRingtone(uri)
                true
            }
            mp.prepareAsync()
        } catch (e: Exception) {
            Log.w(TAG, "MediaPlayer gagal dibuat: $e")
            player?.release()
            player = null
            playRingtone(uri)
        }
    }

    private fun playRingtone(uri: Uri) {
        try {
            ringtone = RingtoneManager.getRingtone(this, uri)?.apply {
                audioAttributes = AlarmNotifier.alarmAttributes()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) isLooping = true
                play()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Ringtone gagal diputar: $e")
        }
    }

    private fun stopSound() {
        player?.let {
            try {
                it.stop()
            } catch (_: IllegalStateException) {
                // Masih menyiapkan: tak ada yang perlu dihentikan, cukup dilepas.
            }
            it.release()
        }
        player = null
        try {
            ringtone?.stop()
        } catch (_: Exception) {
        }
        ringtone = null
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    private fun startVibration() {
        try {
            val v = vibrator() ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                v.vibrate(VibrationEffect.createWaveform(VIBRATION, 0), AlarmNotifier.alarmAttributes())
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(VIBRATION, 0, AlarmNotifier.alarmAttributes())
            }
        } catch (e: Exception) {
            Log.w(TAG, "getar gagal: $e")
        }
    }

    private fun stopVibration() {
        try {
            vibrator()?.cancel()
        } catch (_: Exception) {
        }
    }

    /**
     * Bunyi dan getar berhenti, layanan selesai. Notifikasi alarmnya tetap di
     * bilah (kini biasa, bisa digeser) sampai reminder dibuka atau dijawab.
     */
    fun silenceNow() {
        handler.removeCallbacks(ceiling)
        stopSound()
        stopVibration()
        ringing = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /** Satu alarm selesai (dibuka/dijawab/digeser). Layanan berhenti bila tak ada alarm tersisa. */
    fun dismissNow(tag: String, id: Int) {
        alarms.remove(id)
        AlarmNotifier.cancel(this, tag, id)
        if (alarms.isEmpty()) silenceNow()
    }

    companion object {
        private const val TAG = "AlarmService"

        /** Lamanya paling lama berbunyi; sesudah itu hanya notifikasinya yang tersisa. */
        private const val MAX_RING_MS = 10 * 60 * 1000L

        /** Volume alarm minimum, sebagai pecahan dari maksimum aliran alarm. */
        private const val VOLUME_FLOOR = 0.6

        private val VIBRATION = longArrayOf(0, 800, 400, 800, 400, 800, 1500)

        @Volatile
        private var instance: AlarmService? = null

        /**
         * Mulai atau tambah satu alarm. Dipanggil dari thread layanan FCM.
         * Bila Android menolak memulai layanan latar, notifikasi bunyi-sistem
         * menjadi cadangan: alarm yang berbunyi sekali lebih baik daripada
         * tidak sama sekali.
         */
        fun start(ctx: Context, data: Map<String, String>) {
            val alarm = AlarmData.from(data) ?: return
            val intent = alarm.putInto(Intent(ctx, AlarmService::class.java))
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(intent)
                } else {
                    ctx.startService(intent)
                }
            } catch (e: Exception) {
                Log.w(TAG, "layanan alarm tidak bisa dimulai: $e")
                AlarmNotifier.postSystemSound(ctx, alarm)
            }
        }

        /** Bunyi berhenti, notifikasinya tetap (ketukan, tombol Matikan bunyi). */
        fun silence() {
            instance?.silenceNow()
        }

        /** Reminder dibuka atau dijawab: tutup notifikasinya dan hentikan bunyinya bila itu yang terakhir. */
        fun stopFor(ctx: Context, tag: String) {
            val id = AlarmNotifier.notificationId(tag)
            val s = instance
            if (s != null) s.dismissNow(tag, id) else AlarmNotifier.cancel(ctx, tag, id)
        }

        /** Notifikasi digeser orangnya. */
        fun dismiss(ctx: Context, tag: String, id: Int) {
            val s = instance
            if (s != null) s.dismissNow(tag, id) else AlarmNotifier.cancel(ctx, tag, id)
        }
    }
}
