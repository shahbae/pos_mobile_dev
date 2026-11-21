import 'package:flutter_test/flutter_test.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/models/me_model.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';

/// Karyawan murni (dulu: siapa yang terkunci absensi, hotfix 19 Okt 2026; kunci
/// layar dibuang revisi 21 Nov, aturannya kini memilih pesan "belum ada
/// jadwal"). Owner, supervisor dan leader bukan karyawan murni, juga kalau dia
/// sekaligus kasir — dibaca dari seluruh role.
void main() {
  group('multi-role', () {
    test('kasir yang juga owner/supervisor/leader bebas', () {
      for (final r in ['owner', 'supervisor', 'leader']) {
        expect(isCrewOnly({'kasir', r}), isFalse, reason: r);
      }
    });

    test('kasir dengan role lain tetap terkunci', () {
      // Ilham & Darwinih di prod.
      expect(isCrewOnly({'kasir', 'produksi'}), isTrue);
      expect(isCrewOnly({'kasir', 'karyawan'}), isTrue);
      expect(isCrewOnly({'kasir', 'admin_produksi'}), isTrue);
    });

    test('akun prod sekarang', () {
      // Kasircoba: role utama leader.
      expect(isCrewOnly({'karyawan', 'kasir', 'leader'}), isFalse);
      // Alena: role utama supervisor.
      expect(isCrewOnly({'admin_produksi', 'supervisor'}), isFalse);
    });

    test('finance di atas leader di role utama tidak membuat aturannya meleset', () {
      // Role utama-nya finance; yang dibaca tetap seluruh role.
      final held = heldRoles('finance', ['finance', 'leader', 'kasir']);
      expect(isCrewOnly(held), isFalse);
      expect(isCrewOnly(heldRoles('finance', ['finance', 'kasir'])), isTrue);
    });

    test('huruf besar & spasi dari server tidak berpengaruh', () {
      expect(isCrewOnly({' Kasir ', 'LEADER'}), isFalse);
      expect(isCrewOnly({' Kasir '}), isTrue);
    });
  });

  group('sumber role', () {
    test('roles kosong (token lama) jatuh ke role utama', () {
      // Role lama kasir dibaca sebagai karyawan (dihapus 31 Okt 2026).
      expect(heldRoles('kasir', const []), {'karyawan'});
      expect(heldRoles('leader', const []), {'leader'});
      expect(heldRoles(null, const []), isEmpty);
      expect(isCrewOnly(heldRoles(null, const [])), isFalse);
    });

    test('roles ada → role utama tidak ditambahkan diam-diam', () {
      expect(heldRoles('leader', ['leader', 'karyawan']), {'leader', 'karyawan'});
      expect(heldRoles('leader', ['leader', 'kasir', 'karyawan']), {'leader', 'karyawan'});
    });

    test('/me membawa roles', () {
      final me = MeModel.fromJson({
        'id': 41,
        'role': 'leader',
        'roles': ['karyawan', 'Kasir', 'leader', '', null],
      });
      expect(me.role, 'leader');
      expect(me.roles, ['karyawan', 'kasir', 'leader']);
    });

    test('/me versi lama tanpa roles', () {
      final me = MeModel.fromJson({'id': 3, 'role': 'kasir'});
      expect(me.roles, isEmpty);
    });

    test('AuthState.held', () {
      const kasirLama = AuthState(status: AuthStatus.authenticated, role: 'kasir');
      expect(isCrewOnly(kasirLama.held), isTrue);

      const kasirLeader = AuthState(
        status: AuthStatus.authenticated,
        role: 'leader',
        roles: ['kasir', 'leader'],
      );
      expect(isCrewOnly(kasirLeader.held), isFalse);

      // copyWith tanpa roles mempertahankan set; logout mengosongkannya.
      expect(kasirLeader.copyWith(branchId: 8).roles, ['kasir', 'leader']);
      expect(kasirLeader.copyWith(role: null, roles: const []).held, isEmpty);
    });
  });
}
