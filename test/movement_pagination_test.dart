import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_mobile/data/models/movement_page.dart';
import 'package:pos_mobile/presentation/providers/movement_list_notifier.dart';
import 'package:pos_mobile/presentation/widgets/paged_movement_list.dart';

int _id(Map<String, dynamic> j) => j['id'] as int;

List<Map<String, dynamic>> _rows(int from, int count) => [
  for (var i = 0; i < count; i++) {'id': from - i},
];

void main() {
  group('MovementPage.parse', () {
    test('bentuk halaman {items, total} menghitung hasMore dari total', () {
      final p = MovementPage.parse<int>(
        {'items': _rows(100, 30), 'total': 75, 'page': 1, 'limit': 30},
        _id,
        page: 1,
        limit: 30,
      );
      expect(p.items.length, 30);
      expect(p.total, 75);
      expect(p.hasMore, isTrue);

      final last = MovementPage.parse<int>(
        {'items': _rows(40, 15), 'total': 75},
        _id,
        page: 3,
        limit: 30,
      );
      expect(last.hasMore, isFalse);
    });

    // APK bisa terpasang sebelum BE berpaginasi: BE lama membalas array.
    test('array dari BE lama dianggap satu-satunya halaman', () {
      final p = MovementPage.parse<int>(_rows(10, 10), _id, page: 1, limit: 30);
      expect(p.items.length, 10);
      expect(p.total, 10);
      expect(p.hasMore, isFalse);
    });

    test('data kosong atau asing tidak melempar', () {
      expect(
        MovementPage.parse<int>(null, _id, page: 1, limit: 30).items,
        isEmpty,
      );
      expect(
        MovementPage.parse<int>({'x': 1}, _id, page: 1, limit: 30).hasMore,
        isFalse,
      );
    });
  });

  group('MovementListNotifier', () {
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('memuat halaman 1 lalu menyambung halaman berikutnya', () async {
      final asked = <int>[];
      final n = MovementListNotifier<int>((page, limit) async {
        asked.add(page);
        final start = 1000 - (page - 1) * limit;
        final count = page < 3 ? limit : 5;
        return MovementPage(
          items: [for (var i = 0; i < count; i++) start - i],
          total: 2 * limit + 5,
          hasMore: page < 3,
        );
      });

      await settle();
      expect(n.state.items.length, movementPageLimit);
      expect(n.state.hasMore, isTrue);

      await n.loadMore();
      await n.loadMore();
      expect(n.state.items.length, 2 * movementPageLimit + 5);
      expect(n.state.hasMore, isFalse);

      await n.loadMore(); // sudah habis → tidak meminta lagi
      expect(asked, [1, 2, 3]);
    });

    test('loadMore diabaikan selama permintaan masih berjalan', () async {
      final gate = Completer<void>();
      var calls = 0;
      final n = MovementListNotifier<int>((page, limit) async {
        calls++;
        if (page == 2) await gate.future;
        return MovementPage(items: [page], total: 100, hasMore: true);
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
        final n = MovementListNotifier<int>((page, limit) async {
          if (page == 2 && failPage2) throw 'jaringan putus';
          return MovementPage(items: [page], total: 100, hasMore: true);
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
      final slow = Completer<MovementPage<int>>();
      var round = 0;
      final n = MovementListNotifier<int>((page, limit) {
        round++;
        if (round == 2) return slow.future; // loadMore halaman 2 yang lambat
        return Future.value(
          MovementPage(items: [page * 10 + round], total: 100, hasMore: true),
        );
      });
      await settle();

      unawaited(n.loadMore());
      await n.refresh();
      slow.complete(
        const MovementPage(items: [999], total: 100, hasMore: true),
      );
      await settle();

      expect(n.state.items, isNot(contains(999)));
      expect(n.state.items.length, 1);
    });
  });

  testWidgets('menggulir ke ujung daftar meminta halaman berikutnya', (
    tester,
  ) async {
    final asked = <int>[];
    final n = MovementListNotifier<int>((page, limit) async {
      asked.add(page);
      return MovementPage(
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
              return PagedMovementList<int>(
                state: n.state,
                notifier: n,
                emptyText: 'kosong',
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
      find.text('baris ${1000 + movementPageLimit - 1}'),
      500,
    );
    await tester.pumpAndSettle();
    expect(asked, [1, 2]);
    expect(n.state.items.length, 2 * movementPageLimit);
  });
}
