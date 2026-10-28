import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/core/promo_engine.dart';
import 'package:pos_mobile/data/models/promo_model.dart';

// Mesin promo Dart harus menghitung sama persis dengan server. Kasusnya dibaca
// dari salinan be-pos internal/services/testdata/promo_cases.json — kasus baru
// ditambahkan di sana lalu disalin ke sini, jangan di tes ini saja.

final Map<String, dynamic> _file = Map<String, dynamic>.from(
    jsonDecode(File('test/fixtures/promo_cases.json').readAsStringSync()) as Map);

Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from(v as Map);

void main() {
  final templates = _map(_file['promo_templates']);
  final cases = (_file['cases'] as List).map(_map).toList();
  final scopeCases = (_file['scope_cases'] as List).map(_map).toList();

  test('berkas kasus terbaca', () {
    expect(cases, isNotEmpty);
    expect(scopeCases, isNotEmpty);
  });

  group('kasus hitungan', () {
    for (final c in cases) {
      test(c['name'], () {
        final promos = [
          for (final raw in c['promos'] as List)
            Promo.fromJson(raw is String ? _map(templates[raw]) : _map(raw)),
        ];
        final usage = <int, PromoUsage>{
          for (final e in _map(c['usage'] ?? {}).entries)
            int.parse(e.key): PromoUsage(
              total: (_map(e.value)['total'] as num?)?.toInt() ?? 0,
              today: (_map(e.value)['today'] as num?)?.toInt() ?? 0,
            ),
        };
        final m = c['manual'] == null ? null : _map(c['manual']);
        final got = evaluatePricing(
          wib: wibWallClock(DateTime.parse(c['now'] as String)),
          branchId: (c['branch_id'] as num).toInt(),
          channel: (c['channel'] as String?) ?? 'pos',
          lines: [for (final l in c['lines'] as List) PricingLine.fromJson(_map(l))],
          promos: promos,
          usage: usage,
          chosenBuyFree: [for (final id in (c['chosen_buy_free'] as List? ?? const [])) (id as num).toInt()],
          freeDiscount: (c['free_discount'] as num?)?.toInt() ?? 0,
          manual: m == null
              ? null
              : ManualDiscountInput(
                  kind: m['kind'] as String,
                  value: (m['value'] as num).toInt(),
                  limitPct: (m['limit_pct'] as num).toInt(),
                  hasReason: m['has_reason'] as bool? ?? false,
                ),
        );

        final e = _map(c['expect']);
        expect(got.subtotal, e['subtotal'], reason: 'subtotal');
        expect(got.percent?.id, e['percent_id'], reason: 'promo persen');
        expect(got.percent?.discount ?? 0, e['percent_discount'], reason: 'potongan persen');
        if (e['dropped_percent_id'] != null) {
          expect(got.droppedPercent?.id, e['dropped_percent_id'], reason: 'promo dilepas');
        }
        expect(got.manualDiscount, e['manual_discount'] ?? 0, reason: 'diskon manual');
        expect(got.total, e['total'], reason: 'total');
        expect(
          got.violations.map((v) => v.code).toList()..sort(),
          [for (final v in (e['violations'] as List? ?? const [])) v as String]..sort(),
          reason: 'pelanggaran',
        );
      });
    }
  });

  group('kasus cakupan beli X gratis Y', () {
    for (final c in scopeCases) {
      test(c['name'], () {
        final problem = buyFreeScopeProblem(
          Promo.fromJson(_map(c['promo'])),
          [for (final l in c['lines'] as List) PricingLine.fromJson(_map(l))],
          PricingLine.fromJson(_map(c['free'])),
        );
        expect(problem.isEmpty, c['ok'], reason: problem);
      });
    }
  });

  group('jam dinding WIB', () {
    test('HP berzona lain tetap membaca jam WIB', () {
      // 13.30 UTC = 20.30 WIB, Selasa 3 Nov 2026.
      final wib = wibWallClock(DateTime.utc(2026, 11, 3, 13, 30));
      expect([wib.hour, wib.minute, wib.weekday % 7], [20, 30, 2]);
    });

    test('lewat tengah malam WIB berganti tanggal dan hari', () {
      final wib = wibWallClock(DateTime.utc(2026, 11, 3, 17, 5)); // 00.05 WIB Rabu
      expect([wib.day, wib.hour, wib.weekday % 7], [4, 0, 3]);
    });
  });

  group('alasan tidak berlaku', () {
    final p = Promo.fromJson({
      'id': 1, 'name': 'Happy hour', 'kind': 'percent', 'percent': 15, 'days': [1, 2, 3, 4, 5],
      'start_time': '14:00', 'end_time': '16:00', 'is_active': true, 'channel_pos': true,
    });

    test('sebelum jamnya', () {
      final r = promoEligible(p, wibWallClock(DateTime.parse('2026-11-03T13:59:00+07:00')), 7, 'pos', PromoUsage.none);
      expect(r.ok, isFalse);
      expect(r.why, 'Promo "Happy hour" baru berlaku pukul 14.00');
    });

    test('hari yang tidak dipilih', () {
      final r = promoEligible(p, wibWallClock(DateTime.parse('2026-11-01T15:00:00+07:00')), 7, 'pos', PromoUsage.none);
      expect(r.why, 'Promo "Happy hour" tidak berlaku hari Minggu');
    });
  });
}
