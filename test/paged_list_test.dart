import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/data/models/page_result.dart';
import 'package:pos_mobile/presentation/providers/paged_list_notifier.dart';
import 'package:pos_mobile/presentation/widgets/paged_list_view.dart';

int _id(Map<String, dynamic> j) => j['id'] as int;

List<Map<String, dynamic>> _rows(int from, int count) => [
  for (var i = 0; i < count; i++) {'id': from - i},
];

void main() {
  group('PageResult.parse', () {
    test('bentuk halaman {items, total} menghitung hasMore dari total', () {
      final p = PageResult.parse<int>(
        {'items': _rows(100, 30), 'total': 75, 'page': 1, 'limit': 30},
        _id,
        page: 1,
        limit: 30,
      );
      expect(p.items.length, 30);
      expect(p.total, 75);
      expect(p.hasMore, isTrue);

      final last = PageResult.parse<int>(
        {'items': _rows(40, 15), 'total': 75},
        _id,
        page: 3,
        limit: 30,
      );
      expect(last.hasMore, isFalse);
    });

    // APK bisa terpasang sebelum BE berpaginasi: BE lama membalas array.
    test('array dari BE lama dianggap satu-satunya halaman', () {
      final p = PageResult.parse<int>(_rows(10, 10), _id, page: 1, limit: 30);
      expect(p.items.length, 10);
      expect(p.total, 10);
      expect(p.hasMore, isFalse);
    });

    test('data kosong atau asing tidak melempar', () {
      expect(
        PageResult.parse<int>(null, _id, page: 1, limit: 30).items,
        isEmpty,
      );
      expect(
        PageResult.parse<int>({'x': 1}, _id, page: 1, limit: 30).hasMore,
        isFalse,
      );
    });
  });

  group('PagedListNotifier', () {
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('memuat halaman 1 lalu menyambung halaman berikutnya', () async {
      final asked = <int>[];
      final n = PagedListNotifier<int>((page, limit) async {
        asked.add(page);
        final start = 1000 - (page - 1) * limit;
        final count = page < 3 ? limit : 5;
        return PageResult(
          items: [for (var i = 0; i < count; i++) start - i],
          total: 2 * limit + 5,
          hasMore: page < 3,
        );
      });

      await settle();
      expect(n.state.items.length, defaultPageLimit);
      expect(n.state.hasMore, isTrue);

      await n.loadMore();
      await n.loadMore();
      expect(n.state.items.length, 2 * defaultPageLimit + 5);
      expect(n.state.hasMore, isFalse);

      await n.loadMore(); // sudah habis → tidak meminta lagi
      expect(asked, [1, 2, 3]);
    });

    test('loadMore diabaikan selama permintaan masih berjalan', () async {
      final gate = Completer<void>();
      var calls = 0;
      final n = PagedListNotifier<int>((page, limit) async {
        calls++;
        if (page == 2) await gate.future;
        return PageResult(items: [page], total: 100, hasMore: true);
      });
      await settle();

      unawaited(n.loadMore());
      unawaited(n.loadMore());
      unawaited(n.loadMore());
      gate.complete();
      await settle();
      expect(calls, 2);
      expect(n.state.items, [1, 2]);
    });

    test(
      'gagal berhenti memuat otomatis sampai retry, isi lama tetap',
      () async {
        var failPage2 = true;
        final n = PagedListNotifier<int>((page, limit) async {
          if (page == 2 && failPage2) throw 'jaringan putus';
          return PageResult(items: [page], total: 100, hasMore: true);
        });
        await settle();

        await n.loadMore();
        expect(n.state.error, isNotNull);
        expect(n.state.items, [1]);

        await n.loadMore(); // masih error → tidak mengulang sendiri
        expect(n.state.items, [1]);

        failPage2 = false;
        await n.retry();
        expect(n.state.error, isNull);
        expect(n.state.items, [1, 2]);
      },
    );

    test('refresh di tengah muat lanjutan membuang respons lama', () async {
      final slow = Completer<PageResult<int>>();
      var round = 0;
      final n = PagedListNotifier<int>((page, limit) {
        round++;
        if (round == 2) return slow.future; // loadMore halaman 2 yang lambat
        return Future.value(
          PageResult(items: [page * 10 + round], total: 100, hasMore: true),
        );
      });
      await settle();

      unawaited(n.loadMore());
      await n.refresh();
      slow.complete(const PageResult(items: [999], total: 100, hasMore: true));
      await settle();

      expect(n.state.items, isNot(contains(999)));
      expect(n.state.items.length, 1);
    });
  });

  testWidgets('menggulir ke ujung daftar meminta halaman berikutnya', (
    tester,
  ) async {
    final asked = <int>[];
    final n = PagedListNotifier<int>((page, limit) async {
      asked.add(page);
      return PageResult(
        items: [for (var i = 0; i < limit; i++) page * 1000 + i],
        total: 3 * limit,
        hasMore: page < 3,
      );
    });

    StateSetter? rebuild;
    n.addListener((_) => rebuild?.call(() {}), fireImmediately: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return PagedListView<int>(
                state: n.state,
                notifier: n,
                emptyText: 'kosong',
                unit: 'mutasi',
                itemBuilder: (_, v) =>
                    SizedBox(height: 60, child: Text('baris $v')),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(asked, [1]);
    expect(find.text('baris 1000'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('baris ${1000 + defaultPageLimit - 1}'),
      500,
    );
    await tester.pumpAndSettle();
    expect(asked, [1, 2]);
    expect(n.state.items.length, 2 * defaultPageLimit);
  });

  test('PageResult.parse membaca halaman audit stok', () {
    final p = PageResult.parse<int>(
      {
        'items': [
          {'id': 9},
          {'id': 8},
        ],
        'total': 22,
        'page': 1,
        'limit': 20,
      },
      _id,
      page: 2,
      limit: 20,
    );
    expect(p.items, [9, 8]);
    expect(p.hasMore, isFalse); // 2 * 20 >= 22
  });

  test('ukuran halaman bisa diatur per daftar', () async {
    final limits = <int>[];
    final n = PagedListNotifier<int>((page, limit) async {
      limits.add(limit);
      return const PageResult(items: [1], total: 1, hasMore: false);
    }, pageLimit: 20);
    await Future<void>.delayed(Duration.zero);
    expect(limits, [20]);
    expect(n.state.items, [1]);
  });

  testWidgets('pesan gagal dari repository ditampilkan apa adanya', (
    tester,
  ) async {
    final n = PagedListNotifier<int>(
      (page, limit) async => throw 'Pilih cabang dulu',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return PagedListView<int>(
                state: n.state,
                notifier: n,
                unit: 'audit',
                emptyText: 'kosong',
                itemBuilder: (_, v) => Text('$v'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // State dibaca sekali saat build; bangun ulang setelah permintaan gagal.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedListView<int>(
            state: n.state,
            notifier: n,
            unit: 'audit',
            emptyText: 'kosong',
            itemBuilder: (_, v) => Text('$v'),
          ),
        ),
      ),
    );
    expect(find.text('Pilih cabang dulu'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });
}
