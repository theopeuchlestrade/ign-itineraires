export 'speech_driver_contract.dart';

import 'speech_driver_contract.dart';
import 'speech_driver_stub.dart'
    if (dart.library.io) 'speech_driver_native.dart'
    if (dart.library.js_interop) 'speech_driver_web.dart'
    as platform;

SpeechDriver createSpeechDriver() => platform.createSpeechDriver();
