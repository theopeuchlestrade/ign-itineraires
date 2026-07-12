import 'speech_driver_contract.dart';

SpeechDriver createSpeechDriver() => _UnsupportedSpeechDriver();

class _UnsupportedSpeechDriver implements SpeechDriver {
  @override
  void setErrorHandler(void Function(String message) handler) {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> speak(String text) async {
    throw UnsupportedError('Speech synthesis is unavailable.');
  }

  @override
  Future<void> stop() async {}
}
