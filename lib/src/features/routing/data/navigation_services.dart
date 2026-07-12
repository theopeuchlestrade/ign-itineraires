import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'speech_driver.dart';

abstract interface class SpeechGateway {
  void setErrorHandler(ValueChanged<String> handler);

  Future<void> initialize();

  Future<void> speak(String text);

  Future<void> stop();
}

class FlutterSpeechService implements SpeechGateway {
  FlutterSpeechService({SpeechDriver? driver})
    : _driver = driver ?? createSpeechDriver();

  final SpeechDriver _driver;
  bool _initialized = false;

  @override
  void setErrorHandler(ValueChanged<String> handler) =>
      _driver.setErrorHandler(handler);

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _driver.initialize();
    _initialized = true;
  }

  @override
  Future<void> speak(String text) async {
    await initialize();
    await _driver.stop();
    await _driver.speak(text);
  }

  @override
  Future<void> stop() async {
    await _driver.stop();
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
