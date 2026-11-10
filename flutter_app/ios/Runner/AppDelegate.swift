import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let speech = AVSpeechSynthesizer()
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(name: "kalimat_sahmiya/speech",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(false); return }
      switch call.method {
      case "speak":
        guard let text = call.arguments as? String,
          let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix("ar") })
        else { result(false); return }
        self.speech.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: String(text.prefix(4000)))
        utterance.voice = voice
        utterance.rate = 0.42
        self.speech.speak(utterance)
        result(true)
      case "stop":
        self.speech.stopSpeaking(at: .immediate)
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
}
