import 'package:pos_mobile/core/auth/role_access.dart';

/// Susunan menu layout baru app kasir (revisi owner 26 Nov 2026, PDF "Layout
/// App POS"). Navigasi bawah: Beranda · Stok · (+) · Laporan · Profil; Setting
/// lewat ikon gir di kanan atas.
///
/// Berkas ini hanya menentukan URUTAN dan SIAPA melihat menu apa — tanpa
/// widget — supaya bisa dites per role. Halaman tab mengubah tiap kunci jadi
/// kartu menu. Tab yang daftarnya kosong tidak ditampilkan.
enum MenuKey {
  // Stok
  catatWaste,
  returStok,
  permintaanStok,
  kirimanGudang,
  stokMenipis,
  auditStok,
  stokMaterial,
  stokTopping,
  stokPlastik,
  stokSedotan,
  mutasiMaterial,
  mutasiTopping,
  mutasiPlastik,
  mutasiSedotan,
  // Laporan
  tugasHarian,
  shiftKasir,
  laporanHarianLeader,
  pengeluaran,
  riwayatPenjualan,
  yangBertugas,
  penjualanOffline,
  riwayatIzinKeluar,
  laporanHarian,
  laporanPembayaran,
  // Tugas setiap hari
  monitoringPesanan,
  ceklisFoto,
  reminder,
  setoran,
  bantuan,
  arahanSpv,
  sidak,
  // Profil (kartu profil selalu ada di atas, bukan bagian daftar ini)
  jatahMinum,
  skorKpi,
  jadwalSaya,
  absensi,
  izinKeluar,
  slipGaji,
  pinjaman,
  pinjamanTunai,
  sop,
  // Setting (Versi aplikasi, Ganti password, Log out selalu ada di bawahnya)
  perangkatCetak,
  produk,
  gantiCabang,
  qrisCabang,
}

/// Bahan penentu menu: fitur hari ini (sudah dikurangi menu kasir untuk yang
/// bertugas penyaji), role utama, semua role yang dipegang, dan ada tidaknya
/// cabang aktif di token.
class MenuAccess {
  final Set<AppFeature> today;
  final String? role;
  final Set<String> held;
  final bool hasBranch;

  const MenuAccess({
    required this.today,
    required this.role,
    required this.held,
    required this.hasBranch,
  });
}

/// Tab Stok, urutan dari owner: Catat waste, (Retur Stok — fitur baru 26 Nov,
/// pasangan Catat waste), Permintaan stok, Kiriman gudang, Stok menipis, Audit
/// stok, empat stok, lalu empat riwayat mutasi.
List<MenuKey> stockMenu(MenuAccess a) => [
      if (a.today.contains(AppFeature.branchWaste)) ...[MenuKey.catatWaste, MenuKey.returStok],
      if (a.today.contains(AppFeature.stockRequest)) MenuKey.permintaanStok,
      if (a.today.contains(AppFeature.shipment)) MenuKey.kirimanGudang,
      if (a.today.contains(AppFeature.stockAlerts)) MenuKey.stokMenipis,
      if (a.today.contains(AppFeature.stockAudit)) MenuKey.auditStok,
      if (a.today.contains(AppFeature.stockMaterial)) MenuKey.stokMaterial,
      if (a.today.contains(AppFeature.stockTopping)) MenuKey.stokTopping,
      if (a.today.contains(AppFeature.stockPlastic)) MenuKey.stokPlastik,
      if (a.today.contains(AppFeature.stockStraw)) MenuKey.stokSedotan,
      if (a.today.contains(AppFeature.stockMovements)) MenuKey.mutasiMaterial,
      if (a.today.contains(AppFeature.toppingMovements)) MenuKey.mutasiTopping,
      if (a.today.contains(AppFeature.plasticMovements)) MenuKey.mutasiPlastik,
      if (a.today.contains(AppFeature.strawMovements)) MenuKey.mutasiSedotan,
    ];

