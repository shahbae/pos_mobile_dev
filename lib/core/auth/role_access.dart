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
  reports, // GET /reports/* (harian, pembayaran, stok menipis)
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
      // Operasional cabang. TANPA reports.
      return {
        AppFeature.pos,
        AppFeature.dashboard,
        AppFeature.transactions,
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
    case 'finance':
      // Read-only master data + reports + expenses. TANPA POS.
      return {
        AppFeature.dashboard,
        AppFeature.transactions,
        AppFeature.reports,
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
      // POS + shift + absensi.
      return {
        AppFeature.pos,
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

/// Boleh menyesuaikan (adjust) stok material/topping. Finance = lihat saja.
bool canAdjustStock(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'supervisor':
    case 'leader':
      return true;
    default:
      return false;
  }
}

/// Boleh membuat pembelian. Finance hanya lihat.
bool canCreatePurchase(String? role) => canAdjustStock(role);

/// Boleh membuat audit stok. Finance hanya lihat.
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
