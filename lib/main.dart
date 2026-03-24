import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/theme/app_theme.dart';
import 'package:pos_mobile/presentation/providers/auth_provider.dart';
import 'package:pos_mobile/presentation/pages/dashboard/dashboard_page.dart';
import 'package:pos_mobile/presentation/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

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
        page = const DashboardPage();
        break;

      case AuthStatus.unauthenticated:
        page = const LoginPage();
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
