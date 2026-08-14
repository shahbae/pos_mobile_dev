import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Penanda cabang aktif — angkanya sendiri tidak berarti apa-apa, yang penting
/// **berubah** setiap kasir pindah cabang.
///
/// Aturannya: setiap repository yang datanya terikat cabang **wajib** menonton
/// provider ini dengan `ref.watch(branchScopeProvider);` di baris pertama.
/// Karena semua provider data sudah menonton repository-nya masing-masing,
/// satu perubahan di sini merontokkan seluruh cache turunannya sekaligus —
/// dashboard, katalog produk, stok, laporan, semuanya ikut dimuat ulang tanpa
/// perlu daftar `invalidate` yang harus diingat saat menambah provider baru.
///
/// Dua repository sengaja TIDAK menontonnya:
/// - `authRepositoryProvider` — sesi login tidak boleh ikut ter-reset.
/// - `branchRepositoryProvider` — daftar cabang berlaku lintas cabang, dan
///   `switchBranch` sendiri lewat sini, jadi jangan sampai lahir ulang di
///   tengah proses pindah.
///
/// Yang menaikkannya cuma [BranchSwitchNotifier.switchBranch].
final branchScopeProvider = StateProvider<int>((ref) => 0);
