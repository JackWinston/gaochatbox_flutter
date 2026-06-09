import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 注册调试日志原生视图
    let channel = FlutterMethodChannel(
      name: "com.gao.chatbox/debug_log_view",
      binaryMessenger: engineBridge.engine.binaryMessenger
    )
    let factory = DebugLogViewFactory(channel: channel)
    engineBridge.pluginRegistry.registrar(forPlugin: "DebugLogPlatformView")?.register(
      factory,
      withId: "com.gao.chatbox/debug_log_list"
    )
  }
}
