import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/data/models/shipment_model.dart';
import 'package:pos_mobile/presentation/pages/shipments/shipment_detail_page.dart';
import 'package:pos_mobile/presentation/providers/shipment_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// **Setiap test di sini WAJIB memakai `AppTheme.lightTheme`.**
//
// AppTheme menyetel minimumSize tombol ke `Size.fromHeight(44)` — lebar minimum
// TAK HINGGA — dan itu pernah meruntuhkan satu halaman penuh di layar Minta
// Barang. Dengan MaterialApp polos setelan itu tidak ada, sehingga test lulus
// atas kode yang rusak. Itu betulan terjadi sekali; jangan diulang.
//
// Halaman ini punya dua tombol aksi, jadi justru rawan pada jebakan yang sama.

Shipment _shipment({
  String status = 'shipped',
  String? rejectedReason,
  List<ShipmentLine>? lines,
}) {
  return Shipment(
    id: 3,
    branchId: 7,
    branchName: 'Cabang Sudirman',
    stockRequestId: 5,
    status: status,
    shipperName: 'Admin Gudang',
    shippedAt: '2026-08-30T07:02:11Z',
    rejectedReason: rejectedReason,
    totalCost: 21500,
    lines: lines ??
        [
          ShipmentLine(
            id: 9,
            itemType: 'material',
            itemId: 1,
            name: 'Teh Original',
            unit: 'ml',
            qty: 10000,
            unitCost: 2.15,
            subtotal: 21500,
          ),
          ShipmentLine(
            id: 10,
            itemType: 'topping',
            itemId: 2,
            // Nama panjang: yang biasanya mendorong angka keluar layar.
            name: 'Biscuit Marie Remah Kemasan Besar',
            unit: 'gram',
            qty: 1500,
            unitCost: 30,
            subtotal: 45000,
          ),
        ],
  );
}

Widget _harness(Shipment sh) {
  return ProviderScope(
    overrides: [
      shipmentDetailProvider(sh.id).overrideWith((ref) async => sh),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: ShipmentDetailPage(shipmentId: sh.id),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Halaman ini membaca authProvider, yang menyeret ApiService, yang membaca
  // .env. Tanpa ini test gagal dengan NotInitializedError — pesan yang tidak
  // menyebut .env sama sekali, jadi mudah disalahartikan sebagai bug layout.
  setUpAll(() async {
    await dotenv.load(
      fileName: '.env',
      isOptional: true,
      mergeWith: {'API_BASE_URL': 'http://localhost'},
    );
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  });

  testWidgets('kiriman yang menunggu memperingatkan stok belum bertambah',
      (tester) async {
    await tester.pumpWidget(_harness(_shipment()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('belum masuk stok cabang'), findsOneWidget);
  });

  // Bar tombol diuji terpisah dari halamannya. Tombolnya cuma muncul untuk role
  // yang berwenang, dan berpura-pura login di widget test berarti melawan
  // bootstrap auth yang async — melelahkan, dan tidak menguji apa pun yang
  // penting. Yang penting justru layoutnya, dan itu bisa dirender langsung.
  group('ShipmentActionBar', () {
    Widget bar({bool busy = false}) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ShipmentActionBar(
                  busy: busy,
                  onReceive: () {},
                  onReject: () {},
                ),
              ],
            ),
          ),
        );

    testWidgets('menampilkan dua tombol dan pengingat aturannya',
        (tester) async {
      await tester.pumpWidget(bar());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Terima Kiriman'), findsOneWidget);
      expect(find.text('Tolak Seluruhnya'), findsOneWidget);
      expect(find.textContaining('tidak ada terima sebagian'), findsOneWidget);
    });

    // Inilah jebakan yang meruntuhkan layar Minta Barang: tombol dengan
    // minimumSize lebar tak hingga di dalam Row. Di sini disusun bertumpuk,
    // dan test ini yang menjaganya tetap begitu.
    testWidgets('tidak meruntuhkan layout di layar sempit', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(bar());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // Diuji lewat perilakunya, bukan bentuknya: `ElevatedButton.icon`
    // menghasilkan subkelas privat sehingga `find.byType` tidak cocok, dan
    // yang benar-benar penting memang "menekannya tidak melakukan apa-apa" —
    // bukan properti internal tombolnya.
    testWidgets('menekan tombol saat sedang memproses tidak melakukan apa pun',
        (tester) async {
      var receiveCalls = 0;
      var rejectCalls = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ShipmentActionBar(
                busy: true,
                onReceive: () => receiveCalls++,
                onReject: () => rejectCalls++,
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terima Kiriman'));
      await tester.tap(find.text('Tolak Seluruhnya'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(receiveCalls, 0);
      expect(rejectCalls, 0);
    });

    testWidgets('menekan tombol saat siap memanggil aksinya', (tester) async {
      var receiveCalls = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ShipmentActionBar(
                busy: false,
                onReceive: () => receiveCalls++,
                onReject: () {},
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Terima Kiriman'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(receiveCalls, 1);
    });
  });

  testWidgets('tetap aman di layar sempit', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_shipment()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('aman saat ukuran font sistem dibesarkan', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sh = _shipment();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
      shipmentDetailProvider(sh.id).overrideWith((ref) async => sh),
    ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: ShipmentDetailPage(shipmentId: sh.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // Kiriman yang sudah diputuskan tidak boleh menawarkan tombol apa pun —
  // menekannya cuma akan dijawab 409 oleh server.
  testWidgets('kiriman yang sudah diterima tidak menawarkan tombol',
      (tester) async {
    await tester.pumpWidget(_harness(_shipment(status: 'received')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ShipmentActionBar), findsNothing);
    // Peringatan in-transit juga tidak boleh muncul lagi.
    expect(find.textContaining('belum masuk stok cabang'), findsNothing);
  });

  testWidgets('alasan penolakan ditampilkan', (tester) async {
    await tester.pumpWidget(_harness(
      _shipment(status: 'rejected', rejectedReason: 'segel rusak, teh tumpah'),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('segel rusak, teh tumpah'), findsOneWidget);
  });

}
