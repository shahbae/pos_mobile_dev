/// Kebijakan akses berbasis role untuk aplikasi mobile.
///
/// - full      : owner, karyawan        → akses penuh
/// - stockOnly : supervisor, leader, produksi → hanya tab Stok (+ Pengaturan/Logout)
/// - denied    : finance, kasir, lainnya → tidak boleh masuk app
enum AppAccess { full, stockOnly, denied }

AppAccess accessForRole(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'karyawan':
      return AppAccess.full;
    case 'supervisor':
    case 'leader':
    case 'produksi':
      return AppAccess.stockOnly;
    default:
      return AppAccess.denied;
  }
}

/// Menu di dalam tab Stok.
enum StockMenu {
  produk,
  pembelian,
  stokMaterial,
  stokTopping,
  riwayatMutasi,
  riwayatTopping,
  auditStok,
  pengeluaran,
}

/// Menu Stok yang boleh dilihat tiap role.
/// - owner/karyawan : semua
/// - supervisor     : audit stok saja
/// - leader         : pembelian, stok material (lihat+adjust), pengeluaran
/// - produksi       : semua (sementara — perlu konfirmasi)
Set<StockMenu> allowedStockMenus(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'karyawan':
    case 'produksi':
      return StockMenu.values.toSet();
    case 'supervisor':
      return {StockMenu.auditStok};
    case 'leader':
      return {
        StockMenu.pembelian,
        StockMenu.stokMaterial,
        StockMenu.stokTopping,
        StockMenu.pengeluaran,
      };
    default:
      return {};
  }
}
