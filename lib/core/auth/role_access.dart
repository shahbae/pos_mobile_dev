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
  stockMaterial, // /stock-levels (+ adjust)
  stockTopping, // /topping-stock (+ adjust)
  stockPlastic, // /plastic-stock (+ adjust)
  stockStraw, // /sedotan-stock (+ adjust)
  stockMovements, // /stock-movements (Riwayat Mutasi)
  toppingMovements, // /topping-stock/movements (Riwayat Stok Topping)
  plasticMovements, // /plastic-stock/movements (Riwayat Stok Plastik)
  strawMovements, // /sedotan-stock/movements (Riwayat Stok Sedotan)
  stockAudit, // /stock-audits
  stockRequest, // /stock-requests (Permintaan Stok ke gudang)
  shipment, // /shipments (Kiriman Gudang — terima / tolak)
  expenses, // /expenses (Pengeluaran)
  shift, // /shifts (Shift Kasir)
  attendance, // /attendance/check-in|out (Absensi)
  kitchenDisplay, // /kds/stream, /kds/orders (Monitoring Pesanan / KDS)
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
        AppFeature.stockMaterial,
        AppFeature.stockTopping,
        AppFeature.stockPlastic,
        AppFeature.stockStraw,
        AppFeature.stockMovements,
        AppFeature.toppingMovements,
        AppFeature.plasticMovements,
        AppFeature.strawMovements,
        AppFeature.stockAudit,
        AppFeature.stockRequest,
        AppFeature.shipment,
        AppFeature.expenses,
        AppFeature.shift,
        AppFeature.kitchenDisplay,
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
        AppFeature.stockMaterial,
        AppFeature.stockTopping,
        AppFeature.stockPlastic,
        AppFeature.stockStraw,
        AppFeature.stockMovements,
        AppFeature.toppingMovements,
        AppFeature.plasticMovements,
        AppFeature.strawMovements,
        AppFeature.stockAudit,
        AppFeature.stockRequest,
        AppFeature.shipment,
        AppFeature.expenses,
        AppFeature.shift,
        AppFeature.attendance,
        AppFeature.kitchenDisplay,
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
        AppFeature.stockMaterial,
        AppFeature.stockTopping,
        AppFeature.stockPlastic,
        AppFeature.stockStraw,
        AppFeature.stockMovements,
        AppFeature.toppingMovements,
        AppFeature.plasticMovements,
        AppFeature.strawMovements,
        AppFeature.stockAudit,
        AppFeature.stockRequest,
        AppFeature.shipment,
        AppFeature.expenses,
        AppFeature.shift,
        AppFeature.attendance,
        AppFeature.kitchenDisplay,
      };
    case 'finance':
      // ABSENSI SAJA (docs/api-finance-absensi-fe.md §7). Server sebenarnya
      // masih mengizinkan finance membaca reports/expenses/master data, tapi
      // di app mobile finance sengaja dikunci ke absensi saja — keputusan FE.
      return {
        AppFeature.attendance,
      };
    case 'karyawan':
      // POS + shift + absensi + riwayat transaksi + dashboard adaptif.
      // CATATAN: matriks (baris 243) menandai GET /transactions ❌ untuk
      // karyawan, tapi per arahan user karyawan boleh akses transaksi.
      // + audit stok (Tahap 1 SDM): karyawan bertugas kasir menggantikan role
      // kasir, termasuk opname. Role kasir sendiri sudah dihapus (revisi uji
      // manual 31 Okt 2026). Hari yang ia bertugas penyaji saja, menu kasir
      // ditutup lewat [cashierDutyFeatures].
      return {
        AppFeature.dashboard,
        AppFeature.pos,
        AppFeature.transactions,
        AppFeature.stockAudit,
        AppFeature.shift,
        AppFeature.attendance,
        AppFeature.kitchenDisplay,
      };
    case 'produksi':
      // Absensi + dashboard (revisi BE 2026-06-29: produksi dibatasi ke
      // endpoint absensi + /me, TAPI §6 mengizinkan GET /dashboard yang
      // mengembalikan section absensi). Tanpa POS / shift / lainnya.
      // + monitoring pesanan (KDS): justru role inilah alasan layar dapur ada.
      return {
        AppFeature.dashboard,
        AppFeature.attendance,
        AppFeature.kitchenDisplay,
      };
    default:
      return {};
  }
}

