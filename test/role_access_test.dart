import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/core/auth/role_access.dart';

void main() {
  group('login gate — revisi 18 Sep 2026', () {
    test('finance tidak lagi masuk app kasir', () {
      // Finance absen di gudang lewat app Gudang, dengan lokasi gudang.
      expect(canAccessApp('finance'), isFalse);
      expect(accessDeniedMessage('finance'), contains('app Gudang'));
    });

    test('role outlet tetap masuk', () {
      for (final r in ['owner', 'supervisor', 'leader', 'karyawan', 'produksi']) {
        expect(canAccessApp(r), isTrue, reason: r);
      }
    });

    test('role kasir dihapus (31 Okt 2026): token lama dibaca sebagai karyawan', () {
      expect(canAccessApp('kasir'), isFalse, reason: 'role mentah tidak dikenal lagi');
      expect(upgradeLegacyRole('kasir'), 'karyawan');
      expect(upgradeLegacyRole(' KASIR '), 'karyawan');
      expect(upgradeLegacyRole('leader'), 'leader');
      expect(upgradeLegacyRole(null), isNull);
      expect(upgradeLegacyRoles(['kasir', 'karyawan', 'leader']), ['karyawan', 'leader']);
      expect(canAccessApp(upgradeLegacyRole('kasir')), isTrue);
    });

    test('role lain mendapat pesan umum', () {
      expect(canAccessApp('admin_produksi'), isFalse);
      expect(accessDeniedMessage('admin_produksi'), startsWith('Akses ditolak'));
    });

    test('karyawan boleh masuk (Tahap 1 SDM)', () {
      expect(canAccessApp('karyawan'), isTrue);
    });
  });
}
