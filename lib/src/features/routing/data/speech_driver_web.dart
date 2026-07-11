import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'speech_driver_contract.dart';

SpeechDriver createSpeechDriver() => WebSpeechDriver();

class WebSpeechDriver implements SpeechDriver {
  void Function(String message)? _errorHandler;

  @override
  void setErrorHandler(void Function(String message) handler) {
    _errorHandler = handler;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    web.window.speechSynthesis.cancel();
    final utterance = web.SpeechSynthesisUtterance(text)
      ..lang = 'fr-FR'
      ..rate = 0.95
      ..pitch = 1
      ..volume = 1;
    utterance.onerror = ((web.Event event) {
      _errorHandler?.call('speech-error');
    }).toJS;
    web.window.speechSynthesis.speak(utterance);
  }

  @override
  Future<void> stop() async {
    web.window.speechSynthesis.cancel();
  }
}
