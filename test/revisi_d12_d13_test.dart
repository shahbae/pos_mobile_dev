import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/allowance_model.dart';
import 'package:pos_mobile/data/models/help_ticket_model.dart';
import 'package:pos_mobile/data/models/page_result.dart';
import 'package:pos_mobile/data/repositories/allowance_repository.dart';
import 'package:pos_mobile/data/repositories/help_repository.dart';
import 'package:pos_mobile/presentation/pages/allowance/my_allowance_page.dart';
import 'package:pos_mobile/presentation/pages/help/help_ticket_detail_page.dart';
import 'package:pos_mobile/presentation/providers/allowance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/help_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

/// Revisi meeting owner 5 Nov. D12: pesan jatah sendiri dari Jatah Saya.
/// D13: tiket bantuan ditandai selesai oleh leader pengaju.

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);
  @override
  Future<bool> refreshSession() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthState _auth(List<String> roles) =>
    AuthState(status: AuthStatus.authenticated, role: roles.first, roles: roles, branchId: 7);

Map<String, dynamic> _ticket({String status = 'approved', List<String> actions = const ['resolve'], String? note}) => {
      'id': 9,
      'branch_name': 'Karangampel',
      'created_by_name': 'Khaerudien',
      'target': 'supervisor',
      'category_name': 'Alat rusak',
      'description': 'Blender mati.',
      'photo_url': null,
      'status': status,
      'due_at': '2026-11-30T10:00:00Z',
      'approved_by_name': 'Alena',
      'resolved_by_name': status == 'resolved' ? 'Khaerudien' : null,
      'resolved_at': status == 'resolved' ? '2026-11-07T03:00:00Z' : null,
      'resolution_note': note,
      'overdue': false,
      'late': status == 'resolved' ? false : null,
      'actions': actions,
      'events': [
        {'id': 1, 'from_status': '', 'to_status': 'submitted', 'actor_id': 5, 'actor_name': 'Khaerudien'},
      ],
    };

class _HelpRepo implements HelpRepository {
  HelpTicket ticket;
  final notes = <String>[];
  _HelpRepo(this.ticket);

  @override
  Future<HelpTicket> one(int id) async => ticket;

  @override
  Future<HelpTicket> resolve(int id, {String note = ''}) async {
    notes.add(note);
    ticket = HelpTicket.fromJson(_ticket(status: 'resolved', actions: const [], note: note.isEmpty ? null : note));
    return ticket;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _AllowanceRepo implements AllowanceRepository {
  final int balance;
  _AllowanceRepo(this.balance);

  @override
  Future<MyAllowance> mine() async => MyAllowance(date: '2026-11-07', balance: balance);

  @override
  Future<PageResult<AllowanceOrder>> myOrders(int page, int limit) async =>
      const PageResult(items: [], total: 0, hasMore: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _pump(WidgetTester tester, Widget page, List<Override> overrides) async {
  tester.view.physicalSize = const Size(720, 1600); // HP 360 × 800 dp
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.lightTheme, home: page),
  ));
  await tester.pumpAndSettle();
}

// Tombol .icon adalah subkelas privat, jadi dicari lewat predikat.
Finder get _orderButton => find.ancestor(
      of: find.text('Pesan jatah'),
      matching: find.byWidgetPredicate((w) => w is ElevatedButton),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    Intl.defaultLocale = 'id_ID';
    // Layar tiket mematikan notifikasinya saat dibuka (cancelTag).
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => null,
    );
  });

  group('D12 Jatah Saya', () {
    Future<void> open(WidgetTester tester, List<String> roles, int balance) => _pump(tester, const MyAllowancePage(), [
          authProvider.overrideWith((ref) => _FixedAuth(_auth(roles))),
          allowanceRepositoryProvider.overrideWithValue(_AllowanceRepo(balance)),
        ]);

    testWidgets('penyaji yang punya saldo melihat tombol Pesan jatah selebar layar', (tester) async {
      await open(tester, ['karyawan'], 20000);
      expect(tester.takeException(), isNull);
      expect(_orderButton, findsOneWidget);
      expect(find.text('Pesan jatah'), findsOneWidget);
      expect(tester.getRect(_orderButton).width, greaterThan(300));
    });

    testWidgets('saldo habis: tombol tidak tampil', (tester) async {
      await open(tester, ['karyawan'], 0);
      expect(find.text('Pesan jatah'), findsNothing);
    });

    testWidgets('finance tidak memesan dari app kasir', (tester) async {
      await open(tester, ['finance'], 20000);
      expect(find.text('Pesan jatah'), findsNothing);
    });

    testWidgets('leader juga bisa', (tester) async {
      await open(tester, ['leader'], 20000);
      expect(find.text('Pesan jatah'), findsOneWidget);
    });
  });

  group('D13 tiket bantuan', () {
    testWidgets('disetujui: leader menandai selesai dengan keterangan', (tester) async {
      final repo = _HelpRepo(HelpTicket.fromJson(_ticket()));
      await _pump(tester, const HelpTicketDetailPage(ticketId: 9), [
        helpRepositoryProvider.overrideWithValue(repo),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.text('Konfirmasi selesai'), findsNothing);
      expect(find.text('Buka kembali'), findsNothing);
      final button = find.text('Tandai selesai');
      expect(button, findsOneWidget);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Tandai selesai?'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Keterangan (opsional)'), 'Blender diganti');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Tandai selesai')));
      await tester.pumpAndSettle();
      expect(repo.notes, ['Blender diganti']);
      expect(find.text('Tandai selesai'), findsNothing);
      expect(find.textContaining('Ditandai selesai oleh Khaerudien'), findsOneWidget);
      expect(find.text('Blender diganti'), findsOneWidget);
    });

    testWidgets('batal di dialog: tiket tidak berubah', (tester) async {
      final repo = _HelpRepo(HelpTicket.fromJson(_ticket()));
      await _pump(tester, const HelpTicketDetailPage(ticketId: 9), [helpRepositoryProvider.overrideWithValue(repo)]);
      final button = find.text('Tandai selesai');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(repo.notes, isEmpty);
      expect(find.text('Tandai selesai'), findsOneWidget);
    });

    testWidgets('selesai tanpa keterangan: kartu tetap tampil, tombol hilang', (tester) async {
      final repo = _HelpRepo(HelpTicket.fromJson(_ticket(status: 'resolved', actions: const [])));
      await _pump(tester, const HelpTicketDetailPage(ticketId: 9), [helpRepositoryProvider.overrideWithValue(repo)]);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Ditandai selesai oleh Khaerudien'), findsOneWidget);
      expect(find.text('Tandai selesai'), findsNothing);
    });
  });
}