/// Role yang diizinkan masuk ke aplikasi mobile ini (login gate).
///
/// `finance` dikeluarkan (revisi 18 Sep 2026): finance kini absen di gudang
/// lewat app Gudang, dengan lokasi gudang. Dulu dia masuk ke sini hanya untuk
/// absensi. `karyawan` masuk sejak Tahap 1 SDM dan menggantikan role `kasir`
/// (dihapus 31 Okt 2026); tugas kasir/penyajinya diambil dari jadwal.
const allowedAppRoles = {
  'owner',
  'karyawan',
  'supervisor',
  'leader',
  'produksi',
};

/// Pesan penolakan login. Finance diberi arah yang jelas — dia bukan salah
/// akun, absensinya pindah aplikasi.
String accessDeniedMessage(String? role) {
  if (role?.toLowerCase() == 'finance') {
    return 'Absensi finance sekarang lewat app Gudang. Silakan pasang dan '
        'masuk ke aplikasi Gudang Es Teh.';
  }
  return 'Akses ditolak. Role Anda tidak diizinkan menggunakan aplikasi ini.';
}

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

/// Role lama `kasir` dihapus (revisi uji manual 31 Okt 2026); pemegangnya
/// dimigrasi ke `karyawan` oleh server. Token yang terbit sebelum migrasi masih
/// membawanya — dibaca sebagai `karyawan`, sama seperti di server.
String? upgradeLegacyRole(String? role) {
  final r = role?.trim().toLowerCase();
  return r == 'kasir' ? 'karyawan' : r;
}

/// [upgradeLegacyRole] untuk seluruh daftar, tanpa dobel.
List<String> upgradeLegacyRoles(Iterable<String> roles) => {
      for (final r in roles)
        if (r.trim().isNotEmpty) upgradeLegacyRole(r)!,
    }.toList();

/// Seluruh role yang dipegang user, huruf kecil. `roles` dari `/me` atau token;
/// kosong (token sebelum multi-role) → jatuh ke role utama.
Set<String> heldRoles(String? role, Iterable<String> roles) {
  final held = upgradeLegacyRoles(roles).toSet();
  final primary = upgradeLegacyRole(role);
  if (held.isEmpty && primary != null && primary.isNotEmpty) held.add(primary);
  return held;
}

/// Role yang membebaskan dari kunci absensi, apa pun role lain yang ikut
/// dipegang.
const _attendanceGateExempt = {'owner', 'supervisor', 'leader'};

/// Aplikasi terkunci mengikuti absensi: sebelum absen masuk dan sesudah absen
/// pulang, yang terbuka hanya halaman Absensi.
///
/// Hanya karyawan (hotfix 19 Okt 2026 untuk kasir; revisi 17 Okt mengunci
/// semua yang ikut absen; karyawan sejak Tahap 1 SDM, kasir dihapus 31 Okt).
/// Owner, supervisor dan leader bebas — juga kalau dia sekaligus karyawan.
/// Karena itu yang dibaca seluruh role, bukan role utama: finance mengalahkan
/// leader di urutan role utama, jadi finance + leader + karyawan akan terbaca
/// "finance" dan aturannya meleset.
bool requiresAttendanceGate(Iterable<String> held) {
  final roles = _norm(held);
  return roles.contains('karyawan') && roles.intersection(_attendanceGateExempt).isEmpty;
}

Set<String> _norm(Iterable<String> held) => upgradeLegacyRoles(held).toSet();

/// Owner & supervisor: hak penuh di semua cabang.
bool isOwnerLevel(Iterable<String> held) =>
    _norm(held).intersection(const {'owner', 'supervisor'}).isNotEmpty;

/// Boleh memilih cabang sendiri (menu Ganti Cabang): hanya owner & SPV
/// (revisi uji manual 31 Okt 2026). Cabang kerja role lain mengikuti jadwal
/// hari ini dan app pindah sendiri sesudah absen masuk; menu itu bagi mereka
/// hanya sumber 403.
bool canSwitchBranch(Iterable<String> held) => isOwnerLevel(held);

