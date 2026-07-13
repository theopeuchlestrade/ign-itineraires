import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'speech_driver_contract.dart';

SpeechDriver createSpeechDriver() => WebSpeechDriver();

class WebSpeechDriver implements SpeechDriver {
  void Function(String message)? _errorHandler;
  web.SpeechSynthesisUtterance? _activeUtterance;
  web.SpeechSynthesisUtterance? _activationUtterance;
  bool _activated = false;

  @override
  void setErrorHandler(void Function(String message) handler) {
    _errorHandler = handler;
  }

  @override
  Future<void> initialize() async {
    if (_activated) return;
    final synthesis = web.window.speechSynthesis;
    final utterance = web.SpeechSynthesisUtterance('\u00a0')
      ..lang = 'fr-FR'
      ..rate = 1
      ..pitch = 1
      ..volume = 1;
    utterance.onend = ((web.Event event) {
      if (_activationUtterance == utterance) _activationUtterance = null;
    }).toJS;
    utterance.onerror = ((web.Event event) {
      if (_activationUtterance == utterance) _activationUtterance = null;
    }).toJS;
    _activationUtterance = utterance;
    _activated = true;
    synthesis.speak(utterance);
    if (synthesis.paused) synthesis.resume();
  }

  @override
  Future<void> speak(String text) async {
    final synthesis = web.window.speechSynthesis;
    synthesis.cancel();
    await Future<void>.delayed(Duration.zero);
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
    if (synthesis.paused) synthesis.resume();
  }

  @override
  Future<void> stop() async {
    web.window.speechSynthesis.cancel();
    _activeUtterance = null;
    _activationUtterance = null;
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
