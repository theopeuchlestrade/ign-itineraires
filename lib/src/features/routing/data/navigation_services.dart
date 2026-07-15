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
  Future<void>? _initialization;

  @override
  void setErrorHandler(ValueChanged<String> handler) =>
      _driver.setErrorHandler(handler);

  @override
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final pending = _initialization;
    if (pending != null) return pending;
    final initialization = _driver.initialize().then((_) {
      _initialized = true;
    });
    _initialization = initialization;
    return initialization.whenComplete(() {
      if (identical(_initialization, initialization)) _initialization = null;
    });
  }

  @override
  Future<void> speak(String text) {
    if (_initialized) return _driver.speak(text);
    return initialize().then((_) => _driver.speak(text));
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