/// Pesan saat token belum membawa cabang, untuk yang tidak bisa memilih
/// cabang sendiri.
const kNoOutletTodayMsg = 'Belum ada jadwal di outlet hari ini. Absen masuk dulu atau hubungi leader.';

/// Pesan "belum ada cabang" yang sesuai untuk orang ini.
String branchRequiredMessage(Iterable<String> held) =>
    canSwitchBranch(held) ? 'Pilih cabang aktif dulu lewat menu Ganti Cabang.' : kNoOutletTodayMsg;

/// Karyawan yang menunya mengikuti tugas hari ini (Tahap 1 SDM). Cerminan
/// `dutyGated` di BE: memegang karyawan tanpa role lain. Dulu pemegang role
/// kasir dilewati; role itu dihapus 31 Okt 2026, sehingga penyaji tidak lagi
/// bisa membuka POS hanya karena rolenya belum dimigrasi.
bool isDutyGated(Iterable<String> held) {
  final roles = _norm(held);
  return roles.contains('karyawan') &&
      roles.intersection(const {
        'owner',
        'supervisor',
        'finance',
        'leader',
        'admin_produksi',
        'produksi',
      }).isEmpty;
}

/// Menu kasir: ditutup untuk karyawan yang hari ini hanya bertugas penyaji.
/// Monitoring pesanan tetap terbuka untuk semua tugas.
const cashierDutyFeatures = {
  AppFeature.pos,
  AppFeature.shift,
  AppFeature.stockAudit,
  AppFeature.transactions,
};

/// Fitur hari ini: fitur role utama, dikurangi menu kasir bila [cashierDuty]
/// false (tugas hari ini di cabang ini hanya penyaji). Null = tidak diketahui
/// atau tidak ada jadwal di cabang ini → tidak dikurangi; server tetap menolak
/// bila memang tidak boleh.
Set<AppFeature> featuresForToday(String? role, Iterable<String> held, {bool? cashierDuty}) {
  final f = featuresForRole(role);
  if (cashierDuty == false && isDutyGated(held)) return f.difference(cashierDutyFeatures);
  return f;
}

/// Boleh menandai lembur: leader (outletnya, termasuk dirinya), SPV, owner.
bool canMarkOvertime(Iterable<String> held) =>
    _norm(held).intersection(const {'owner', 'supervisor', 'leader'}).isNotEmpty;

/// Boleh membaca riwayat izin keluar: owner, SPV (semua), leader (cabangnya).
bool canSeeLeaveOuts(Iterable<String> held) => canMarkOvertime(held);

/// Punya slip gaji & boleh mengajukan pinjaman (Tahap 2 SDM): semua role
/// kecuali owner — owner bukan karyawan. Cermin `Request` di loan_service.go
/// dan `/me/payslips` di BE. Owner yang juga memegang role lain tetap ikut.
bool canUsePayroll(Iterable<String> held) => _norm(held)
    .intersection(const {
      'supervisor',
      'leader',
      'finance',
      'karyawan',
      'produksi',
      'admin_produksi',
    })
    .isNotEmpty;

/// Boleh menyerahkan pinjaman tunai dari laci (`loanCashier` di BE). Karyawan
/// penyaji tetap ditolak BE (RequireCashierDuty); menunya ikut [AppFeature.shift].
bool canHandOutLoan(Iterable<String> held) =>
    _norm(held).intersection(const {'owner', 'leader', 'karyawan'}).isNotEmpty;

/// Bisa menerima reminder & permintaan pengecekan foto (Tahap 4): kru outlet.
/// SPV dan owner tidak pernah menerima walau sedang absen di outlet — cermin
/// aturan penerima di be-pos `reminder_rules.go`.
bool canReceiveReminders(Iterable<String> held) =>
    _norm(held).intersection(const {'karyawan', 'leader'}).isNotEmpty;

/// Membuat dan menandai selesai tiket bantuan (Tahap 4): leader, untuk outlet
/// yang dipimpinnya. Menanggapi tiket ada di web admin.
bool canUseHelpTickets(Iterable<String> held) => _norm(held).contains('leader');

