import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'package:pos_mobile/data/local/catalog_store.dart';
import 'package:pos_mobile/data/local/kasir_local_db.dart';
import 'package:pos_mobile/data/models/plastic_model.dart';
import 'package:pos_mobile/data/models/pos_catalog_model.dart';
import 'package:pos_mobile/data/models/promo_model.dart';
import 'package:pos_mobile/data/models/sedotan_model.dart';
import 'package:pos_mobile/data/models/topping_model.dart';
import 'package:pos_mobile/data/repositories/pos_catalog_repository.dart';
import 'package:pos_mobile/data/services/api_provider.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/providers/branch_scope.dart';

/// DB lokal kasir, dibuka sekali untuk seumur aplikasi.
final kasirLocalDbProvider = Provider<Future<Database>>((ref) => openKasirLocalDb());

final catalogStoreProvider = Provider<CatalogStore>((ref) {
  return SqfliteCatalogStore(ref.watch(kasirLocalDbProvider));
});

final posCatalogRepositoryProvider = Provider<PosCatalogRepository>((ref) {
  // Ikut lahir ulang saat pindah cabang — lihat [branchScopeProvider].
  ref.watch(branchScopeProvider);
  return PosCatalogRepository(ref.watch(apiProvider));
});

/// Cabang yang sedang aktif, dari sesi login. null bila belum diketahui.
final activeBranchIdProvider = Provider<int?>((ref) {
  return ref.watch(authProvider.select((s) => s.branchId));
});

/// Seberapa sering versi katalog dicek ke server selama layar POS terbuka.
const posCatalogCheckInterval = Duration(minutes: 1);

class PosCatalogState {
  /// Katalog yang sedang dipakai layar. null = belum ada potret sama sekali
  /// (pasang baru, atau cabang ini belum pernah dibuka di HP ini).
  final PosCatalog? catalog;

  /// Sedang bertanya ke server.
  final bool refreshing;

  /// Galat pembaruan terakhir; null bila yang terakhir berhasil. Katalog lama
  /// tetap dipakai, jadi ini tanda "belum tentu terbaru", bukan "tidak ada".
  final String? error;

  const PosCatalogState({this.catalog, this.refreshing = false, this.error});

