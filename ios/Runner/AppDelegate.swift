import Flutter
import UIKit
import AVFoundation

#if canImport(FoundationModels)
  import FoundationModels
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var llmChannel: FlutterMethodChannel?
  private var videoChannel: FlutterMethodChannel?

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VyroLocalVideo") {
      let channel = FlutterMethodChannel(name: "vyro/local_video", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in LocalVideoDecoder.handle(call, result: result) }
      videoChannel = channel
    }
  }
}

/// Decodes only the user-selected local file. No frames are written to disk.
enum LocalVideoDecoder {
  private static var generator: AVAssetImageGenerator?
  private static var session = 0
  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "open":
      guard let path = args["path"] as? String,
        FileManager.default.fileExists(atPath: path)
      else { result(FlutterError(code: "video_failed", message: "Missing local file", details: nil)); return }
      generator?.cancelAllCGImageGeneration()
      generator = nil
      session += 1
      let id = session
      let asset = AVURLAsset(url: URL(fileURLWithPath: path))
      Task {
        do {
          let duration = try await asset.load(.duration)
          guard duration.seconds.isFinite, duration.seconds > 0 else { throw NSError(domain: "VYROVideo", code: 1) }
          await MainActor.run {
            guard id == session else { result(FlutterError(code: "video_closed", message: "Cancelled", details: nil)); return }
            let decoder = AVAssetImageGenerator(asset: asset)
            decoder.appliesPreferredTrackTransform = true
            decoder.maximumSize = CGSize(width: 640, height: 640)
            decoder.requestedTimeToleranceBefore = .zero
            decoder.requestedTimeToleranceAfter = .zero
            generator = decoder
            result(["id": id, "durationMs": Int(duration.seconds * 1000)])
          }
        } catch { await MainActor.run { result(FlutterError(code: "video_failed", message: error.localizedDescription, details: nil)) } }
      }
    case "frame":
      guard let id = args["id"] as? Int, id == session, let decoder = generator,
        let milliseconds = args["timeMs"] as? NSNumber
      else { result(FlutterError(code: "video_closed", message: "Closed session", details: nil)); return }
      let time = CMTime(value: milliseconds.int64Value, timescale: 1000)
      decoder.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, image, actualTime, state, error in
        guard state == .succeeded, let image = image, let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else {
          DispatchQueue.main.async { result(FlutterError(code: "video_failed", message: error?.localizedDescription ?? "Cannot decode frame", details: nil)) }; return
        }
        DispatchQueue.main.async {
          result(["jpeg": FlutterStandardTypedData(bytes: jpeg), "timeMs": Int(actualTime.seconds * 1000), "approximate": false])
        }
      }
    case "close":
      if let id = args["id"] as? Int, id == session {
        generator?.cancelAllCGImageGeneration(); generator = nil; session += 1
      }
      result(nil)
    default: result(FlutterMethodNotImplemented)
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
