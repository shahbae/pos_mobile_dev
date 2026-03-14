// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:pos_mobile/main.dart';
import 'package:pos_mobile/presentation/pages/login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = <String, String>{};

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUpAll(() async {
    await dotenv.load(
      fileName: '.env',
      isOptional: true,
      mergeWith: {'API_BASE_URL': 'http://localhost'},
    );
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
    channel.setMockMethodCallHandler((call) async {
      final args =
          (call.arguments as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      switch (call.method) {
        case 'write':
          storage[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return storage[args['key'] as String];
        case 'deleteAll':
          storage.clear();
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    storage.clear();
    channel.setMockMethodCallHandler(null);
  });

  testWidgets('Menampilkan Login saat belum autentikasi', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
