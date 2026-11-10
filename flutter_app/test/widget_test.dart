import 'package:flutter_test/flutter_test.dart';
import 'package:kalimat_sahmiya/main.dart';
import 'package:kalimat_sahmiya/screens/home_screen.dart';
import 'package:kalimat_sahmiya/services/preview_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreviewStore store;
  setUp(() async {
    store = PreviewStore();
    await store.init();
    await store.markIntroSeen();
  });
  tearDown(() => store.close());

  testWidgets('App opens the Arabic home screen with the preview store',
      (tester) async {
    await tester.pumpWidget(ArabicArrowwordsApp(store: store));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('كلمات سهمية'), findsOneWidget);
    expect(find.text('العب الآن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
