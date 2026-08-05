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
  leaderReport, // GET /reports/leader/daily (Laporan Harian Leader per shift)
  stockAlerts, // GET /reports/stock-alerts (Stok Menipis) — gate terpisah
  products, // GET /products (katalog baca di tab Stok)
  purchases, // /purchases (Pembelian)
  stockMaterial, // /stock-levels (+ adjust)
  stockTopping, // /topping-stock (+ adjust)
  stockPlastic, // /plastic-stock (+ adjust)
  stockStraw, // /sedotan-stock (+ adjust)
  stockMovements, // /stock-movements (Riwayat Mutasi)
  toppingMovements, // /topping-stock/movements (Riwayat Stok Topping)
  plasticMovements, // /plastic-stock/movements (Riwayat Stok Plastik)
  strawMovements, // /sedotan-stock/movements (Riwayat Stok Sedotan)
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
        AppFeature.leaderReport,
        AppFeature.stockAlerts,
        AppFeature.products,
        AppFeature.purchases,
        AppFeature.stockMaterial,
        AppFeature.stockTopping,
        AppFeature.stockPlastic,
        AppFeature.stockStraw,
        AppFeature.stockMovements,
        AppFeature.toppingMovements,
        AppFeature.plasticMovements,
        AppFeature.strawMovements,
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
        AppFeature.leaderReport,
        AppFeature.stockAlerts,
        AppFeature.products,
        AppFeature.purchases,
        AppFeature.stockMaterial,
        AppFeature.stockTopping,
        AppFeature.stockPlastic,
        AppFeature.stockStraw,
        AppFeature.stockMovements,
        AppFeature.toppingMovements,
        AppFeature.plasticMovements,
        AppFeature.strawMovements,
        AppFeature.stockAudit,
        AppFeature.expenses,
        AppFeature.shift,
        AppFeature.attendance,
      };
    case 'leader':
      // Operasional cabang + POS (per arahan user 2026-07-11).
      // TANPA reports (per arahan user 2026-06-20). Audit stok dibuka lagi
      // per revisi BE 2026-08-03 §4 (input boleh, approve tidak).
      return {
        AppFeature.pos,
        AppFeature.dashboard,
        AppFeature.transactions,
        AppFeature.leaderReport, // laporan harian per shift (GET /reports/leader/daily)
        AppFeature.stockAlerts, // peringatan stok (per arahan user 2026-06-20)
        AppFeature.products,
        AppFeature.purchases,
        AppFeature.stockMaterial,
        AppFeature.stockTopping,
        AppFeature.stockPlastic,
        AppFeature.stockStraw,
        AppFeature.stockMovements,
        AppFeature.toppingMovements,
        AppFeature.plasticMovements,
        AppFeature.strawMovements,
        AppFeature.stockAudit,
        AppFeature.expenses,
        AppFeature.shift,
        AppFeature.attendance,
      };
    case 'finance':
      // ABSENSI SAJA (docs/api-finance-absensi-fe.md §7). Server sebenarnya
      // masih mengizinkan finance membaca reports/expenses/master data, tapi
      // di app mobile finance sengaja dikunci ke absensi saja — keputusan FE.
      return {
        AppFeature.attendance,
      };
    case 'kasir':
      // Fokus POS, shift, transaksi, absensi. + dashboard (GET /dashboard
      // adaptif: section current_shift + recent_transactions).
      // + audit stok (revisi BE 2026-08-03 §4): kasir input hitung fisik,
      //   approve tetap milik owner/supervisor.
      return {
        AppFeature.dashboard,
        AppFeature.pos,
        AppFeature.transactions,
        AppFeature.stockAudit,
        AppFeature.shift,
        AppFeature.attendance,
      };
    case 'karyawan':
      // POS + shift + absensi + riwayat transaksi + dashboard adaptif.
      // CATATAN: matriks (baris 243) menandai GET /transactions ❌ untuk
      // karyawan, tapi per arahan user karyawan boleh akses transaksi.
      // + audit stok (revisi BE 2026-08-03 §4), sama seperti kasir.
      return {
        AppFeature.dashboard,
        AppFeature.pos,
        AppFeature.transactions,
        AppFeature.stockAudit,
        AppFeature.shift,
        AppFeature.attendance,
      };
    case 'produksi':
      // Absensi + dashboard (revisi BE 2026-06-29: produksi dibatasi ke
      // endpoint absensi + /me, TAPI §6 mengizinkan GET /dashboard yang
      // mengembalikan section absensi). Tanpa POS / shift / lainnya.
      return {
        AppFeature.dashboard,
        AppFeature.attendance,
      };
    default:
      return {};
  }
}

/// Role yang diizinkan masuk ke aplikasi mobile ini (login gate).
/// `finance` ditambahkan per docs/api-finance-absensi-fe.md — masuk hanya untuk
/// absensi. Selain enam role ini (mis. karyawan) ditolak masuk.
const allowedAppRoles = {
  'owner',
  'kasir',
  'supervisor',
  'leader',
  'produksi',
  'finance',
};

/// Boleh masuk app? Role harus ada di allowlist & punya minimal satu fitur.
bool canAccessApp(String? role) {
  final r = role?.toLowerCase();
  return r != null && allowedAppRoles.contains(r) && featuresForRole(r).isNotEmpty;
}

bool hasFeature(String? role, AppFeature f) => featuresForRole(role).contains(f);

/// Role yang satu-satunya fiturnya absensi (mis. `finance`). App membuka
/// halaman Absensi langsung sebagai layar utama, tanpa dashboard/menu lain.
bool isAttendanceOnly(String? role) {
  final f = featuresForRole(role);
  return f.length == 1 && f.contains(AppFeature.attendance);
}

/// Boleh memilih cabang saat check-in absensi.
/// BE hanya membaca field `branch_id` untuk owner & supervisor; untuk role lain
/// cabang selalu diambil dari token (docs/api-finance-absensi-fe.md §2), jadi
/// dropdown cabang tidak boleh ditampilkan — hanya bikin salah paham.
bool canChooseAttendanceBranch(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'supervisor':
      return true;
    default:
      return false;
  }
}

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

/// Boleh mencatat / mengubah / menghapus pengeluaran.
/// Owner, Supervisor, Finance, Leader (BE 2026-08-01: gate create == edit ==
/// delete). Role lain hanya melihat daftar.
bool canManageExpense(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'supervisor':
    case 'finance':
    case 'leader':
      return true;
    default:
      return false;
  }
}

/// Boleh membuat / mengubah / menghapus draft audit stok.
/// Revisi BE 2026-08-03 §4 memisahkan input dari persetujuan: Owner,
/// Supervisor, Leader, Kasir, dan Karyawan boleh menginput hitung fisik.
/// Finance & Produksi tidak (read-only / tanpa akses).
bool canCreateAudit(String? role) {
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

/// Boleh menyetujui (approve) audit stok. Hanya Owner & Supervisor —
/// approve-lah yang benar-benar mengubah stok (revisi BE 2026-08-03 §4).
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
