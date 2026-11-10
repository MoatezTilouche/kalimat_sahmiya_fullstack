import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/puzzle.dart';
import '../models/learning.dart';

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiService {
  ApiService(
      {http.Client? client,
      String? baseUrl,
      this.timeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? defaultBaseUrl;
  static const defaultBaseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://kalimat-sahmiya-api.onrender.com');
  final http.Client _client;
  final String _baseUrl;
  final Duration timeout;
  final Map<String, Future<Map<String, dynamic>>> _pending = {};

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query,
      {Duration? requestTimeout}) {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final key = uri.toString();
    return _pending.putIfAbsent(key, () async {
      try {
        final response =
            await _client.get(uri).timeout(requestTimeout ?? timeout);
        if (response.statusCode == 422) {
          throw const ApiException(
              'هذا التحدي غير متاح حاليا. حاول مجددا بعد قليل.');
        }
        if (response.statusCode != 200) {
          throw const ApiException('الخادم مشغول حاليا. يرجى إعادة المحاولة.');
        }
        return jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
      } on ApiException {
        rethrow;
      } on FormatException {
        throw const ApiException('تعذر قراءة اللغز. يرجى إعادة المحاولة.');
      } catch (_) {
        throw const ApiException(
            'تعذر الاتصال بالإنترنت. المستويات المحفوظة متاحة دائما.');
      } finally {
        _pending.remove(key);
      }
    });
  }

  /// The first connection can take longer while the hosted backend wakes up.
  Future<void> warmUp() async {
    final data = await _get('/api/health', {},
        requestTimeout: const Duration(seconds: 90));
    if (data['ok'] != true) {
      throw const ApiException('الخادم غير متاح حاليا. حاول مرة أخرى.');
    }
  }

  Future<Puzzle> fetchPuzzle(int level, {int? size}) async {
    final data = await _get('/api/puzzles/generate',
        {'level': '$level', if (size != null) 'size': '$size'});
    try {
      final puzzle = Puzzle.fromJson(data);
      if (puzzle.level != level ||
          puzzle.difficulty != GameDifficulty.forLevel(level)) {
        throw const FormatException();
      }
      return puzzle;
    } catch (_) {
      throw const ApiException('وصل لغز غير مكتمل. يرجى إعادة المحاولة.');
    }
  }

  Future<List<Map<String, dynamic>>> fetchWords(
      {int limit = 300, int offset = 0, GameDifficulty? difficulty}) async {
    final data = await _get('/api/words', {
      'limit': '$limit',
      'offset': '$offset',
      if (difficulty != null) 'difficulty': difficulty.code
    });
    try {
      return (data['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      throw const ApiException('تعذر قراءة الكلمات. حاول مرة أخرى.');
    }
  }

  void close() => _client.close();
  Future<KnowledgeCard> fetchKnowledge(int wordId) async =>
      KnowledgeCard.fromJson(await _get('/api/knowledge/$wordId', {}));
  Future<LearningQuiz> fetchQuiz(int wordId) async =>
      LearningQuiz.fromJson(await _get('/api/knowledge/$wordId/quiz', {}));
  Future<List<KnowledgeCard>> knowledgeCards(
      {String? category, GameDifficulty? difficulty}) async {
    final data = await _get('/api/knowledge', {
      'limit': '20',
      if (category != null) 'category': category,
      if (difficulty != null) 'difficulty': difficulty.code
    });
    return (data['items'] as List)
        .map((r) => KnowledgeCard.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
