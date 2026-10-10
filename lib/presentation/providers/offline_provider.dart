import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/local/outbox_store.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/models/product_transaction_model.dart';
import 'package:pos_mobile/data/models/receipt_model.dart';
import 'package:pos_mobile/data/offline/offline_sale.dart';
import 'package:pos_mobile/data/repositories/product_transaction_repository.dart';
import 'package:pos_mobile/presentation/providers/pos_catalog_provider.dart';
import 'package:pos_mobile/presentation/providers/product_transaction_provider.dart';

final outboxStoreProvider = Provider<OutboxStore>((ref) {
  return OutboxStore(ref.watch(kasirLocalDbProvider));
});

/// Seberapa sering server dicoba lagi selama mode offline.
const offlineRetryInterval = Duration(seconds: 30);

/// Berapa lama penjualan yang sudah terkirim masih disimpan di HP (untuk cetak
/// ulang nota) sebelum dibuang.
const outboxKeepSent = Duration(days: 7);

/// Yang diingat HP tentang sesi kasir di sebuah cabang, supaya penjualan
/// offline tahu shift dan kasirnya tanpa bertanya ke server.
class OfflineSession {
  /// 0 = server terakhir bilang belum ada shift terbuka.
  final int shiftId;
  final String shiftName;
  final int cashierId;
  final String cashierName;

  /// Jam server dikurangi jam HP, dalam milidetik, saat terakhir terhubung.
  final int clockOffsetMs;

  const OfflineSession({
    this.shiftId = 0,
    this.shiftName = '',
    this.cashierId = 0,
    this.cashierName = '',
    this.clockOffsetMs = 0,
  });

  bool get hasShift => shiftId > 0;
  bool get hasCashier => cashierId > 0;

  Map<String, dynamic> toJson() => {
        'shift_id': shiftId,
        'shift_name': shiftName,
        'cashier_id': cashierId,
        'cashier_name': cashierName,
        'clock_offset_ms': clockOffsetMs,
      };

  factory OfflineSession.fromJson(Map<String, dynamic> j) => OfflineSession(
        shiftId: (j['shift_id'] as num?)?.toInt() ?? 0,
        shiftName: j['shift_name']?.toString() ?? '',
        cashierId: (j['cashier_id'] as num?)?.toInt() ?? 0,
        cashierName: j['cashier_name']?.toString() ?? '',
        clockOffsetMs: (j['clock_offset_ms'] as num?)?.toInt() ?? 0,
      );
}

class OfflineState {
  /// Apakah server terjangkau menurut percobaan terakhir.
  final bool reachable;

  /// Penjualan cabang ini yang belum terkirim.
  final int pending;

  /// Penjualan cabang ini yang ditolak server dan menunggu ditangani.
  final int failed;

  /// Sedang mengirim antrean.
  final bool sending;

  const OfflineState({this.reachable = true, this.pending = 0, this.failed = 0, this.sending = false});

  /// Mode offline: server tak terjangkau, ATAU masih ada penjualan yang belum
  /// terkirim. Yang kedua menjaga urutan — penjualan baru ikut antre di
  /// belakang yang lama, tidak menyalipnya lewat jalur online.
  bool get active => !reachable || pending > 0;

  OfflineState copyWith({bool? reachable, int? pending, int? failed, bool? sending}) => OfflineState(
        reachable: reachable ?? this.reachable,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        sending: sending ?? this.sending,
      );
}

/// Kenapa sebuah penjualan tidak bisa disimpan sebagai penjualan offline.
class OfflineUnavailable implements Exception {
  final String message;
  const OfflineUnavailable(this.message);

  @override
  String toString() => message;
}

/// Hasil menyimpan satu penjualan offline: baris antreannya dan notanya.
class OfflineSale {
  final OutboxEntry entry;
  final Receipt receipt;
  const OfflineSale(this.entry, this.receipt);
}

/// Mode offline kasir cabang aktif: tahu apakah server terjangkau, menyimpan
/// penjualan saat tidak, dan mengirimkannya begitu bisa.
final offlineProvider = StateNotifierProvider<OfflineNotifier, OfflineState>((ref) {
  final notifier = OfflineNotifier(
    store: ref.watch(outboxStoreProvider),
    repo: ref.watch(productTransactionRepositoryProvider),
    branchId: ref.watch(activeBranchIdProvider),
  );
  notifier.start();
  return notifier;
});

class OfflineNotifier extends StateNotifier<OfflineState> {
  final OutboxStore store;
  final ProductTransactionRepository repo;
  final int? branchId;
  final Duration retryInterval;
  final DateTime Function() _now;

  Timer? _timer;
  Future<void>? _flushing;

