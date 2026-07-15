abstract interface class SpeechDriver {
  void setErrorHandler(void Function(String message) handler);

  Future<void> initialize();

  Future<void> speak(String text);

  Future<void> stop();
}
