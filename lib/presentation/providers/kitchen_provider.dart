import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/data/models/kitchen_order_model.dart';
import 'package:pos_mobile/data/repositories/kitchen_repository.dart';
import 'package:pos_mobile/data/services/sse_client.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';

/// Nama event SSE — kontrak bersama dengan `internal/realtime/hub.go`.
/// Mengubah salah satunya = breaking change di kedua sisi.
const _eventOrderPaid = 'order.paid';
const _eventOrderStatusChanged = 'order.status_changed';
const _eventOrderVoided = 'order.voided';

class KitchenDisplayState {
  final List<KitchenOrder> orders;

  /// Stream SSE sedang tersambung.
  final bool connected;

  /// Snapshot pertama belum selesai dimuat.
  final bool loading;

  /// Error terakhir yang perlu ditampilkan sekali (snackbar / banner).
  final String? error;

  const KitchenDisplayState({
    this.orders = const [],
    this.connected = false,
    this.loading = true,
    this.error,
  });

  KitchenDisplayState copyWith({
    List<KitchenOrder>? orders,
    bool? connected,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return KitchenDisplayState(
      orders: orders ?? this.orders,
      connected: connected ?? this.connected,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class KitchenDisplayNotifier extends StateNotifier<KitchenDisplayState> {
  KitchenDisplayNotifier(this._repo, this._branchId)
      : super(const KitchenDisplayState());

  final KitchenRepository _repo;
  final int? _branchId;

  SseClient? _sse;
  StreamSubscription<SseEvent>? _eventSub;
  bool _disposed = false;

  /// Tarik snapshot lalu sambungkan stream. Aman dipanggil berulang —
  /// koneksi lama ditutup dulu (dipakai juga saat app kembali dari background).
  Future<void> start() async {
    if (_disposed) return;
    await _teardown();

    await _loadSnapshot();
    if (_disposed) return;

    final sse = _repo.openStream(
      branchId: _branchId,
      onStateChanged: (isConnected) {
        if (_disposed) return;
        state = state.copyWith(connected: isConnected);
        // Wajib resync tiap kali koneksi pulih: frame yang lewat saat offline
        // tidak dikirim ulang oleh BE.
        if (isConnected) unawaited(_loadSnapshot());
      },
      // 401 pada stream tidak bisa di-retry interceptor (lihat SseClient).
      // Satu request biasa cukup untuk memicu refresh token sebelum reconnect.
      onUnauthorized: _loadSnapshot,
    );
    _sse = sse;
    _eventSub = sse.events.listen(_onEvent);
    await sse.connect();
  }

  /// Muat ulang manual (pull-to-refresh / tombol).
  Future<void> refresh() => _loadSnapshot();

  Future<void> _loadSnapshot() async {
    try {
      final orders = await _repo.listActive(branchId: _branchId);
      if (_disposed) return;
      state = state.copyWith(
        orders: _sorted(orders),
        loading: false,
        clearError: true,
      );
    } catch (e) {
      if (_disposed) return;
      debugPrint('[KDS] snapshot gagal: $e');
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void _onEvent(SseEvent event) {
    if (_disposed) return;

    final KitchenOrder order;
    try {
      order = KitchenOrder.fromJson(
        jsonDecode(event.data) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('[KDS] payload tidak valid (${event.name}): $e');
      return;
    }

    final next = [...state.orders];
    switch (event.name) {
      case _eventOrderPaid:
        _upsert(next, order);
        break;
      case _eventOrderStatusChanged:
        if (order.status == kitchenStatusServed) {
          next.removeWhere((o) => o.id == order.id);
        } else {
          _upsert(next, order);
        }
        break;
      case _eventOrderVoided:
        next.removeWhere((o) => o.id == order.id);
        break;
      default:
        return; // event tak dikenal — abaikan, snapshot tetap benar
    }

    state = state.copyWith(orders: _sorted(next));
  }

  /// Pindahkan pesanan ke status berikutnya. Optimistic: layar berubah dulu,
  /// event SSE yang mengonfirmasi. Kalau request gagal, dikembalikan.
  Future<void> advance(KitchenOrder order) async {
    final target = nextKitchenStatus(order.status);
    if (target == null) return;
    await setStatus(order, target);
  }

  Future<void> setStatus(KitchenOrder order, String status) async {
    final before = state.orders;

    final optimistic = [...before];
    if (status == kitchenStatusServed) {
      optimistic.removeWhere((o) => o.id == order.id);
    } else {
      final i = optimistic.indexWhere((o) => o.id == order.id);
      if (i >= 0) optimistic[i] = optimistic[i].copyWith(status: status);
    }
    state = state.copyWith(orders: _sorted(optimistic), clearError: true);

    try {
      await _repo.updateStatus(order.id, status);
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(orders: before, error: e.toString());
    }
  }

  void clearError() {
    if (_disposed) return;
    state = state.copyWith(clearError: true);
  }

  void _upsert(List<KitchenOrder> list, KitchenOrder order) {
    final i = list.indexWhere((o) => o.id == order.id);
    if (i >= 0) {
      list[i] = order;
    } else {
      list.add(order);
    }
  }

  /// Terlama di depan. Pesanan tanpa `paid_at` (data lama) ditaruh paling akhir.
  List<KitchenOrder> _sorted(List<KitchenOrder> list) {
    final out = [...list];
    out.sort((a, b) {
      final ap = a.paidAt;
      final bp = b.paidAt;
      if (ap == null && bp == null) return a.id.compareTo(b.id);
      if (ap == null) return 1;
      if (bp == null) return -1;
      return ap.compareTo(bp);
    });
    return out;
  }

  Future<void> _teardown() async {
    await _eventSub?.cancel();
    _eventSub = null;
    await _sse?.dispose();
    _sse = null;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_teardown());
    super.dispose();
  }
}

final kitchenDisplayProvider = StateNotifierProvider.autoDispose<
    KitchenDisplayNotifier, KitchenDisplayState>((ref) {
  final repo = ref.watch(kitchenRepositoryProvider);
  // Non-owner dikunci BE ke cabang token; owner yang sudah switch cabang juga
  // punya branchId. Owner tanpa cabang aktif tidak boleh membuka layar ini
  // (halaman meminta pilih cabang dulu).
  final branchId = ref.watch(authProvider).branchId;
  return KitchenDisplayNotifier(repo, branchId);
});
