import Flutter
import Foundation
import MLCLLMiOS

public class MLCBridge: NSObject, FlutterPlugin {
    private var chatModule: ChatModule?
    private var isModelLoaded = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "ski_coach/mlc",
            binaryMessenger: registrar.messenger()
        )
        let instance = MLCBridge()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "loadModel":
            loadModel(result: result)
        case "unloadModel":
            unloadModel(result: result)
        case "generate":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            generate(args: args, result: result)
        case "isModelLoaded":
            result(isModelLoaded)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func loadModel(result: @escaping FlutterResult) {
        if isModelLoaded {
            result(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Initialize MLC Chat Module
                let modelPath = Bundle.main.bundlePath + "/SkiCoachLlama"
                
                guard FileManager.default.fileExists(atPath: modelPath) else {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "MODEL_NOT_FOUND",
                            message: "Model not found at \(modelPath)",
                            details: nil
                        ))
                    }
                    return
                }
                
                self.chatModule = ChatModule()
                try self.chatModule?.reload(modelPath: modelPath)
                
                self.isModelLoaded = true
                
                DispatchQueue.main.async {
                    result(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "LOAD_FAILED",
                        message: "Failed to load model: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }
    
    private func unloadModel(result: @escaping FlutterResult) {
        if !isModelLoaded {
            result(nil)
            return
        }
        
        chatModule?.unload()
        chatModule = nil
        isModelLoaded = false
        result(nil)
    }
    
    private func generate(args: [String: Any], result: @escaping FlutterResult) {
        guard isModelLoaded, let chatModule = chatModule else {
            result(FlutterError(
                code: "MODEL_NOT_LOADED",
                message: "Model not loaded",
                details: nil
            ))
            return
        }
        
        guard let systemPrompt = args["systemPrompt"] as? String,
              let userPrompt = args["userPrompt"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Missing systemPrompt or userPrompt",
                details: nil
            ))
            return
        }
        
        let temperature = args["temperature"] as? Double ?? 0.0
        let maxTokens = args["maxTokens"] as? Int ?? 6000
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Reset chat for fresh generation
                chatModule.resetChat()
                
                // Construct Llama 3 format prompt
                let prompt = """
                <|begin_of_text|><|start_header_id|>system<|end_header_id|>
                
                \(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>
                
                \(userPrompt)<|eot_id|><|start_header_id|>assistant<|end_header_id|>
                
                """
                
                // Configure generation
                let generationConfig = GenerationConfig(
                    temperature: Float(temperature),
                    topP: 0.95,
                    maxGenLen: maxTokens,
                    stopTokens: ["<|eot_id|>", "<|end_of_text|>"]
                )
                
                // Generate response (synchronous)
                var fullResponse = ""
                chatModule.prefill(prompt: prompt)
                
                while !chatModule.stopped() {
                    let token = chatModule.decode()
                    fullResponse += token
                    
                    if fullResponse.count > maxTokens * 4 { // Rough char estimate
                        break
                    }
                }
                
                DispatchQueue.main.async {
                    result(fullResponse)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "GENERATION_FAILED",
                        message: "Generation failed: \(error.localizedDescription)",
                        details: nil
                    ))
                }
            }
        }
    }
}
