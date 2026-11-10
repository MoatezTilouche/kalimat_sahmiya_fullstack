import 'package:flutter/services.dart';

const _channel = MethodChannel('kalimat_sahmiya/speech');
Future<bool> speak(String text) async =>
    await _channel.invokeMethod<bool>('speak', text) ?? false;
Future<void> stop() => _channel.invokeMethod<void>('stop');
