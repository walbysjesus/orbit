import Flutter
import UIKit
import AVFoundation
import CallKit
import PushKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let voipChannelName = "orbit/voip"
  private var voipChannel: FlutterMethodChannel?
  private var pushRegistry: PKPushRegistry?
  private lazy var callController = CXCallController()
  private lazy var provider: CXProvider = {
    let configuration = CXProviderConfiguration(localizedName: "Orbit")
    configuration.includesCallsInRecents = false
    configuration.supportsVideo = true
    configuration.maximumCallsPerCallGroup = 1
    configuration.maximumCallGroups = 1
    configuration.supportedHandleTypes = [.generic]
    configuration.iconTemplateImageData = nil
    return CXProvider(configuration: configuration)
  }()
  private var currentCallUUID: UUID?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      voipChannel = FlutterMethodChannel(name: voipChannelName, binaryMessenger: controller.binaryMessenger)
      voipChannel?.setMethodCallHandler { [weak self] call, result in
        self?.handleVoipMethod(call: call, result: result)
      }
    }

    provider.setDelegate(self, queue: nil)
    configurePushKit()
    configureAudioSessionForVoip()
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    voipChannel?.invokeMethod("onNativeLifecycle", arguments: ["state": "active"])
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    voipChannel?.invokeMethod("onNativeLifecycle", arguments: ["state": "background"])
  }

  private func configurePushKit() {
    let registry = PKPushRegistry(queue: DispatchQueue.main)
    registry.delegate = self
    registry.desiredPushTypes = [.voIP]
    pushRegistry = registry
  }

  private func configureAudioSessionForVoip(speakerOn: Bool = false) {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers, .defaultToSpeaker]
      )
      try session.setPreferredIOBufferDuration(0.01)
      try session.setPreferredSampleRate(48000)
      try session.setActive(true)
      try session.overrideOutputAudioPort(speakerOn ? .speaker : .none)
    } catch {
      NSLog("[OrbitVoIP] Audio session config error: \(error)")
    }
  }

  private func deactivateAudioSession() {
    do {
      try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    } catch {
      NSLog("[OrbitVoIP] Audio session deactivation error: \(error)")
    }
  }

  private func handleVoipMethod(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getManufacturer":
      result("apple")
    case "ensureVoipRuntimeSetup":
      configureAudioSessionForVoip()
      result(true)
    case "setVoipAudioMode":
      let speakerOn = (call.arguments as? [String: Any])?["speakerOn"] as? Bool ?? false
      configureAudioSessionForVoip(speakerOn: speakerOn)
      result(true)
    case "setNormalAudioMode":
      deactivateAudioSession()
      result(true)
    case "startVoipForeground":
      // iOS no usa foreground service; mantener audio/callkit activos.
      configureAudioSessionForVoip()
      result(true)
    case "stopVoipForeground":
      result(true)
    case "isIgnoringBatteryOptimizations":
      result(true)
    case "openBatteryOptimizationSettings":
      if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
        result(true)
      } else {
        result(false)
      }
    case "openOemAutostartSettings":
      if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
        result(true)
      } else {
        result(false)
      }
    case "getVoipCapabilityReport":
      result([
        "platform": "ios",
        "iosVersion": UIDevice.current.systemVersion,
        "model": UIDevice.current.model,
        "callKit": true,
        "pushKit": true,
        "backgroundVoip": true,
      ])
    case "showIncomingCall":
      let args = call.arguments as? [String: Any]
      let remoteId = (args?["remoteId"] as? String) ?? "Orbit"
      let remoteName = (args?["remoteName"] as? String) ?? "Llamada Orbit"
      reportIncomingCall(remoteId: remoteId, remoteName: remoteName)
      result(true)
    case "endNativeCall":
      if let uuid = currentCallUUID {
        endCall(uuid: uuid)
      }
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func reportIncomingCall(remoteId: String, remoteName: String) {
    let uuid = UUID()
    currentCallUUID = uuid
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: remoteId)
    update.localizedCallerName = remoteName
    update.hasVideo = true
    update.supportsHolding = false
    update.supportsGrouping = false
    update.supportsUngrouping = false
    provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
      if let error {
        NSLog("[OrbitVoIP] report incoming error: \(error)")
      } else {
        self?.voipChannel?.invokeMethod("onNativeIncomingCall", arguments: [
          "uuid": uuid.uuidString,
          "remoteId": remoteId,
          "remoteName": remoteName,
        ])
      }
    }
  }

  private func endCall(uuid: UUID) {
    let transaction = CXTransaction(action: CXEndCallAction(call: uuid))
    callController.request(transaction) { error in
      if let error {
        NSLog("[OrbitVoIP] end call transaction error: \(error)")
      }
    }
  }
}

extension AppDelegate: PKPushRegistryDelegate {
  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    voipChannel?.invokeMethod("onPushKitToken", arguments: ["token": token])
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    voipChannel?.invokeMethod("onPushKitToken", arguments: ["token": ""]) 
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    let data = payload.dictionaryPayload
    let remoteId = (data["remoteId"] as? String) ?? "Orbit"
    let remoteName = (data["remoteName"] as? String) ?? "Llamada Orbit"
    reportIncomingCall(remoteId: remoteId, remoteName: remoteName)
    voipChannel?.invokeMethod("onPushKitIncoming", arguments: data)
    completion()
  }
}

extension AppDelegate: CXProviderDelegate {
  func providerDidReset(_ provider: CXProvider) {
    currentCallUUID = nil
    deactivateAudioSession()
    voipChannel?.invokeMethod("onNativeCallEnded", arguments: ["reason": "provider_reset"])
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    configureAudioSessionForVoip()
    voipChannel?.invokeMethod("onNativeCallAnswered", arguments: [
      "uuid": action.callUUID.uuidString,
    ])
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    deactivateAudioSession()
    voipChannel?.invokeMethod("onNativeCallEnded", arguments: [
      "uuid": action.callUUID.uuidString,
      "reason": "ended",
    ])
    action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    configureAudioSessionForVoip()
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: "Orbit")
    update.hasVideo = true
    provider.reportCall(with: action.callUUID, updated: update)
    action.fulfill()
  }

  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    voipChannel?.invokeMethod("onNativeAudioActivated", arguments: nil)
  }

  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    voipChannel?.invokeMethod("onNativeAudioDeactivated", arguments: nil)
  }
}
