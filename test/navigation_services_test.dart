import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ign_itineraires/src/features/routing/data/navigation_services.dart';
import 'package:ign_itineraires/src/features/routing/data/speech_driver.dart';

void main() {
  test(
    'speech service initializes once and replaces the active utterance',
    () async {
      final driver = _FakeSpeechDriver();
      final service = FlutterSpeechService(driver: driver);

      await service.speak('Première instruction');
      await service.speak('Deuxième instruction');

      expect(driver.initializeCalls, 1);
      expect(driver.stopCalls, 0);
      expect(driver.messages, ['Première instruction', 'Deuxième instruction']);
    },
  );

  test('speech service forwards platform errors', () {
    final driver = _FakeSpeechDriver();
    final service = FlutterSpeechService(driver: driver);
    String? received;

    service.setErrorHandler((message) => received = message);
    driver.errorHandler?.call('native-error');

    expect(received, 'native-error');
  });
}

class _FakeSpeechDriver implements SpeechDriver {
  int initializeCalls = 0;
  int stopCalls = 0;
  final List<String> messages = [];
  ValueChanged<String>? errorHandler;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  void setErrorHandler(ValueChanged<String> handler) {
    errorHandler = handler;
  }

  @override
  Future<void> speak(String text) async => messages.add(text);

  @override
  Future<void> stop() async => stopCalls++;
}
