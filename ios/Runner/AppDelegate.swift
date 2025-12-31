import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register LlamaCppBridge plugin
    let controller = window?.rootViewController as! FlutterViewController
    LlamaCppBridge.register(with: self.registrar(forPlugin: "ski_coach/llama")!)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
