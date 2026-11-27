// Layout baru app kasir (revisi owner 26 Nov 2026, langkah 5): navigasi bawah
// Beranda · Stok · (+) · Laporan · Profil, Setting lewat ikon gir, Tugas
// setiap hari di Laporan, kartu profil → Data diri.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/allowance_model.dart';
import 'package:pos_mobile/data/models/kpi_model.dart';
import 'package:pos_mobile/data/models/profile_model.dart';
import 'package:pos_mobile/data/models/reminder_model.dart';
import 'package:pos_mobile/presentation/pages/dashboard/dashboard_page.dart';
import 'package:pos_mobile/presentation/pages/dashboard/menu_layout.dart';
import 'package:pos_mobile/presentation/pages/profile/profile_summary.dart';
import 'package:pos_mobile/presentation/providers/allowance_provider.dart';
import 'package:pos_mobile/presentation/providers/app_update_provider.dart';
import 'package:pos_mobile/presentation/providers/attendance_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_provider.dart';
import 'package:pos_mobile/presentation/providers/dashboard_index_provider.dart';
import 'package:pos_mobile/presentation/providers/duty_provider.dart';
import 'package:pos_mobile/presentation/providers/kpi_provider.dart';
import 'package:pos_mobile/presentation/providers/offline_provider.dart';
import 'package:pos_mobile/presentation/providers/payroll_provider.dart';
import 'package:pos_mobile/presentation/providers/reminder_provider.dart';
import 'package:pos_mobile/presentation/providers/shipment_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

MenuAccess _access(List<String> roles, {bool? cashierDuty = true, bool hasBranch = true}) {
  final held = heldRoles(roles.first, roles);
  return MenuAccess(
    today: featuresForToday(roles.first, held, cashierDuty: cashierDuty),
    role: roles.first,
    held: held,
    hasBranch: hasBranch,
  );
}

class _FixedAuth extends StateNotifier<AuthState> implements AuthNotifier {
  _FixedAuth(super.state);

  @override
  Future<bool> refreshSession() async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Offline extends StateNotifier<OfflineState> implements OfflineNotifier {
  _Offline() : super(const OfflineState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Update extends AppUpdateNotifier {
  @override
  Future<AppUpdateStatus> build() async => const AppUpdateStatus(installedVersion: '1.0.38', installedCode: 56);
}

List<Override> _overrides(List<String> roles) => [
      authProvider.overrideWith((ref) => _FixedAuth(AuthState(
            status: AuthStatus.authenticated,
            role: roles.first,
            roles: roles,
            branchId: 2,
          ))),
      cashierDutyProvider.overrideWith((ref) async => true),
      offlineProvider.overrideWith((ref) => _Offline()),
      pendingRemindersProvider.overrideWith((ref) async => MyReminderPage(items: const [], total: 0)),
      myProfileProvider.overrideWith((ref) async => ProfileModel.fromJson({
            'id': 6, 'name': 'Aenah', 'email': 'aenah@t.local', 'roles': roles,
          })),
      myAllowanceProvider.overrideWith((ref) async => const MyAllowance(date: '2026-11-27', balance: 20000)),
      myKpiProvider.overrideWith((ref, period) async => MyKpi(period: period, scores: [
            KpiScore(period: period, module: 'CREW', userId: 6, name: 'Aenah', score: 67.8, predicate: 'Kurang'),
            KpiScore(period: period, module: 'LEADER', userId: 6, name: 'Aenah', score: 88.5, predicate: 'Sangat Baik'),
          ])),
      myDayProvider.overrideWith((ref) => Future.error('offline')),
      cashPendingLoansProvider.overrideWith((ref) async => const []),
      shipmentListProvider.overrideWith((ref) async => const []),
      branchListProvider.overrideWith((ref) async => const []),
      appUpdateProvider.overrideWith(_Update.new),
      // Mulai di tab Profil supaya Beranda (data dashboard dari server) tidak dibangun.
      dashboardIndexProvider.overrideWith((ref) => 4),
    ];

Future<void> _pumpDashboard(WidgetTester tester, List<String> roles, Size size) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(roles),
    child: MaterialApp(theme: AppTheme.lightTheme, home: const DashboardPage()),
  ));
  await tester.pumpAndSettle();
}

