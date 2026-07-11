import 'package:flutter/services.dart';

import 'speech_driver_contract.dart';

SpeechDriver createSpeechDriver() => NativeSpeechDriver();

class NativeSpeechDriver implements SpeechDriver {
  NativeSpeechDriver() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onError') {
        _errorHandler?.call(call.arguments?.toString() ?? 'speech-error');
      }
    });
  }

  static const _channel = MethodChannel('ign_itineraires/speech');
  void Function(String message)? _errorHandler;

  @override
  void setErrorHandler(void Function(String message) handler) {
    _errorHandler = handler;
  }

  @override
  Future<void> initialize() => _channel.invokeMethod<void>('initialize');

  @override
  Future<void> speak(String text) =>
      _channel.invokeMethod<void>('speak', {'text': text});

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');
}
