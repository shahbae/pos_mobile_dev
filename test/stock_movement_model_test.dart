import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/data/models/page_result.dart';
import 'package:pos_mobile/data/models/stock_movement_model.dart';

void main() {
  // Bentuk yang benar-benar dikirim BE prod (quantity decimal → string).
  const row = {
    'id': 131505,
    'material_id': 33,
    'branch_id': 7,
    'type': 'ADJUST',
    'quantity': '72',
    'reference_type': 'migrasi',
    'reference_id': 0,
    'created_at': '2026-09-27T07:24:23.468+07:00',
  };

  test('quantity string dari BE dibaca sebagai desimal', () {
    expect(StockMovementModel.fromJson(Map.of(row)).quantity, 72);
    expect(StockMovementModel.fromJson({...row, 'quantity': '12.5'}).quantity, 12.5);
    expect(StockMovementModel.fromJson({...row, 'quantity': 3}).quantity, 3);
    expect(StockMovementModel.fromJson({...row, 'quantity': null}).quantity, 0);
  });

  test('halaman riwayat mutasi bahan dari BE prod bisa dibaca utuh', () {
    final page = PageResult.parse(
      {
        'items': [row, {...row, 'id': 131504, 'quantity': '9087.5'}],
        'total': 17359,
        'page': 1,
        'limit': 30,
      },
      StockMovementModel.fromJson,
      page: 1,
      limit: 30,
    );
    expect(page.items.map((m) => m.quantity), [72, 9087.5]);
    expect(page.hasMore, isTrue);
  });
}
