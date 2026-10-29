import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/help_ticket_model.dart';
import 'package:pos_mobile/data/models/reminder_model.dart';
import 'package:pos_mobile/data/services/push_service.dart';

/// Tahap 4 langkah 5: notifikasi push, reminder, bantuan leader.
void main() {
  group('payload notifikasi', () {
    test('alarm diawali "alarm|" — dibaca MainActivity untuk tampil di atas kunci layar', () {
      expect(payloadOf(alarm: true, target: 'app:/reminders/12'), 'alarm|app:/reminders/12');
      expect(payloadOf(alarm: false, target: 'web:/help-tickets/5'), 'normal|web:/help-tickets/5');
    });

    test('tujuan ketukan dibaca kembali dari payload', () {
      expect(targetOf('alarm|app:/reminders/12'), 'app:/reminders/12');
      expect(targetOf('normal|web:/reminders/3'), 'web:/reminders/3');
      expect(targetOf('normal|'), isNull);
      expect(targetOf(null), isNull);
      // Payload tanpa level (tidak pernah dibuat app ini) tetap terbaca.
      expect(targetOf('app:/schedule'), 'app:/schedule');
    });

    test('id notifikasi stabil per tag, supaya tag sama menggantikan yang lama', () {
      // Nilai tetap: isolate depan, isolate latar, dan jalan app berikutnya
      // harus menghitung angka yang sama.
      expect(notificationId('reminder-12'), notificationId('reminder-12'));
      expect(notificationId('reminder-12'), 597222117); // FNV-1a 32-bit, dihitung terpisah
      expect(notificationId('reminder-12'), isNot(notificationId('reminder-13')));
      expect(notificationId('help-5') >= 0, isTrue);
    });
  });

  group('penerima reminder & bantuan', () {
    test('kru outlet menerima reminder; SPV dan owner tidak', () {
      expect(canReceiveReminders({'karyawan'}), isTrue);
      expect(canReceiveReminders({'kasir'}), isTrue);
      expect(canReceiveReminders({'leader'}), isTrue);
      expect(canReceiveReminders({'supervisor'}), isFalse);
      expect(canReceiveReminders({'owner'}), isFalse);
      expect(canReceiveReminders({'produksi'}), isFalse);
      // Multi-role: satu role kru cukup.
      expect(canReceiveReminders({'supervisor', 'leader'}), isTrue);
    });

    test('hanya leader membuat tiket bantuan dari app', () {
      expect(canUseHelpTickets({'leader'}), isTrue);
      expect(canUseHelpTickets({'karyawan', 'leader'}), isTrue);
      expect(canUseHelpTickets({'supervisor'}), isFalse);
      expect(canUseHelpTickets({'karyawan'}), isFalse);
    });
  });

  group('model reminder', () {
    test('satu reminder membawa server_time sendiri', () {
      final r = MyReminder.fromJson({
        'id': 1,
        'kind': 'check',
        'message': 'Cek sebelum ramai sore.',
        'sender_name': 'Alena',
        'created_at': '2026-10-29T07:00:00Z',
        'branch_id': 2,
        'branch_name': 'Karangampel',
        'duty': 'server',
        'status': 'pending',
        'deadline_minutes': 15,
        'deadline_at': '2026-10-29T07:15:00Z',
        'opened_at': null,
        'read_at': null,
        'replied_at': null,
        'parts': [
          {'id': 1, 'name': 'Lantai area dalam', 'duty': 'server', 'photo': null},
          {
            'id': 2,
            'name': 'Meja penyaji',
            'duty': 'server',
            'photo': {'id': 9, 'url': 'https://x/uploads/a.jpg', 'received_at': '2026-10-29T07:03:00Z', 'verdict': null},
          },
        ],
        'server_time': '2026-10-29T07:05:00Z',
      });
      expect(r.isCheck, isTrue);
      expect(r.isPending, isTrue);
      expect(r.photographed, 1);
      expect(r.parts[1].photo!.judged, isFalse);
      expect(r.deadlineAt!.difference(r.serverTime!), const Duration(minutes: 10));
    });

    test('daftar: server_time di amplop diturunkan ke tiap item', () {
      final page = MyReminderPage.fromJson({
        'server_time': '2026-10-29T07:05:00Z',
        'items': [
          {'id': 3, 'kind': 'note', 'message': 'Stok gula tipis', 'status': 'pending', 'parts': []},
        ],
        'total': 1,
        'page': 1,
        'limit': 20,
      });
      expect(page.total, 1);
      expect(page.items.single.isCheck, isFalse);
      expect(page.items.single.serverTime, DateTime.parse('2026-10-29T07:05:00Z'));
    });
  });

  group('model tiket', () {
    test('aksi, tenggat, dan riwayat terbaca; actor kosong = sistem', () {
      final t = HelpTicket.fromJson({
        'id': 1,
        'branch_name': 'Karangampel',
        'created_by_name': 'Khaerudien',
        'target': 'finance',
        'category_name': 'Permintaan dana',
        'description': 'Uang laci kurang.',
        'photo_url': null,
        'status': 'resolved',
        'due_at': '2026-10-30T16:59:59Z',
        'resolved_by_name': 'Nende',
        'resolution_note': 'Sudah ditransfer.',
        'reopen_count': 0,
        'auto_confirmed': false,
        'auto_confirm_at': '2026-11-02T03:00:00Z',
        'overdue': false,
        'late': false,
        'actions': ['reopen', 'confirm'],
        'events': [
          {'id': 1, 'from_status': '', 'to_status': 'submitted', 'actor_id': 2, 'actor_name': 'Khaerudien'},
          {'id': 2, 'from_status': 'resolved', 'to_status': 'confirmed', 'actor_id': null, 'actor_name': ''},
        ],
      });
      expect(t.can('confirm'), isTrue);
      expect(t.can('approve'), isFalse);
      expect(t.late, isFalse);
      expect(t.events.first.actorName, 'Khaerudien');
      expect(t.events.last.actorName, isNull);
      expect(helpTargetLabels[t.target], 'Finance');
    });
  });
}
