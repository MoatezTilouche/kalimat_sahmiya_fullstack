import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kalimat_sahmiya/models/puzzle.dart';
import 'package:kalimat_sahmiya/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('health check allows a cold start longer than normal API calls',
      (tester) async {
    final response = Completer<http.Response>();
    Uri? requestedUrl;
    final api = ApiService(
        timeout: const Duration(seconds: 1),
        client: MockClient((request) {
          requestedUrl = request.url;
          return response.future;
        }));
    final ready = api.warmUp();
    final completion = expectLater(ready, completes);
    await tester.pump();
    await tester.pump(const Duration(seconds: 65));
    response.complete(http.Response('{"ok":true}', 200));
    await tester.pump();
    await completion;
    expect(requestedUrl?.path, '/api/health');
    expect(requestedUrl?.host, 'kalimat-sahmiya-api.onrender.com');
    api.close();
  });
  testWidgets('health check times out after 90 seconds and can be retried',
      (tester) async {
    var requests = 0;
    final response = Completer<http.Response>();
    final api = ApiService(client: MockClient((_) {
      requests++;
      return requests == 1
          ? response.future
          : Future.value(http.Response('{"ok":true}', 200));
    }));
    final failure = expectLater(api.warmUp(), throwsA(isA<ApiException>()));
    await tester.pump(const Duration(seconds: 91));
    await failure;
    await api.warmUp();
    expect(requests, 2);
    response.complete(http.Response('{"ok":true}', 200));
    api.close();
  });
  test('coalesces requests and lets the backend choose grid complexity',
      () async {
    final levels = jsonDecode(
            await rootBundle.loadString('assets/puzzles/starter_levels.json'))
        as List;
    var requests = 0;
    final response = Completer<http.Response>();
    final api = ApiService(client: MockClient((request) {
      requests++;
      expect(request.url.queryParameters, {'level': '75'});
      return response.future;
    }));
    final a = api.fetchPuzzle(75);
    final b = api.fetchPuzzle(75);
    response.complete(http.Response(jsonEncode(levels[74]), 200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    final results = await Future.wait([a, b]);
    expect(requests, 1);
    expect(results.first.difficulty, GameDifficulty.hard);
    api.close();
  });
  test(
      'offline, unavailable, malformed and wrong-level responses are Arabic errors',
      () async {
    for (final response in [
      http.Response('{}', 503),
      http.Response('{}', 422),
      http.Response('broken', 200),
      http.Response('{"level":2}', 200)
    ]) {
      final api = ApiService(client: MockClient((_) async => response));
      await expectLater(
          api.fetchPuzzle(1),
          throwsA(isA<ApiException>().having((e) => e.message, 'Arabic message',
              matches(RegExp('[\u0621-\u064a]')))));
      api.close();
    }
    var requests = 0;
    final api = ApiService(client: MockClient((_) async {
      requests++;
      throw http.ClientException('offline');
    }));
    await expectLater(api.fetchPuzzle(76), throwsA(isA<ApiException>()));
    await expectLater(api.fetchPuzzle(76), throwsA(isA<ApiException>()));
    expect(requests,
        2); // Failed requests are removed, so retry can succeed later.
    api.close();
  });
  test('word requests include the selected difficulty', () async {
    final api = ApiService(client: MockClient((request) async {
      expect(request.url.queryParameters['difficulty'], 'medium');
      expect(request.url.queryParameters['offset'], '10');
      return http.Response('{"items":[]}', 200);
    }));
    expect(await api.fetchWords(difficulty: GameDifficulty.medium, offset: 10),
        isEmpty);
    api.close();
  });
}
