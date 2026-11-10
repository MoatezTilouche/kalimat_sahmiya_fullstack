import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kalimat_sahmiya/main.dart';
import 'package:kalimat_sahmiya/screens/home_screen.dart';
import 'package:kalimat_sahmiya/screens/splash_screen.dart';
import 'package:kalimat_sahmiya/services/api_service.dart';
import 'package:kalimat_sahmiya/services/preview_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreviewStore store;
  setUp(() async {
    store = PreviewStore(api: ApiService(client: MockClient((request) async {
      expect(request.url.path, '/api/health');
      return http.Response('{"ok":true}', 200);
    })));
    await store.init();
    await store.markIntroSeen();
  });
  tearDown(() => store.close());

  testWidgets('App opens the Arabic home screen with the preview store',
      (tester) async {
    await tester.pumpWidget(ArabicArrowwordsApp(store: store));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('كلمات سهمية'), findsOneWidget);
    expect(find.text('العب الآن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