  PosCatalogState copyWith({
    PosCatalog? catalog,
    bool? refreshing,
    String? error,
    bool clearError = false,
  }) {
    return PosCatalogState(
      catalog: catalog ?? this.catalog,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Ambil satu daftar dari katalog dalam bentuk yang dipakai layar: ada isi
  /// begitu potret tersedia, galat hanya bila potret belum ada DAN server tak
  /// terjangkau, selain itu masih memuat.
  AsyncValue<List<T>> pick<T>(List<T> Function(PosCatalog) select) {
    final c = catalog;
    if (c != null) return AsyncData(select(c));
    if (error != null && !refreshing) return AsyncError(error!, StackTrace.empty);
    return const AsyncLoading();
  }
}

/// Katalog kasir cabang aktif.
///
/// Urutan kerjanya selalu sama: tampilkan potret di HP lebih dulu (tanpa
/// menunggu jaringan), lalu tanyakan ke server apakah ada yang berubah, dan
/// ulangi pertanyaan itu tiap [posCatalogCheckInterval]. Potret hanya diganti
/// oleh katalog baru yang sudah terbaca utuh; pembaruan yang gagal membiarkan
/// potret lama tetap dipakai.
final posCatalogProvider =
    StateNotifierProvider.autoDispose<PosCatalogNotifier, PosCatalogState>((ref) {
  final notifier = PosCatalogNotifier(
    repo: ref.watch(posCatalogRepositoryProvider),
    store: ref.watch(catalogStoreProvider),
    // Potret disimpan per cabang supaya katalog cabang lain tidak pernah
    // terpakai setelah kasir pindah cabang.
    branchId: ref.watch(activeBranchIdProvider),
  );
  notifier.start();
  return notifier;
});

class PosCatalogNotifier extends StateNotifier<PosCatalogState> {
  final PosCatalogRepository repo;
  final CatalogStore store;

  /// null = cabang aktif tidak diketahui; katalog tetap dimuat dari server,
  /// hanya tidak disimpan.
  final int? branchId;
  final Duration checkInterval;

  Timer? _timer;
  Future<void>? _refreshing;

  PosCatalogNotifier({
    required this.repo,
    required this.store,
    required this.branchId,
    this.checkInterval = posCatalogCheckInterval,
    // Lahir dalam keadaan "sedang memuat": sebelum potret lokal terbaca, layar
    // harus menunggu, bukan menampilkan "produk tidak ditemukan".
  }) : super(const PosCatalogState(refreshing: true));

  /// Muat potret lokal, perbarui dari server, lalu mulai pengecekan berkala.
  Future<void> start() async {
    await _loadLocal();
    if (!mounted) return;
    await refresh();
    if (!mounted) return;
    _timer = Timer.periodic(checkInterval, (_) => refresh());
  }

  Future<void> _loadLocal() async {
    final id = branchId;
    if (id == null) return;
    try {
      final stored = await store.read(id);
      if (stored == null) return;
      if (stored.schema != posCatalogSchema) {
        // Ditulis versi aplikasi lain: jangan ditebak isinya, unduh ulang.
        await store.delete(id);
        return;
      }
      final catalog = PosCatalog.fromStored(stored);
      if (!mounted) return;
      state = state.copyWith(catalog: catalog);
    } catch (_) {
      // Potret rusak atau DB tidak bisa dibuka. Aplikasi tidak boleh macet
      // karenanya: buang potretnya dan lanjut seperti HP yang belum punya.
      try {
        await store.delete(id);
      } catch (_) {}
    }
  }

  /// Tanyakan versi terbaru ke server; unduh penuh hanya bila berubah.
  ///
  /// Panggilan yang datang saat pertanyaan sebelumnya belum dijawab ikut
  /// menunggu jawaban yang sama, tidak membuat permintaan kedua.
  Future<void> refresh() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    state = state.copyWith(refreshing: true);
    try {
      final fetch = await repo.fetch(version: state.catalog?.version);
      if (!mounted) return;
      if (fetch.unchanged || fetch.catalog == null) {
        state = state.copyWith(refreshing: false, clearError: true);
        return;
      }
      // Sampai di sini katalog baru sudah terbaca utuh, baru boleh menggantikan
      // potret lama.
      final id = branchId;
      if (id != null && fetch.stored != null) {
        try {
          await store.write(id, fetch.stored!);
        } catch (_) {
          // Gagal menyimpan tidak membatalkan katalog yang baru: layar tetap
          // memakainya, dan percobaan berikutnya menyimpan lagi.
        }
      }
      if (!mounted) return;
      state = state.copyWith(catalog: fetch.catalog, refreshing: false, clearError: true);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(refreshing: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Topping aktif untuk pemilih topping di POS.
final posToppingsProvider = Provider.autoDispose<AsyncValue<List<Topping>>>((ref) {
  return ref.watch(posCatalogProvider).pick((c) => c.toppings);
});

/// Plastik aktif untuk bagian kemasan di checkout.
final posPlasticsProvider = Provider.autoDispose<AsyncValue<List<Plastic>>>((ref) {
  return ref.watch(posCatalogProvider).pick((c) => c.plastics);
});

/// Sedotan aktif untuk bagian sedotan di checkout.
final posSedotansProvider = Provider.autoDispose<AsyncValue<List<Sedotan>>>((ref) {
  return ref.watch(posCatalogProvider).pick((c) => c.sedotans);
});

/// Promo yang berlaku hari ini, untuk checkout.
///
/// Katalog membawa promo untuk semua hari; penyaringan per hari dilakukan di
/// sini dengan jam HP, dan ikut dihitung ulang tiap katalog dicek ke server —
/// jadi tablet yang menyala melewati tengah malam berganti promo sendiri.
final posPromosProvider = Provider.autoDispose<AsyncValue<List<Promo>>>((ref) {
  return ref.watch(posCatalogProvider).pick((c) => c.promosToday);
});
