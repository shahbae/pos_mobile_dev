import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/data/models/stock_request_model.dart';
import 'package:pos_mobile/presentation/pages/stock_requests/stock_request_form_page.dart';
import 'package:pos_mobile/presentation/providers/stock_request_provider.dart';
import 'package:pos_mobile/theme/app_theme.dart';

// Layar ini pernah runtuh di perangkat asli: "RenderBox was not laid out" pada
// Column terluar, Scaffold, dan bar bawahnya sekaligus.
//
// Penyebabnya `ElevatedButton` sebagai anak non-flex di dalam Row. Sendirian
// itu tidak apa-apa — yang membuatnya fatal adalah `AppTheme.lightTheme`, yang
// menyetel minimumSize tombol ke `Size.fromHeight(44)`, alias lebar minimum
// TAK HINGGA. Di dalam Row lebarnya juga tak terbatas, jadi tombolnya menuntut
// lebar tak hingga dan menggagalkan layout satu halaman penuh.
//
// **Karena itu setiap test di sini WAJIB memakai `AppTheme.lightTheme`.**
// Dengan MaterialApp polos, seluruh test ini lulus padahal aplikasinya rusak —
// itu betulan terjadi, dan sempat membuat saya menyimpulkan halamannya sehat.

RequestableItem _item({
  required String type,
  required int id,
  required String name,
  String unit = 'ml',
  double warehouseQty = 200000,
  int templateCount = 1,
}) {
  return RequestableItem(
    itemType: type,
    itemId: id,
    name: name,
    unit: unit,
    warehouseQty: warehouseQty,
    templates: [
      for (var i = 0; i < templateCount; i++)
        RequestableTemplate(
          id: id * 10 + i,
          name: i == 0 ? 'Pack' : 'Dus',
          baseQty: i == 0 ? 5000 : 20000,
        ),
    ],
  );
}

final _catalogue = <RequestableItem>[
  _item(type: 'material', id: 33, name: 'Teh Original'),
  // Nama panjang: dulu ini yang mendorong kotak jumlah keluar layar.
  _item(
    type: 'material',
    id: 34,
    name: 'Teh Hijau Melati Konsentrat Kemasan Besar',
    templateCount: 2,
  ),
  _item(type: 'topping', id: 4, name: 'Boba', unit: 'gram'),
  _item(type: 'plastic', id: 9, name: 'Cup 22oz', unit: 'pcs'),
  _item(type: 'sedotan', id: 2, name: 'Sedotan Jumbo', unit: 'pcs'),
];

Widget _harness(List<RequestableItem> catalogue) {
  return ProviderScope(
    overrides: [
      requestableItemsProvider.overrideWith((ref) async => catalogue),
    ],
    // WAJIB pakai tema aslinya. AppTheme menyetel minimumSize tombol ke
    // Size.fromHeight(44) — lebar minimum TAK HINGGA — dan itu yang dulu
    // meruntuhkan bar bawah. MaterialApp polos tidak punya setelan itu,
    // sehingga test yang memakainya lulus padahal aplikasinya rusak.
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const StockRequestFormPage(),
    ),
  );
}

void main() {
  testWidgets('halaman minta barang ter-render tanpa error layout',
      (tester) async {
    await tester.pumpWidget(_harness(_catalogue));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Minta Barang'), findsOneWidget);
    // Judul kategori muncul, dan hanya untuk kategori yang ada isinya.
    expect(find.text('BAHAN'), findsOneWidget);
    expect(find.text('TOPPING'), findsOneWidget);
    expect(find.text('Ajukan'), findsOneWidget);
  });

  // Layar sempit itu justru kasus normalnya — kasir pakai HP, bukan tablet.
  testWidgets('tetap aman di layar sempit', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness(_catalogue));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('mengisi jumlah memunculkan terjemahan ke satuan dasar',
      (tester) async {
    await tester.pumpWidget(_harness(_catalogue));
    await tester.pumpAndSettle();

    // Kotak jumlah pertama milik Teh Original: 1 pack = 5.000 ml.
    await tester.enterText(find.byType(TextField).at(1), '2');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Diminta 10000'), findsOneWidget);
    // Penyaring "Diisi" baru muncul setelah ada yang diisi.
    expect(find.textContaining('Diisi (1)'), findsOneWidget);
  });

  _bigTextTests();

  testWidgets('katalog kosong menjelaskan penyebabnya, bukan spinner selamanya',
      (tester) async {
    await tester.pumpWidget(_harness(const []));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Belum ada barang yang bisa diminta'), findsOneWidget);
    // Tidak ada tombol Ajukan kalau tidak ada yang bisa diminta.
    expect(find.text('Ajukan'), findsNothing);
  });
}

// Ukuran font sistem yang dibesarkan adalah kondisi nyata di HP kasir, dan
// salah satu beda antara test dengan perangkat asli. Chip penyaring dulu
// dikurung SizedBox setinggi 32 — teks yang membesar akan melewatinya.
void _bigTextTests() {
  testWidgets('aman saat ukuran font sistem dibesarkan', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requestableItemsProvider.overrideWith((ref) async => _catalogue),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const StockRequestFormPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
