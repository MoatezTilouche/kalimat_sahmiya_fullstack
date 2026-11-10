import 'speech_native.dart' if (dart.library.js_interop) 'speech_web.dart'
    as platform;

/// Uses the platform voice as supplied; never synthesizes guessed vowel marks.
class SpeechService {
  Future<bool> speak(String text) async {
    try {
      return await platform.speak(text);
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await platform.stop();
    } catch (_) {/* Unsupported platforms stay silent. */}
  }
}
