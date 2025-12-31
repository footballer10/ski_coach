import Flutter
import Foundation

// Simple bridge that uses llama_cpp_dart's existing implementation
// iOS will use the same GGUF model as Android via the shared Dart package
public class LlamaBridge: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        // llama_cpp_dart package handles everything
        // No native iOS code needed - Flutter plugin does it all
        print("✅ Llama.cpp bridge registered for iOS")
    }
}
