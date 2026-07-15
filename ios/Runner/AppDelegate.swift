import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, AVSpeechSynthesizerDelegate {
  private let speechSynthesizer = AVSpeechSynthesizer()
  private var speechChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    speechSynthesizer.delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IgnSpeech") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "ign_itineraires/speech",
      binaryMessenger: registrar.messenger()
    )
    speechChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "initialize":
        self.configureAudioSession(result: result)
      case "speak":
        guard
          let arguments = call.arguments as? [String: Any],
          let text = arguments["text"] as? String,
          !text.isEmpty
        else {
          result(
            FlutterError(
              code: "invalid-text",
              message: "Le texte à prononcer est vide.",
              details: nil
            )
          )
          return
        }
        do {
          try self.activateAudioSession()
        } catch {
          result(self.audioSessionError(error))
          return
        }
        self.speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = 0.48
        utterance.pitchMultiplier = 1
        utterance.volume = 1
        self.speechSynthesizer.speak(utterance)
        result(nil)
      case "stop":
        self.speechSynthesizer.stopSpeaking(at: .immediate)
        do {
          try AVAudioSession.sharedInstance().setActive(
            false,
            options: [.notifyOthersOnDeactivation]
          )
          result(nil)
        } catch {
          result(self.audioSessionError(error))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureAudioSession(result: FlutterResult) {
    do {
      try activateAudioSession()
      result(nil)
    } catch {
      speechChannel?.invokeMethod("onError", arguments: "audio-session-error")
      result(audioSessionError(error))
    }
  }

  private func activateAudioSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
    try session.setActive(true)
  }

  private func audioSessionError(_ error: Error) -> FlutterError {
    FlutterError(
      code: "audio-session-error",
      message: "La session audio iOS est indisponible.",
      details: error.localizedDescription
    )
  }

  func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: [.notifyOthersOnDeactivation]
    )
  }
}
