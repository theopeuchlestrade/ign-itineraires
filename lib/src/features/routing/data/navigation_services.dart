import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class SpeechGateway {
  void setErrorHandler(ValueChanged<String> handler);

  Future<void> initialize();

  Future<void> speak(String text);

  Future<void> stop();
}

class FlutterSpeechService implements SpeechGateway {
  FlutterSpeechService({FlutterTts? engine}) : _engine = engine ?? FlutterTts();

  final FlutterTts _engine;
  bool _initialized = false;
  ValueChanged<String>? _errorHandler;

  @override
  void setErrorHandler(ValueChanged<String> handler) {
    _errorHandler = handler;
    _engine.setErrorHandler((message) {
      _errorHandler?.call(message.toString());
    });
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _engine.setLanguage('fr-FR');
    await _engine.setSpeechRate(0.48);
    await _engine.setPitch(1);
    await _engine.setVolume(1);
    await _engine.awaitSpeakCompletion(false);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _engine.setAudioAttributesForNavigation();
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _engine.setSharedInstance(true);
    }
    _initialized = true;
  }

  @override
  Future<void> speak(String text) async {
    await initialize();
    await _engine.stop();
    await _engine.speak(text);
  }

  @override
  Future<void> stop() async {
    await _engine.stop();
  }
}

abstract interface class WakeLockGateway {
  Future<void> enable();

  Future<void> disable();
}

class ScreenWakeLockService implements WakeLockGateway {
  const ScreenWakeLockService();

  @override
  Future<void> enable() => WakelockPlus.enable();

  @override
  Future<void> disable() => WakelockPlus.disable();
}
