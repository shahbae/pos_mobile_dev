import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:pos_mobile/data/services/api_services.dart';
import 'package:pos_mobile/data/services/app_identity.dart';

/// Notifikasi push (Tahap 4). Kontrak: be-pos `docs/api-push-fe.md`.
///
/// Server mengirim *data message* tanpa blok `notification`, jadi app yang
/// menggambar notifikasinya — di depan lewat [FirebaseMessaging.onMessage], di
/// latar dan saat app mati lewat [pushBackgroundHandler]. Dua saluran:
/// - `biasa`: jadwal, catatan reminder, tiket bantuan.
/// - `alarm`: permintaan pengecekan foto. Berbunyi lewat volume alarm (tetap
///   terdengar di mode senyap), berulang sampai dibuka, dan menyalakan layar
///   di atas kunci layar.
///
/// Ketukan tidak membuka layar dari sini: tujuannya ditaruh di
/// [pendingTarget], lalu `PushBinder` — yang hidup di bawah navigator sesi
/// yang sedang login — membukanya.
class PushService {
  PushService._();

  static const channelNormal = 'biasa';
  static const channelAlarm = 'alarm';

  static final _local = FlutterLocalNotificationsPlugin();
  static const _native = MethodChannel('estehcandi/notif');

  /// Firebase berhasil disiapkan. Salah bila APK dibangun tanpa
  /// google-services.json (flavor prod sebelum terdaftar): app tetap jalan,
  /// hanya tanpa push.
  static bool available = false;

  /// Tujuan ketukan yang belum dibuka (`app:/…` atau `web:/…`).
  static final pendingTarget = ValueNotifier<String?>(null);

  /// Bertambah setiap notifikasi masuk saat app terbuka, supaya layar yang
  /// bergantung padanya (reminder belum dibalas) menyegarkan diri.
  static final received = ValueNotifier<int>(0);

  static StreamSubscription<String>? _tokenRefresh;

  /// Dipanggil sekali di `main()`.
  static Future<void> init() async {
    await _initLocal();
    await _createChannels();

    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      pendingTarget.value = targetOf(launch?.notificationResponse?.payload);
    }

    try {
      await Firebase.initializeApp();
      available = true;
    } catch (e) {
      debugPrint('[push] Firebase tidak tersedia: $e');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
    FirebaseMessaging.onMessage.listen((m) {
      unawaited(show(m.data));
      received.value++;
    });
  }

