import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:presensi_ble/main.dart';
import 'package:presensi_ble/services/user_provider.dart';

void main() {
  testWidgets('App splash/loading screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that the startup loading text is displayed
    expect(find.text('Memuat Profil...'), findsOneWidget);
  });
}
