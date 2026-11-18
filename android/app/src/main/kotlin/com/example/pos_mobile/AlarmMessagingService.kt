package com.example.pos_mobile

import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Layanan FCM milik app, menggantikan yang dipasang plugin firebase_messaging
 * (lihat AndroidManifest: entri plugin dibuang). Turunannya mewarisi semua
 * kerja plugin (token baru, dst.); plugin sendiri meneruskan pesan ke Dart lewat
 * penerima siarannya, bukan lewat layanan ini, jadi `onMessageReceived` bebas
 * dipakai.
 *
 * Pesan `level=alarm` dibunyikan di sini, langsung di Kotlin: alarm tak boleh
 * bergantung pada mesin Dart yang harus menyala dulu di isolate latar. Dart
 * sendiri tidak lagi menggambar notifikasi alarm (lihat `PushService.show`).
 */
class AlarmMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        if (message.data["level"] == "alarm") {
            AlarmService.start(applicationContext, message.data)
        }
    }
}