/// Memesan jatah sendiri lewat app, termasuk yang hari ini bertugas penyaji.
/// Cermin `POST /me/allowance/orders` di be-pos.
bool canOrderOwnAllowance(Iterable<String> held) =>
    _norm(held).intersection(const {'owner', 'supervisor', 'leader', 'karyawan'}).isNotEmpty;

/// Punya skor KPI sendiri dan boleh menyanggah: leader & karyawan (Crew &
/// Leader, Tahap 6) dan SPV (modul SPV, Tahap 7). Akun yang juga memegang
/// owner tidak dinilai. Finance & produksi melihat skornya di app gudang.
/// Cermin `POST /kpi/disputes` di be-pos.
bool canSeeOwnKpi(Iterable<String> held) {
  final r = _norm(held);
  if (r.contains('owner')) return false;
  return r.intersection(const {'leader', 'karyawan', 'supervisor'}).isNotEmpty;
}

/// Mengirim ceklis foto opening/closing (Tahap 6): yang bertugas di outlet.
/// Cermin `crewApp` (`/me/photo-checklist`) di be-pos. SPV tidak, walau kini
/// punya skor sendiri.
bool canUsePhotoChecklist(Iterable<String> held) =>
    _norm(held).intersection(const {'leader', 'karyawan'}).isNotEmpty;

/// Komplain kualitas atas kiriman yang sudah diterima (Tahap 7, PRD-C1):
/// leader outlet penerima. Server memastikan outletnya.
bool canComplainShipment(Iterable<String> held) => _norm(held).contains('leader');

/// Melihat skor tim outlet yang dipimpinnya dan mengirim setoran (Tahap 6).
/// Leader tidak bisa menilai crew.
bool canSeeTeamKpi(Iterable<String> held) => _norm(held).contains('leader');
bool canSendCashDeposit(Iterable<String> held) => _norm(held).contains('leader');

/// Sidak outlet (Tahap 6, L6): owner & SPV, di lokasi. Akun leader + SPV
/// ditolak server (403) di outlet yang dipimpinnya.
bool canInspect(Iterable<String> held) => isOwnerLevel(held);

/// Boleh mencatat izin keluar dari outlet (yang sedang bertugas).
bool canLeaveOut(Iterable<String> held) => _norm(held)
    .intersection(const {'owner', 'supervisor', 'leader', 'karyawan'})
    .isNotEmpty;

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
/// Supervisor, Leader, Karyawan boleh menginput hitung fisik. Finance read-only;
/// Produksi tanpa akses. Karyawan (dicabut per BE 2026-08-08 §3) kembali di
/// Tahap 1 SDM untuk hari ia bertugas kasir — lihat [featuresForToday].
bool canCreateAudit(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'supervisor':
    case 'leader':
    case 'karyawan':
      return true;
    default:
      return false;
  }
}

/// Boleh menerima atau menolak kiriman dari gudang.
/// Owner, Supervisor, Leader (BE Stasiun 4) — sama dengan yang boleh
/// mengajukan permintaan. Yang menerima barang harus orang yang benar-benar
/// melihatnya turun, dan bertanggung jawab atas cabangnya.
bool canReceiveShipment(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'supervisor':
    case 'leader':
      return true;
    default:
      return false;
  }
}

/// Boleh mengajukan / mengubah / membatalkan permintaan stok ke gudang.
/// Owner, Supervisor, Leader (BE Stasiun 3). Karyawan tidak: permintaan
/// punya konsekuensi biaya dan harus jelas siapa yang bertanggung jawab per
/// outlet.
///
/// Mengubah & membatalkan sebenarnya lebih sempit lagi — hanya PEMBUATNYA, dan
/// itu tidak bisa dipastikan dari sini karena id user tidak ikut di AuthState.
/// Tombolnya tetap ditampilkan; kalau bukan miliknya, BE membalas 403 dan
/// repository menerjemahkannya jadi kalimat yang jelas.
bool canCreateStockRequest(String? role) {
  switch (role?.toLowerCase()) {
    case 'owner':
    case 'supervisor':
    case 'leader':
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

/// Boleh mengatur QRIS cabang (mode + payload QR statis).
/// Hanya Owner & Supervisor — docs/api-qris-manual-fe.md §5.
bool canManageBranchQris(String? role) {
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
    case 'karyawan':
      return true;
    default:
      return false;
  }
}
