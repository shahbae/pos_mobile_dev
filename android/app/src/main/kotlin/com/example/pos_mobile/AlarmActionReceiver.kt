package com.example.pos_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Tombol dan geseran pada notifikasi alarm. Penerima siaran, bukan layanan:
 * siaran dari notifikasi boleh datang saat app di latar, sedangkan memulai
 * layanan dari sana bisa ditolak Android.
 */
class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_SILENCE -> AlarmService.silence()
            ACTION_DISMISSED -> AlarmService.dismiss(
                context,
                intent.getStringExtra(EXTRA_TAG).orEmpty(),
                intent.getIntExtra(EXTRA_ID, 0),
            )
        }
    }

    companion object {
        const val ACTION_SILENCE = "com.example.pos_mobile.ALARM_SILENCE"
        const val ACTION_DISMISSED = "com.example.pos_mobile.ALARM_DISMISSED"
        const val EXTRA_TAG = "alarm_tag"
        const val EXTRA_ID = "alarm_id"
    }
}
