import Flutter
import UIKit

#if canImport(FoundationModels)
  import FoundationModels
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var llmChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VyroOnDeviceLlm") {
      let channel = FlutterMethodChannel(
        name: "vyro/on_device_llm", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        OnDeviceLlm.handle(call, result: result)
      }
      llmChannel = channel
    }
  }
}

/// Apple Intelligence (Foundation Models, iOS 26+) bridge for the on-device
/// assistant. Runs fully on device; returns "unavailable" on older systems,
/// unsupported iPhones or when Apple Intelligence is turned off.
enum OnDeviceLlm {
  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status", "download":
      // The system manages the model; there is nothing for the app to download.
      result(status())
    case "generate":
      guard let args = call.arguments as? [String: Any],
        let prompt = args["prompt"] as? String, !prompt.isEmpty
      else {
        result(FlutterError(code: "bad_args", message: "Missing prompt", details: nil))
        return
      }
      generate(prompt, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func status() -> String {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        switch SystemLanguageModel.default.availability {
        case .available:
          return "available"
        case .unavailable(.modelNotReady):
          return "downloading"
        case .unavailable:
          return "unavailable"
        @unknown default:
          return "unavailable"
        }
      }
    #endif
    return "unavailable"
  }

  static func generate(_ prompt: String, result: @escaping FlutterResult) {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, *) {
        Task {
          do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            await MainActor.run { result(response.content) }
          } catch {
            await MainActor.run {
              result(
                FlutterError(
                  code: "generation_failed", message: error.localizedDescription, details: nil))
            }
          }
        }
        return
      }
    #endif
    result(FlutterError(code: "unavailable", message: "Requires iOS 26", details: nil))
  }
}