/// Halaman "Tugas setiap hari" (dibuka dari tab Laporan). Sidak ditaruh di
/// sini juga: tugas harian SPV, tidak ada di gambar owner karena gambarnya
/// akun leader.
List<MenuKey> dailyTaskMenu(MenuAccess a) => [
      if (hasFeature(a.role, AppFeature.kitchenDisplay)) MenuKey.monitoringPesanan,
      if (canUsePhotoChecklist(a.held)) MenuKey.ceklisFoto,
      if (canReceiveReminders(a.held)) MenuKey.reminder,
      if (canSendCashDeposit(a.held)) MenuKey.setoran,
      if (canUseHelpTickets(a.held)) MenuKey.bantuan,
      if (canSeeDirectives(a.held)) MenuKey.arahanSpv,
      if (canInspect(a.held)) MenuKey.sidak,
    ];

/// Tab Laporan, urutan dari owner. Laporan Harian & Laporan Pembayaran (owner,
/// SPV, finance) tidak ada di gambar owner; tetap ada di paling bawah supaya
/// tidak hilang.
List<MenuKey> reportMenu(MenuAccess a) => [
      if (dailyTaskMenu(a).isNotEmpty) MenuKey.tugasHarian,
      if (a.today.contains(AppFeature.shift)) MenuKey.shiftKasir,
      if (a.today.contains(AppFeature.leaderReport)) MenuKey.laporanHarianLeader,
      if (a.today.contains(AppFeature.expenses)) MenuKey.pengeluaran,
      if (a.today.contains(AppFeature.transactions)) MenuKey.riwayatPenjualan,
      if (canMarkOvertime(a.held)) MenuKey.yangBertugas,
      // Antrean offline mengikuti role, bukan tugas hari ini: penjualan yang
      // tertahan di HP ini tetap harus bisa dilihat walau hari ini penyaji.
      if (hasFeature(a.role, AppFeature.pos)) MenuKey.penjualanOffline,
      if (canSeeLeaveOuts(a.held)) MenuKey.riwayatIzinKeluar,
      if (a.today.contains(AppFeature.reports)) ...[MenuKey.laporanHarian, MenuKey.laporanPembayaran],
    ];

/// Tab Profil (di bawah kartu profil), urutan dari owner.
List<MenuKey> profileMenu(MenuAccess a) {
  final canAttend = hasFeature(a.role, AppFeature.attendance);
  final payroll = canUsePayroll(a.held);
  return [
    MenuKey.jatahMinum,
    if (canSeeOwnKpi(a.held)) MenuKey.skorKpi,
    if (canAttend) ...[MenuKey.jadwalSaya, MenuKey.absensi],
    if (canLeaveOut(a.held)) MenuKey.izinKeluar,
    if (payroll) ...[MenuKey.slipGaji, MenuKey.pinjaman],
    // Serah pinjaman tunai dari laci: hanya yang memegang shift kasir di
    // cabang aktif (BE menolak penyaji dan yang belum buka shift).
    if (a.today.contains(AppFeature.shift) && canHandOutLoan(a.held) && a.hasBranch) MenuKey.pinjamanTunai,
    MenuKey.sop,
  ];
}

/// Halaman Setting (ikon gir). Ganti Cabang & QRIS Cabang (owner/SPV) tidak ada
/// di gambar owner; ikut ke sini karena sifatnya pengaturan.
List<MenuKey> settingMenu(MenuAccess a) => [
      MenuKey.perangkatCetak,
      if (a.today.contains(AppFeature.products)) MenuKey.produk,
      if (canSwitchBranch(a.held)) MenuKey.gantiCabang,
      if (canManageBranchQris(a.role) && a.hasBranch) MenuKey.qrisCabang,
    ];

/// Label jabatan untuk kartu profil — sama dengan ROLE_LABELS web admin
/// (`src/types/auth.ts`), urutannya juga.
const _roleLabels = {
  'owner': 'Owner',
  'supervisor': 'Supervisor',
  'leader': 'Leader',
  'finance': 'Finance',
  'karyawan': 'Karyawan',
  'produksi': 'Produksi',
  'admin_produksi': 'Admin Produksi',
};

/// "Leader", atau "Leader · Finance" untuk yang memegang lebih dari satu,
/// urut seperti web admin; role tak dikenal ditulis apa adanya.
String jobTitle(Iterable<String> roles) {
  final held = roles.map((r) => r.toLowerCase()).toSet();
  final known = [for (final e in _roleLabels.entries) if (held.contains(e.key)) e.value];
  final unknown = [for (final r in held) if (!_roleLabels.containsKey(r)) r];
  return [...known, ...unknown].join(' · ');
}
