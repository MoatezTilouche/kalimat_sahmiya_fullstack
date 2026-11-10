import 'dart:js_interop';

@JS('window.speechSynthesis')
external _Synthesis? get _synthesis;
extension type _Synthesis._(JSObject _) implements JSObject {
  external JSArray<_Voice> getVoices();
  external void speak(_Utterance utterance);
  external void cancel();
}
extension type _Voice._(JSObject _) implements JSObject {
  external String get lang;
}
@JS('SpeechSynthesisUtterance')
extension type _Utterance._(JSObject _) implements JSObject {
  external factory _Utterance(String text);
  external set lang(String value);
  external set rate(double value);
}
Future<bool> speak(String text) async {
  final synthesis = _synthesis;
  if (synthesis == null) return false;
  var voices = synthesis.getVoices().toDart;
  if (voices.isEmpty) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    voices = synthesis.getVoices().toDart;
  }
  final arabic =
      voices.where((v) => v.lang.toLowerCase().startsWith('ar')).firstOrNull;
  if (arabic == null) return false;
  synthesis.cancel();
  synthesis.speak(_Utterance(text)
    ..lang = arabic.lang
    ..rate = .85);
  return true;
}

Future<void> stop() async => _synthesis?.cancel();
