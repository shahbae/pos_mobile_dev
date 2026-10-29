import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/core/auth/role_access.dart';
import 'package:pos_mobile/data/services/app_identity.dart';
import 'package:pos_mobile/data/services/push_service.dart';
import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/pages/attendance/attendance_page.dart';
import 'package:pos_mobile/presentation/pages/dashboard/dashboard_page.dart';
import 'package:pos_mobile/presentation/pages/login_page.dart';
import 'package:pos_mobile/presentation/widgets/app_update_gate.dart';
import 'package:pos_mobile/presentation/widgets/attendance_gate.dart';
import 'package:pos_mobile/presentation/widgets/push_binder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flavor prod membaca .env.prod (API produksi); flavor lain, termasuk
  // `flutter run` tanpa --flavor, membaca .env (API dev).
  await dotenv.load(fileName: appFlavor == 'prod' ? '.env.prod' : '.env');
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';
  // Sebelum permintaan API pertama: setiap permintaan membawa versi app ini.
  await AppIdentity.load();
  // Notifikasi push (Tahap 4). Tanpa google-services.json (flavor prod
  // sebelum terdaftar) app tetap jalan, hanya tanpa push.
  await PushService.init();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    late final Widget page;

    switch (auth.status) {
      case AuthStatus.authenticated:
        // Role absensi-saja (finance) langsung mendarat di halaman Absensi;
        // tidak ada dashboard/menu lain untuknya.
        //
        // Pembaruan biasa ditawarkan sesudah login, bukan di halaman login:
        // orang yang sedang berusaha masuk tidak perlu disodori dialog lebih
        // dulu. Pembaruan WAJIB muncul di keduanya (lihat AppUpdateGate).
        //
        // Kasir terkunci mengikuti absensinya: belum absen masuk / sudah absen
        // pulang → hanya Absensi. Owner, supervisor & leader bebas (hotfix
        // 19 Okt 2026), dibaca dari seluruh role yang dipegang.
        //
        // PushBinder mendaftarkan token notifikasi dan membuka tujuan
        // ketukannya; ia hidup selama sesi ini saja.
        page = PushBinder(
          child: AppUpdateGate(
            offerOptional: true,
            child: isAttendanceOnly(auth.role)
                ? const AttendancePage(isRoot: true)
                : requiresAttendanceGate(auth.held)
                    ? const AttendanceGate(child: DashboardPage())
                    : const DashboardPage(),
          ),
        );
        break;

      case AuthStatus.unauthenticated:
        page = const AppUpdateGate(child: LoginPage());
        break;

      case AuthStatus.unknown:
        page = const Scaffold(body: Center(child: CircularProgressIndicator()));
        break;
    }

    return MaterialApp(
      key: ValueKey(auth.status),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: page,
    );
  }
}
