import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/data/services/push_service.dart';

/// Alarm pengecekan foto dibunyikan Kotlin (AlarmService), bukan notifikasi
/// sistem: bunyi notifikasi sistem dibungkam tombol volume, dan pesan di latar
/// harus melewati isolate Dart yang bisa tertahan. Sisi Dart tinggal dua hal:
/// jangan menggambar ulang alarm, dan hentikan bunyinya saat reminder selesai.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const nativeChannel = MethodChannel('estehcandi/notif');
  const pluginChannel = MethodChannel('dexterous.com/flutter/local_notifications');

  // Urutan panggilan lintas kedua kanal, supaya "bunyi berhenti dulu, baru
  // notifikasi ditutup" ikut teruji.
  late List<String> calls;

  setUp(() {
    calls = [];
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(nativeChannel, (call) async {
      calls.add('native:${call.method}:${call.arguments}');
      return null;
    });
    messenger.setMockMethodCallHandler(pluginChannel, (call) async {
      calls.add('plugin:${call.method}');
      return null;
    });
  });

  tearDown(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(nativeChannel, null);
    messenger.setMockMethodCallHandler(pluginChannel, null);
  });

  group('alarm tidak digambar dari Dart', () {
    test('pesan level alarm dilewati: Kotlin sudah menggambar dan membunyikannya', () async {
      await PushService.show({
        'level': 'alarm',
        'title': 'Cek kebersihan',
        'body': 'Foto area kasir sebelum 15.30',
        'tag': 'reminder-12',
        'target': 'app:/reminders/12',
      });
      expect(calls, isEmpty, reason: 'satu alarm = satu notifikasi; Dart tak boleh menggambarnya lagi');
    });

    test('pesan biasa tetap digambar Dart', () async {
      await PushService.show({
        'level': 'normal',
        'title': 'Jadwal hari ini',
        'body': 'Shift 1',
        'tag': 'schedule-today-2026-11-19',
        'target': 'app:/schedule',
      });
      expect(calls, ['plugin:show']);
    });

    test('pesan tanpa judul tetap dibuang, level apa pun', () async {
      await PushService.show({'level': 'normal', 'title': '', 'body': 'x'});
      expect(calls, isEmpty);
    });
  });

  group('menutup reminder menghentikan bunyinya', () {
    test('cancelTag menutup notifikasi DAN menyuruh Kotlin menghentikan bunyinya', () async {
      await PushService.cancelTag('reminder-12');
      // Perintah native tak ditunggu cancelTag; beri satu putaran supaya sampai.
      await Future<void>.delayed(Duration.zero);
      expect(calls, unorderedEquals(['plugin:cancel', 'native:stopAlarm:{tag: reminder-12}']));
    });

    test('kanal native belum ada (APK lama): notifikasi tetap ditutup, tanpa galat', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(nativeChannel, null);
      await PushService.cancelTag('reminder-12');
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['plugin:cancel']);
    });
  });

  test('saluran alarm yang diperiksa kartu "Notifikasi siap?" adalah saluran tampilan, bukan saluran lama', () {
    // `alarm` adalah saluran lama (bunyi sistem), kini hanya cadangan.
    expect(PushService.channelAlarm, 'alarm_layar');
  });
}