/// Label navigasi bawah, kiri ke kanan.
List<String> _navLabels(WidgetTester tester) {
  final bar = find.byType(BottomAppBar);
  final texts = tester.widgetList<Text>(find.descendant(of: bar, matching: find.byType(Text)));
  return [for (final t in texts) t.data ?? ''];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await dotenv.load(fileName: '.env', isOptional: true, mergeWith: {'API_BASE_URL': 'http://localhost'});
    await initializeDateFormatting('id_ID', null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (_) async => null,
    );
  });

  group('susunan menu per role', () {
    test('Stok mengikuti urutan owner, Retur Stok tepat setelah Catat Waste', () {
      expect(stockMenu(_access(['leader'])), [
        MenuKey.catatWaste,
        MenuKey.returStok,
        MenuKey.permintaanStok,
        MenuKey.kirimanGudang,
        MenuKey.stokMenipis,
        MenuKey.auditStok,
        MenuKey.stokMaterial,
        MenuKey.stokTopping,
        MenuKey.stokPlastik,
        MenuKey.stokSedotan,
        MenuKey.mutasiMaterial,
        MenuKey.mutasiTopping,
        MenuKey.mutasiPlastik,
        MenuKey.mutasiSedotan,
      ]);
    });

    test('Laporan leader: Tugas setiap hari dulu, Pengeluaran pindah dari Stok', () {
      final menu = reportMenu(_access(['leader']));
      expect(menu.first, MenuKey.tugasHarian);
      expect(menu, containsAllInOrder([
        MenuKey.tugasHarian,
        MenuKey.shiftKasir,
        MenuKey.laporanHarianLeader,
        MenuKey.pengeluaran,
        MenuKey.riwayatPenjualan,
        MenuKey.yangBertugas,
        MenuKey.penjualanOffline,
        MenuKey.riwayatIzinKeluar,
      ]));
      expect(stockMenu(_access(['leader'])), isNot(contains(MenuKey.pengeluaran)));
    });

    test('Tugas setiap hari: leader tanpa Sidak, SPV dengan Sidak', () {
      expect(dailyTaskMenu(_access(['leader'])), [
        MenuKey.monitoringPesanan,
        MenuKey.ceklisFoto,
        MenuKey.reminder,
        MenuKey.setoran,
        MenuKey.bantuan,
        MenuKey.arahanSpv,
      ]);
      expect(dailyTaskMenu(_access(['supervisor'])), contains(MenuKey.sidak));
    });

    test('penyaji: tanpa Shift Kasir, tapi antrean offline tetap terlihat', () {
      final menu = reportMenu(_access(['karyawan'], cashierDuty: false));
      expect(menu, isNot(contains(MenuKey.shiftKasir)));
      expect(menu, contains(MenuKey.penjualanOffline));
    });

    test('Profil: urutan owner, SOP paling bawah; owner tanpa absensi', () {
      final leader = profileMenu(_access(['leader']));
      expect(leader.first, MenuKey.jatahMinum);
      expect(leader.last, MenuKey.sop);
      expect(leader, containsAllInOrder([
        MenuKey.jatahMinum,
        MenuKey.skorKpi,
        MenuKey.jadwalSaya,
        MenuKey.absensi,
        MenuKey.izinKeluar,
        MenuKey.slipGaji,
        MenuKey.pinjaman,
        MenuKey.sop,
      ]));
      expect(profileMenu(_access(['owner'])), isNot(contains(MenuKey.absensi)));
    });

    test('Setting: Perangkat cetak & Produk; Ganti Cabang hanya owner/SPV', () {
      expect(settingMenu(_access(['leader'])), [MenuKey.perangkatCetak, MenuKey.produk]);
      expect(settingMenu(_access(['supervisor'])), contains(MenuKey.gantiCabang));
    });

    test('jabatan di kartu profil', () {
      expect(jobTitle(['leader']), 'Leader');
      expect(jobTitle(['karyawan']), 'Karyawan');
      expect(jobTitle(['finance', 'leader']), 'Leader · Finance');
      expect(jobTitle(['supervisor']), 'Supervisor');
    });
  });

  group('layar HP (360 × 800, tema aplikasi)', () {
    const hp = Size(360, 800);

    testWidgets('navigasi bawah Beranda · Stok · Laporan · Profil, gir Setting di kanan atas', (tester) async {
      await _pumpDashboard(tester, ['leader'], hp);
      expect(_navLabels(tester), ['Beranda', 'Stok', 'Laporan', 'Profil']);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Pengaturan'), findsNothing);
      expect(find.text('Setting'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tab Profil: kartu profil berisi nama, jabatan, skor; menu di bawahnya', (tester) async {
      await _pumpDashboard(tester, ['leader'], hp);
      expect(find.text('Aenah'), findsOneWidget);
      expect(find.text('Leader'), findsWidgets);
      final card = find.byType(ProfileSummaryCard);
      expect(find.descendant(of: card, matching: find.textContaining('Crew 67')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.textContaining('Leader 88')), findsOneWidget);
      expect(find.text('Jatah minum hari ini'), findsOneWidget);
      expect(find.text('Rp 20.000'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('SOP'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('SOP'), findsOneWidget);
    });

    testWidgets('Setting: Perangkat Cetak, Produk, Ganti password, Log out', (tester) async {
      await _pumpDashboard(tester, ['leader'], hp);
      await tester.tap(find.text('Setting'));
      await tester.pumpAndSettle();
      expect(find.text('Perangkat Cetak'), findsOneWidget);
      expect(find.text('Produk'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Log out'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Ganti password'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('Laporan → Tugas Setiap Hari berisi tugas harian leader', (tester) async {
      await _pumpDashboard(tester, ['leader'], hp);
      await tester.tap(find.text('Laporan').last);
      await tester.pumpAndSettle();
      expect(find.text('Tugas Setiap Hari'), findsOneWidget);
      await tester.tap(find.text('Tugas Setiap Hari'));
      await tester.pumpAndSettle();
      for (final t in ['Monitoring Pesanan', 'Ceklis Foto', 'Reminder', 'Setoran', 'Bantuan', 'Arahan SPV']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('Sidak'), findsNothing);
    });

    testWidgets('Stok dibuka dari Catat Waste lalu Retur Stok', (tester) async {
      await _pumpDashboard(tester, ['leader'], hp);
      await tester.tap(find.text('Stok').last);
      await tester.pumpAndSettle();
      final waste = tester.getTopLeft(find.text('Catat Waste')).dy;
      final retur = tester.getTopLeft(find.text('Retur Stok')).dy;
      final minta = tester.getTopLeft(find.text('Permintaan Stok')).dy;
      expect(waste < retur && retur < minta, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('tablet (800 × 1280): rail samping dengan urutan sama', (tester) async {
    await _pumpDashboard(tester, ['leader'], const Size(800, 1280));
    expect(find.byType(BottomAppBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect([for (final d in rail.destinations) (d.label as Text).data], ['Beranda', 'Stok', 'Laporan', 'Profil']);
    expect(find.text('Setting'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
