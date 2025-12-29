import Flutter
import UIKit
import CoreML
import Foundation

@objc class CoreMLBridge: NSObject, FlutterPlugin {
    private var model: SkiCoachModel?
    private var channel: FlutterMethodChannel?
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ski_coach/coreml", binaryMessenger: registrar.messenger())
        let instance = CoreMLBridge()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "loadModel":
            loadModel(result: result)
            
        case "unloadModel":
            unloadModel(result: result)
            
        case "generate":
            guard let args = call.arguments as? [String: Any],
                  let systemPrompt = args["systemPrompt"] as? String,
                  let userPrompt = args["userPrompt"] as? String,
                  let temperature = args["temperature"] as? Double,
                  let maxTokens = args["maxTokens"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                return
            }
            generate(systemPrompt: systemPrompt, 
                    userPrompt: userPrompt,
                    temperature: temperature,
                    maxTokens: maxTokens,
                    result: result)
            
        case "isModelLoaded":
            result(model != nil)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func loadModel(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                self?.model = try SkiCoachModel()
                DispatchQueue.main.async {
                    result(true)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LOAD_ERROR", 
                                      message: "Failed to load model: \(error.localizedDescription)", 
                                      details: nil))
                }
            }
        }
    }
    
    private func unloadModel(result: @escaping FlutterResult) {
        model = nil
        result(true)
    }
    
    private func generate(systemPrompt: String, 
                         userPrompt: String, 
                         temperature: Double, 
                         maxTokens: Int,
                         result: @escaping FlutterResult) {
        guard let model = model else {
            result(FlutterError(code: "NO_MODEL", message: "Model not loaded", details: nil))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let response = try model.generate(
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    temperature: temperature,
                    maxTokens: maxTokens
                )
                DispatchQueue.main.async {
                    result(response)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "GENERATE_ERROR", 
                                      message: "Generation failed: \(error.localizedDescription)", 
                                      details: nil))
                }
            }
        }
    }
}