  static Future<void> _initLocal() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notif'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final target = targetOf(r.payload);
        if (target != null) pendingTarget.value = target;
      },
    );
  }

  static Future<void> _createChannels() async {
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(_normalChannel);
    await android.createNotificationChannel(_alarmChannel);
  }

  static const _normalChannel = AndroidNotificationChannel(
    channelNormal,
    'Notifikasi',
    description: 'Jadwal, catatan dari SPV atau leader, dan tiket bantuan.',
    importance: Importance.high,
  );

  static final _alarmSound = UriAndroidNotificationSound('content://settings/system/alarm_alert');

  static final _alarmChannel = AndroidNotificationChannel(
    channelAlarm,
    'Alarm pengecekan foto',
    description: 'Permintaan foto kebersihan. Berbunyi walau HP dalam mode senyap.',
    importance: Importance.max,
    sound: _alarmSound,
    audioAttributesUsage: AudioAttributesUsage.alarm,
    vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 800]),
  );

  /// Gambar satu notifikasi dari isi pesan server. Dipakai di depan dan di
  /// latar (isolate terpisah).
  static Future<void> show(Map<String, dynamic> data) async {
    final title = '${data['title'] ?? ''}';
    if (title.isEmpty) return;
    final body = '${data['body'] ?? ''}';
    final tag = '${data['tag'] ?? ''}';
    final target = '${data['target'] ?? ''}';
    final alarm = data['level'] == 'alarm';

    final details = alarm
        ? AndroidNotificationDetails(
            channelAlarm,
            _alarmChannel.name,
            channelDescription: _alarmChannel.description,
            importance: Importance.max,
            priority: Priority.max,
            sound: _alarmSound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            vibrationPattern: _alarmChannel.vibrationPattern,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            // FLAG_INSISTENT: suara berulang sampai notifikasinya disentuh.
            additionalFlags: Int32List.fromList([4]),
            visibility: NotificationVisibility.public,
            styleInformation: BigTextStyleInformation(body),
            tag: tag.isEmpty ? null : tag,
          )
        : AndroidNotificationDetails(
            channelNormal,
            _normalChannel.name,
            channelDescription: _normalChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
            tag: tag.isEmpty ? null : tag,
          );

    await _local.show(
      id: notificationId(tag.isEmpty ? '${data['id'] ?? title}' : tag),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
      payload: payloadOf(alarm: alarm, target: target),
    );
  }

  /// Tutup notifikasi bertag itu, mis. alarm reminder yang layarnya sudah
  /// dibuka.
  static Future<void> cancelTag(String tag) => _local.cancel(id: notificationId(tag), tag: tag);

  /// `POST /me/push-devices`. Dipanggil saat sesi mulai dan tiap app kembali
  /// ke depan (memperbarui `last_seen_at`). Gagal diam-diam: notifikasi bukan
  /// alasan mengganggu kasir yang sedang bekerja.
  static Future<void> register(ApiService api) async {
    if (!available) return;
    try {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      // getToken/onTokenRefresh ditandai usang sejak firebase_messaging 17
      // demi register()/onRegistered, yang memberi Firebase Installation ID
      // untuk model kirim lain. be-pos mengirim lewat FCM HTTP v1 ke
      // registration token, dan token itulah yang dikembalikan getToken.
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _post(api, token);
      // ignore: deprecated_member_use
      _tokenRefresh ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) => _post(api, t));
    } catch (e) {
      debugPrint('[push] gagal mendaftarkan token: $e');
    }
  }

  static Future<void> _post(ApiService api, String token) async {
    try {
      await api.dio.post('/me/push-devices', data: {
        'token': token,
        'app': AppIdentity.name,
        'app_version': AppIdentity.versionName,
      });
    } catch (e) {
      debugPrint('[push] POST /me/push-devices gagal: $e');
    }
  }

  // ------------------------------------------------- kesiapan HP (Profil)

  static Future<bool> notificationsEnabled() async =>
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled() ??
      true;

  /// Minta izin notifikasi; bila sudah pernah ditolak permanen, buka
  /// pengaturan notifikasi app.
  static Future<void> requestNotifications() async {
    final granted = await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    if (granted != true) await _call('openAppNotificationSettings');
  }

  static Future<bool> channelEnabled(String id) async =>
      await _native.invokeMethod<bool>('channelEnabled', {'id': id}) ?? true;
  static Future<void> openChannelSettings(String id) => _call('openChannelSettings', {'id': id});
  static Future<bool> canUseFullScreenIntent() async =>
      await _native.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
  static Future<void> openFullScreenIntentSettings() => _call('openFullScreenIntentSettings');
  static Future<bool> ignoringBatteryOptimizations() async =>
      await _native.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? true;
  static Future<void> requestIgnoreBatteryOptimizations() => _call('requestIgnoreBatteryOptimizations');

  /// Lepas izin tampil di atas kunci layar sesudah layar alarm ditutup.
  static Future<void> releaseLockScreen() => _call('setShowOverLock', {'on': false});

  static Future<void> _call(String method, [Map<String, dynamic>? args]) async {
    try {
      await _native.invokeMethod<void>(method, args);
    } catch (e) {
      debugPrint('[push] $method gagal: $e');
    }
  }
}

/// Isi payload notifikasi lokal: `<level>|<target>`. Awalan `alarm|` dibaca
/// MainActivity untuk menampilkan app di atas kunci layar.
@visibleForTesting
String payloadOf({required bool alarm, required String target}) => '${alarm ? 'alarm' : 'normal'}|$target';

/// Tujuan ketukan dari payload, atau null bila kosong.
String? targetOf(String? payload) {
  if (payload == null) return null;
  final cut = payload.indexOf('|');
  final target = cut < 0 ? payload : payload.substring(cut + 1);
  return target.isEmpty ? null : target;
}

/// Id notifikasi Android dari tag (FNV-1a 31 bit). Harus sama di isolate depan
/// dan latar, juga antar-jalan app, supaya tag yang sama menggantikan
/// notifikasi lama — `String.hashCode` tidak menjanjikan itu.
int notificationId(String key) {
  var h = 0x811c9dc5;
  for (final c in key.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// Pesan yang tiba saat app di latar atau mati. Berjalan di isolate sendiri,
/// jadi plugin notifikasi lokal disiapkan ulang di sini.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  await PushService._initLocal();
  await PushService.show(message.data);
}
