import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pos_mobile/presentation/providers/dashboard_operational_provider.dart';
import 'package:pos_mobile/presentation/providers/plastic_provider.dart';
import 'package:pos_mobile/presentation/providers/product_pagination_provider.dart';
import 'package:pos_mobile/presentation/providers/sedotan_provider.dart';
import 'package:pos_mobile/presentation/providers/shift_provider.dart';
import 'package:pos_mobile/presentation/providers/transaction_history_provider.dart';

/// Buang cache semua data yang ikut berubah begitu sebuah transaksi POS masuk.
///
/// Tanpa ini kasir melihat angka/stok pra-transaksi sampai menarik refresh
/// manual — makin terasa saat ramai karena satu halaman dipakai berkali-kali
/// tanpa pernah lepas dari stack (provider autoDispose pun tidak ter-dispose).
///
/// Panggil setiap kali transaksi benar-benar tercatat di BE (tunai maupun QRIS
/// yang sudah lunas), bukan saat QR baru dibuat.
void invalidateAfterTransaction(WidgetRef ref) {
  // Katalog POS: penanda "Tersedia/Habis" ikut berubah setelah stok terpakai.
  //
  // Sengaja muat ulang di tempat, BUKAN invalidate: kasir kembali ke grid ini
  // untuk melayani pelanggan berikutnya, jadi kalau request gagal daftar lama
  // harus tetap ada (loadAll mempertahankannya) — bukan grid kosong. Invalidate
  // akan membuang notifier berikut katalognya dan menyisakan layar kosong.
  ref.read(productPaginationProvider.notifier).loadAll();

  // Ringkasan di Beranda: penjualan, shift berjalan, rekap shift, transaksi terakhir.
  ref.invalidate(dashboardProvider);
  ref.invalidate(dashboardOperationalProvider);
  ref.invalidate(currentShiftProvider);

  // Riwayat penjualan hari ini.
  ref.invalidate(transactionHistoryProvider);

  // Saldo plastik & sedotan berkurang sesuai kemasan yang dipakai.
  ref.invalidate(plasticStockListProvider);
  ref.invalidate(sedotanStockListProvider);

  // Suruh halaman POS membersihkan tampilannya untuk pelanggan berikutnya.
  ref.read(posResetSignalProvider.notifier).state++;
}

/// Naik satu tiap kali sebuah transaksi selesai.
///
/// Halaman POS tetap hidup di bawah halaman sukses, jadi sisa transaksi
/// sebelumnya (teks pencarian, tab kategori, posisi scroll) akan ikut terbawa
/// saat kasir kembali. Sinyal ini yang memicu pembersihannya — dipisah dari
/// data supaya "layar kembali ke kondisi awal" tidak bergantung pada kebetulan
/// bentuk state katalog.
final posResetSignalProvider = StateProvider<int>((ref) => 0);
