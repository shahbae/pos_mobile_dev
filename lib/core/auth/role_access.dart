/// Kebijakan akses berbasis role — diturunkan dari `docs/role-access-matrix.md`
/// (sumber kebenaran BE: `cmd/server/main.go`).
///
/// Gating di app ini bersifat UI-only; BE tetap otoritatif. Tujuannya supaya
/// tiap role hanya melihat menu yang memang boleh dia akses (hindari 403).
///
/// Hanya mencakup fitur yang ADA di app ini. Endpoint yang tidak punya layar
/// (mis. employees, services, recipe) diabaikan.

/// Fitur/menu yang dikenali app (granularitas selevel menu).
enum AppFeature {
  pos, // POST /product-transactions (transaksi baru)
  dashboard, // GET /dashboard/operational (tab Beranda)
  transactions, // GET /transactions (Riwayat Penjualan)
  reports, // GET /reports/daily, /reports/payments (Laporan Harian & Pembayaran)
  stockAlerts, // GET /reports/stock-alerts (Stok Menipis) — gate terpisah
  products, // GET /products (katalog baca di tab Stok)
  purchases, // /purchases (Pembelian)
  stockMaterial, // /stock-levels (+ adjust)
  stockTopping, // /topping-stock (+ adjust)
  stockMovements, // /stock-movements (Riwayat Mutasi)
  toppingMovements, // /topping-stock/movements (Riwayat Stok Topping)
  stockAudit, // /stock-audits
  expenses, // /expenses (Pengeluaran)
  shift, // /shifts (Shift Kasir)
  attendance, // /attendance/check-in|out (Absensi)
}

/// Set fitur yang boleh diakses tiap role.
Set<AppFeature> featuresForRole(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
      // Akses penuh, KECUALI absensi (owner tidak ikut absen).
      return {
        AppFeature.pos,
        AppFeature.dashboard,
        AppFeature.transactions,
        AppFeature.reports,
        AppFeature.stockAlerts,
        AppFeature.products,
        AppFeature.purchases,
        AppFeature.stockMaterial,
        AppFeature.stockTopping,
        AppFeature.stockMovements,
        AppFeature.toppingMovements,
        AppFeature.stockAudit,
        AppFeature.expenses,
        AppFeature.shift,
      };
    case 'supervisor':
      // Setara owner + ikut absensi.
      return {
        AppFeature.pos,
        AppFeature.dashboard,
        AppFeature.transactions,
        AppFeature.reports,
        AppFeature.stockAlerts,
        AppFeature.products,
        AppFeature.purchases,
        AppFeature.stockMaterial,
        AppFeature.stockTopping,
        AppFeature.stockMovements,
        AppFeature.toppingMovements,
        AppFeature.stockAudit,
        AppFeature.expenses,
        AppFeature.shift,
        AppFeature.attendance,
      };
    case 'leader':
      // Operasional cabang. TANPA POS, reports, & audit stok
      // (per arahan user 2026-06-20; matriks menandai leader ✅ untuk semua itu).
      return {
        AppFeature.dashboard,
        AppFeature.transactions,
        AppFeature.stockAlerts, // peringatan stok (per arahan user 2026-06-20)
        AppFeature.products,
        AppFeature.purchases,
        AppFeature.stockMaterial,
        AppFeature.stockTopping,
        AppFeature.stockMovements,
        AppFeature.toppingMovements,
        AppFeature.expenses,
        AppFeature.shift,
        AppFeature.attendance,
      };
    case 'finance':
      // Read-only master data + reports + expenses. TANPA POS.
      return {
        AppFeature.dashboard,
        AppFeature.transactions,
        AppFeature.reports,
        AppFeature.stockAlerts,
        AppFeature.products,
        AppFeature.purchases,
        AppFeature.stockMaterial,
        AppFeature.stockTopping,
        AppFeature.stockMovements,
        AppFeature.toppingMovements,
        AppFeature.stockAudit,
        AppFeature.expenses,
        AppFeature.shift, // lihat saja (lihat canOperateShift)
        AppFeature.attendance,
      };
    case 'kasir':
      // Fokus POS, shift, transaksi, absensi.
      return {
        AppFeature.pos,
        AppFeature.transactions,
        AppFeature.shift,
        AppFeature.attendance,
      };
    case 'karyawan':
      // POS + shift + absensi + riwayat transaksi.
      // CATATAN: matriks (baris 243) menandai GET /transactions ❌ untuk
      // karyawan, tapi per arahan user karyawan boleh akses transaksi.
      return {
        AppFeature.pos,
        AppFeature.transactions,
        AppFeature.shift,
        AppFeature.attendance,
      };
    case 'produksi':
      // POS + absensi (tanpa shift).
      return {
        AppFeature.pos,
        AppFeature.attendance,
      };
    default:
      return {};
  }
}

/// Boleh masuk app? Role dikenali & punya minimal satu fitur.
bool canAccessApp(String? role) => featuresForRole(role).isNotEmpty;

bool hasFeature(String? role, AppFeature f) => featuresForRole(role).contains(f);

// ---------------------------------------------------------------------------
// Gating aksi tulis di dalam halaman (mencegah 403 untuk role read-only).
// ---------------------------------------------------------------------------

/// Boleh menyesuaikan (adjust) stok material/topping.
/// Hanya Owner & Supervisor — Leader & Finance lihat saja.
/// (Per arahan user 2026-06-20: leader read-only stok. Matriks menandai
/// leader ✅ untuk adjust, jadi ini penyimpangan yang disengaja.)
bool canAdjustStock(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'supervisor':
      return true;
    default:
      return false;
  }
}

/// Boleh membuat pembelian. Owner/Supervisor/Leader. Finance hanya lihat.
bool canCreatePurchase(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'supervisor':
    case 'leader':
      return true;
    default:
      return false;
  }
}

/// Boleh membuat audit stok. Hanya Owner & Supervisor (leader tak akses audit).
bool canCreateAudit(String? role) => canAdjustStock(role);

/// Boleh menyetujui (approve) audit stok. Hanya Owner & Supervisor.
bool canApproveAudit(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'supervisor':
      return true;
    default:
      return false;
  }
}

/// Boleh buka/tutup shift. Finance hanya lihat riwayat; Produksi tidak ada shift.
bool canOperateShift(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'supervisor':
    case 'leader':
    case 'kasir':
    case 'karyawan':
      return true;
    default:
      return false;
  }
}