  OfflineNotifier({
    required this.store,
    required this.repo,
    required this.branchId,
    this.retryInterval = offlineRetryInterval,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(const OfflineState());

  /// Baca antrean yang tertinggal dari sesi sebelumnya dan coba kirim.
  Future<void> start() async {
    await _refreshCounts();
    if (!mounted) return;
    if (state.pending > 0) await probe();
  }

  // ── tanda dari bagian lain aplikasi ────────────────────────────────────

  /// Server baru saja menjawab permintaan katalog. Selain menandai server
  /// terjangkau, jawaban itu membawa shift, kasir, dan jam server yang perlu
  /// diingat untuk penjualan offline berikutnya.
  Future<void> onCatalogAnswer(PosCatalogFetch fetch) async {
    final id = branchId;
    if (id != null) {
      try {
        final previous = await session();
        final next = OfflineSession(
          shiftId: fetch.shift?.id ?? 0,
          shiftName: fetch.shift?.name ?? '',
          cashierId: fetch.cashierId > 0 ? fetch.cashierId : previous.cashierId,
          cashierName: fetch.cashierId > 0 ? fetch.cashierName : previous.cashierName,
          clockOffsetMs: fetch.clockOffset?.inMilliseconds ?? previous.clockOffsetMs,
        );
        await store.setMeta(_sessionKey(id), jsonEncode(next.toJson()));
        if (fetch.shift != null) {
          await store.observeQueueNo(fetch.shift!.id, fetch.shift!.lastQueueNo);
        }
      } catch (_) {
        // Gagal mengingat tidak boleh mengganggu jualan online.
      }
    }
    await _reached();
  }

  /// Permintaan ke server gagal. Dipastikan dulu dengan satu percobaan ringan
  /// sebelum layar berubah ke mode offline.
  Future<void> onRequestFailed() => probe();

  /// Percobaan bayar tidak mendapat jawaban sama sekali: server dianggap tak
  /// terjangkau sampai percobaan berkala membuktikan sebaliknya.
  void markUnreachable() {
    if (!mounted) return;
    state = state.copyWith(reachable: false);
    _schedule();
  }

  /// Server memberi nomor antrean lewat penjualan online; diingat supaya
  /// penjualan offline berikutnya melanjutkannya.
  Future<void> observeQueueNo(int queueNo) async {
    if (queueNo <= 0) return;
    try {
      final s = await session();
      if (s.hasShift) await store.observeQueueNo(s.shiftId, queueNo);
    } catch (_) {}
  }

  /// Shift cabang ini baru ditutup: yang tersimpan tidak boleh dipakai lagi.
  Future<void> forgetShift() async {
    final id = branchId;
    if (id == null) return;
    final s = await session();
    await store.setMeta(
      _sessionKey(id),
      jsonEncode(OfflineSession(
        cashierId: s.cashierId,
        cashierName: s.cashierName,
        clockOffsetMs: s.clockOffsetMs,
      ).toJson()),
    );
  }

  /// Sesi terakhir yang diingat untuk cabang aktif.
  Future<OfflineSession> session() async {
    final id = branchId;
    if (id == null) return const OfflineSession();
    final raw = await store.meta(_sessionKey(id));
    if (raw == null) return const OfflineSession();
    try {
      return OfflineSession.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const OfflineSession();
    }
  }

  // ── menyimpan penjualan ────────────────────────────────────────────────

  /// Simpan keranjang sebagai penjualan offline dan kosongkan keranjangnya.
  ///
  /// Nota baru dikembalikan setelah penjualannya tertulis di HP. Melempar
  /// [OfflineUnavailable] bila cabang ini tidak boleh, atau belum bisa,
  /// berjualan offline.
  Future<OfflineSale> record({
    required ProductTransactionNotifier cart,
    required PosCatalog? catalog,
    required int paid,
    String? customerName,
  }) async {
    final id = branchId;
    if (id == null) throw const OfflineUnavailable('Cabang aktif belum diketahui.');
    if (catalog == null) {
      throw const OfflineUnavailable('Menu belum pernah dimuat di HP ini, jadi belum bisa jualan offline.');
    }
    if (!catalog.offlineSalesEnabled) {
      throw const OfflineUnavailable('Jualan offline belum diaktifkan untuk cabang ini.');
    }
    final s = await session();
    if (!s.hasShift) {
      throw const OfflineUnavailable('Shift belum dibuka. Jualan offline hanya bisa di shift yang sudah terbuka.');
    }
    if (!s.hasCashier) {
      throw const OfflineUnavailable('Kasir yang login belum dikenali HP ini. Sambungkan ke jaringan sekali dulu.');
    }
    if (cart.state.items.isEmpty) throw const OfflineUnavailable('Keranjang kosong.');

    final occurredAt = _now().add(Duration(milliseconds: s.clockOffsetMs));
    final deviceId = await store.deviceId();
    final cartState = cart.state;
    final key = cart.offlineKey();
    final context = OfflineSaleContext(
      shiftId: s.shiftId,
      cashierId: s.cashierId,
      cashierName: s.cashierName,
      deviceId: deviceId,
      catalog: catalog,
      occurredAt: occurredAt,
    );

    final entry = await store.record(
      branchId: id,
      shiftId: s.shiftId,
      idempotencyKey: key,
      occurredAt: occurredAt,
      total: cartState.total.toInt(),
      build: (numbers) => buildOfflineSale(
        cart: cartState,
        context: context,
        numbers: numbers,
        idempotencyKey: key,
        paid: paid,
        customerName: customerName,
      ),
    );

    // Sudah tertulis di HP: baru sekarang keranjang boleh dikosongkan.
    cart.completeOffline(ProductTransactionResponse(
      invoiceNumber: entry.clientRef,
      saleId: 0,
      success: true,
      paymentMethod: 'cash',
    ));
    if (mounted) {
      await _refreshCounts();
      // Server terjangkau berarti penjualan ini hanya ikut antre di belakang
      // yang lama: langsung dikirim, tanpa membuat kasir menunggu.
      if (state.reachable) {
        unawaited(flush());
      } else {
        _schedule();
      }
    }
    return OfflineSale(entry, Receipt.fromJson(Map<String, dynamic>.from(jsonDecode(entry.receipt) as Map)));
  }

  // ── mengirim ───────────────────────────────────────────────────────────

  /// Coba hubungi server; bila terjangkau, kirim antrean.
  Future<void> probe() async {
    final ok = await repo.ping();
    if (!mounted) return;
    if (ok) {
      await _reached();
    } else {
      state = state.copyWith(reachable: false);
      _schedule();
    }
  }

  Future<void> _reached() async {
    if (!mounted) return;
    state = state.copyWith(reachable: true);
    if (state.pending > 0) await flush();
    _schedule();
  }

  /// Kirim antrean dari yang tertua, satu per satu.
  ///
  /// Berhenti di penjualan pertama yang tidak mendapat jawaban, supaya urutan
  /// terjaga. Penjualan yang DITOLAK server disisihkan dan tidak menghalangi
  /// yang sesudahnya. Panggilan bersamaan ikut menunggu pengiriman yang sama.
  Future<void> flush() {
    return _flushing ??= _flush().whenComplete(() => _flushing = null);
  }

  Future<void> _flush() async {
    final id = branchId;
    if (id == null || !mounted) return;
    state = state.copyWith(sending: true);
    var reachable = true;
    try {
      for (final entry in await store.pending(id)) {
        // Notifier yang sudah dilepas (kasir pindah cabang atau keluar) tidak
        // boleh terus mengirim: server mencatat ke cabang yang sedang login.
        if (!mounted) return;
        try {
          final payload = Map<String, dynamic>.from(jsonDecode(entry.payload) as Map);
          final invoice = await repo.sendOffline(payload);
          await store.markSent(entry.id, invoiceNo: invoice, at: _now());
        } on TransactionSubmitException catch (e) {
          // Hanya penolakan atas ISI penjualannya yang menyisihkan baris.
          // Sesi habis atau galat server bukan salah penjualannya: baris tetap
          // menunggu dan dicoba lagi nanti.
          if (e.payloadRejected) {
            await store.markFailed(entry.id, e.message);
            continue;
          }
          await store.noteAttempt(entry.id, e.message);
          reachable = !e.unreachable;
          break;
        } catch (e) {
          await store.noteAttempt(entry.id, e.toString());
          break;
        }
      }
      await store.purgeSent(_now().subtract(outboxKeepSent));
    } catch (_) {
      // DB lokal bermasalah: antrean dibiarkan apa adanya dan dicoba lagi nanti.
    }
    if (!mounted) return;
    state = state.copyWith(sending: false, reachable: reachable);
    await _refreshCounts();
    _schedule();
  }

  /// Kembalikan penjualan yang ditolak ke antrean, lalu coba kirim.
  Future<void> retry(int entryId) async {
    await store.retry(entryId);
    await _refreshCounts();
    await probe();
  }

  /// Semua penjualan offline cabang ini, terbaru dulu, untuk halaman
  /// "Belum terkirim".
  Future<List<OutboxEntry>> entries() async {
    final id = branchId;
    if (id == null) return const [];
    return store.list(id);
  }

  Future<void> _refreshCounts() async {
    final id = branchId;
    if (id == null) return;
    try {
      final c = await store.counts(id);
      if (!mounted) return;
      state = state.copyWith(pending: c.pending, failed: c.failed);
    } catch (_) {}
  }

  /// Selama mode offline, server dicoba lagi berkala. Begitu antrean kosong
  /// dan server terjangkau, pewaktunya berhenti sendiri.
  void _schedule() {
    if (!mounted) return;
    if (state.active) {
      _timer ??= Timer.periodic(retryInterval, (_) => probe());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  static String _sessionKey(int branchId) => 'session:$branchId';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
