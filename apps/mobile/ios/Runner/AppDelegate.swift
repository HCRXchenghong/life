import AVFoundation
import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var speechCoordinator: DaylinkSpeechCoordinator?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "app.daylink.daylink_mobile/settings",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "openNotificationSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(FlutterError(code: "settings_unavailable", message: nil, details: nil))
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in
        if opened {
          result(nil)
        } else {
          result(FlutterError(code: "settings_unavailable", message: nil, details: nil))
        }
      }
    }
    speechCoordinator = DaylinkSpeechCoordinator(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}

private final class DaylinkSpeechCoordinator {
  private static let channelName = "app.daylink.daylink_mobile/speech"
  private static let maximumTranscriptLength = 32768

  private let channel: FlutterMethodChannel
  private var recognizer: SFSpeechRecognizer?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var audioEngine: AVAudioEngine?
  private var activeSessionID: String?
  private var pendingSessionID: String?
  private var pendingResult: FlutterResult?
  private var lastLevelUpdate = Date.distantPast

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit {
    teardown(cancelled: true)
    channel.setMethodCallHandler(nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    let sessionID = arguments?["sessionId"] as? String
    switch call.method {
    case "start":
      guard
        let sessionID,
        !sessionID.isEmpty,
        sessionID.count <= 120
      else {
        result(FlutterError(code: "invalid_request", message: nil, details: nil))
        return
      }
      let locale = safeLocale(arguments?["locale"] as? String)
      requestStart(sessionID: sessionID, locale: locale, result: result)
    case "stop":
      stop(requestedSessionID: sessionID, cancelled: false)
      result(nil)
    case "cancel":
      stop(requestedSessionID: sessionID, cancelled: true)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestStart(
    sessionID: String,
    locale: String,
    result: @escaping FlutterResult
  ) {
    guard activeSessionID == nil, pendingSessionID == nil else {
      result(FlutterError(code: "busy", message: nil, details: nil))
      return
    }
    pendingSessionID = sessionID
    pendingResult = result
    requestSpeechAuthorization { [weak self] speechAuthorized in
      DispatchQueue.main.async {
        guard let self, self.pendingSessionID == sessionID else { return }
        guard speechAuthorized else {
          self.completePending(
            error: FlutterError(code: "permission_denied", message: nil, details: nil)
          )
          return
        }
        self.requestMicrophoneAuthorization { [weak self] microphoneAuthorized in
          DispatchQueue.main.async {
            guard let self, self.pendingSessionID == sessionID else { return }
            guard microphoneAuthorized else {
              self.completePending(
                error: FlutterError(code: "permission_denied", message: nil, details: nil)
              )
              return
            }
            self.startRecognition(sessionID: sessionID, locale: locale)
          }
        }
      }
    }
  }

  private func requestSpeechAuthorization(
    completion: @escaping (Bool) -> Void
  ) {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized:
      completion(true)
    case .notDetermined:
      SFSpeechRecognizer.requestAuthorization { status in
        completion(status == .authorized)
      }
    default:
      completion(false)
    }
  }

  private func requestMicrophoneAuthorization(
    completion: @escaping (Bool) -> Void
  ) {
    if #available(iOS 17.0, *) {
      switch AVAudioApplication.shared.recordPermission {
      case .granted:
        completion(true)
      case .undetermined:
        AVAudioApplication.requestRecordPermission(completionHandler: completion)
      default:
        completion(false)
      }
      return
    }
    let session = AVAudioSession.sharedInstance()
    switch session.recordPermission {
    case .granted:
      completion(true)
    case .undetermined:
      session.requestRecordPermission(completion)
    default:
      completion(false)
    }
  }

  private func startRecognition(sessionID: String, locale: String) {
    let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
    guard let recognizer, recognizer.isAvailable else {
      completePending(
        error: FlutterError(code: "recognizer_unavailable", message: nil, details: nil)
      )
      return
    }

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    request.taskHint = .dictation
    let engine = AVAudioEngine()
    let inputNode = engine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    var tapInstalled = false
    guard format.sampleRate > 0, format.channelCount > 0 else {
      completePending(
        error: FlutterError(code: "recognizer_unavailable", message: nil, details: nil)
      )
      return
    }

    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
      inputNode.installTap(
        onBus: 0,
        bufferSize: 1024,
        format: format
      ) { [weak self] buffer, _ in
        request.append(buffer)
        self?.emitLevel(buffer, sessionID: sessionID)
      }
      tapInstalled = true
      engine.prepare()
      try engine.start()
    } catch {
      if tapInstalled {
        inputNode.removeTap(onBus: 0)
      }
      try? AVAudioSession.sharedInstance().setActive(
        false,
        options: .notifyOthersOnDeactivation
      )
      completePending(
        error: FlutterError(code: "audio", message: nil, details: nil)
      )
      return
    }

    self.recognizer = recognizer
    recognitionRequest = request
    audioEngine = engine
    activeSessionID = sessionID
    recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
      guard let self, self.activeSessionID == sessionID else { return }
      if let result {
        let transcript = self.boundedTranscript(
          result.bestTranscription.formattedString
        )
        self.emit(
          result.isFinal ? "onFinal" : "onPartial",
          sessionID: sessionID,
          values: ["transcript": transcript]
        )
        if result.isFinal {
          self.teardown(cancelled: false)
          return
        }
      }
      if error != nil {
        self.emit(
          "onError",
          sessionID: sessionID,
          values: ["code": "recognition_failed"]
        )
        self.teardown(cancelled: true)
      }
    }
    completePending(error: nil)
  }

  private func emitLevel(_ buffer: AVAudioPCMBuffer, sessionID: String) {
    guard activeSessionID == sessionID else { return }
    let now = Date()
    guard now.timeIntervalSince(lastLevelUpdate) >= 0.08 else { return }
    lastLevelUpdate = now
    guard
      let samples = buffer.floatChannelData?[0],
      buffer.frameLength > 0
    else { return }
    let count = Int(buffer.frameLength)
    var sum: Float = 0
    for index in 0..<count {
      let sample = samples[index]
      sum += sample * sample
    }
    let rms = sqrt(sum / Float(count))
    let decibels = 20 * log10(max(rms, 0.000_001))
    let level = min(max((Double(decibels) + 50) / 50, 0), 1)
    emit("onLevel", sessionID: sessionID, values: ["level": level])
  }

  private func emit(
    _ method: String,
    sessionID: String,
    values: [String: Any]
  ) {
    guard activeSessionID == sessionID else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self, self.activeSessionID == sessionID else { return }
      var arguments = values
      arguments["sessionId"] = sessionID
      self.channel.invokeMethod(method, arguments: arguments)
    }
  }

  private func stop(requestedSessionID: String?, cancelled: Bool) {
    if pendingSessionID == requestedSessionID {
      completePending(
        error: FlutterError(code: "cancelled", message: nil, details: nil)
      )
      return
    }
    guard requestedSessionID == activeSessionID else { return }
    teardown(cancelled: cancelled)
  }

  private func teardown(cancelled: Bool) {
    let engine = audioEngine
    if engine?.isRunning == true {
      engine?.stop()
    }
    engine?.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    if cancelled {
      recognitionTask?.cancel()
    } else {
      recognitionTask?.finish()
    }
    activeSessionID = nil
    recognitionTask = nil
    recognitionRequest = nil
    audioEngine = nil
    recognizer = nil
    try? AVAudioSession.sharedInstance().setActive(
      false,
      options: .notifyOthersOnDeactivation
    )
  }

  private func completePending(error: FlutterError?) {
    let result = pendingResult
    pendingResult = nil
    pendingSessionID = nil
    if let error {
      result?(error)
    } else {
      result?(nil)
    }
  }

  private func safeLocale(_ value: String?) -> String {
    guard
      let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
      normalized.range(
        of: #"^[A-Za-z]{2,3}(?:[-_][A-Za-z]{2,4})?$"#,
        options: .regularExpression
      ) != nil
    else {
      return Locale.current.identifier
    }
    return normalized.replacingOccurrences(of: "_", with: "-")
  }

  private func boundedTranscript(_ value: String) -> String {
    let normalized = value
      .replacingOccurrences(
        of: #"[\u{0000}-\u{0008}\u{000B}\u{000C}\u{000E}-\u{001F}]"#,
        with: " ",
        options: .regularExpression
      )
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return String(normalized.prefix(Self.maximumTranscriptLength))
  }
}
