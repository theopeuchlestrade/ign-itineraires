import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'speech_driver_contract.dart';

SpeechDriver createSpeechDriver() => WebSpeechDriver();

class WebSpeechDriver implements SpeechDriver {
  void Function(String message)? _errorHandler;
  web.SpeechSynthesisUtterance? _activeUtterance;

  @override
  void setErrorHandler(void Function(String message) handler) {
    _errorHandler = handler;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    final synthesis = web.window.speechSynthesis;
    synthesis.cancel();
    if (synthesis.paused) synthesis.resume();
    final utterance = web.SpeechSynthesisUtterance(text)
      ..lang = 'fr-FR'
      ..voice = _frenchVoice(synthesis)
      ..rate = 0.95
      ..pitch = 1
      ..volume = 1;
    utterance.onend = ((web.Event event) {
      if (_activeUtterance == utterance) _activeUtterance = null;
    }).toJS;
    utterance.onerror = ((web.Event event) {
      if (_activeUtterance == utterance) _activeUtterance = null;
      _errorHandler?.call((event as web.SpeechSynthesisErrorEvent).error);
    }).toJS;
    _activeUtterance = utterance;
    synthesis.speak(utterance);
  }

  @override
  Future<void> stop() async {
    web.window.speechSynthesis.cancel();
    _activeUtterance = null;
  }

  web.SpeechSynthesisVoice? _frenchVoice(web.SpeechSynthesis synthesis) {
    final voices = synthesis.getVoices().toDart;
    for (final voice in voices) {
      if (voice.lang.toLowerCase() == 'fr-fr') return voice;
    }
    for (final voice in voices) {
      if (voice.lang.toLowerCase().startsWith('fr')) return voice;
    }
    return null;
  }
}
