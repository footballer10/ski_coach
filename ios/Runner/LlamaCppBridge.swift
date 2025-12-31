import Flutter
import Foundation

public class LlamaCppBridge: NSObject, FlutterPlugin {
    private var context: OpaquePointer?
    private var model: OpaquePointer?
    private var isModelLoaded = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "ski_coach/llama",
            binaryMessenger: registrar.messenger()
        )
        let instance = LlamaCppBridge()
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
            
            // Get model path from app's documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let modelPath = documentsPath.appendingPathComponent("llama-3.1-8b-instruct-q4_k_m.gguf").path
            
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
            
            // Initialize llama.cpp
            var params = llama_model_default_params()
            params.n_gpu_layers = 99 // Use Metal GPU
            
            self.model = llama_load_model_from_file(modelPath, params)
            
            guard self.model != nil else {
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "LOAD_FAILED",
                        message: "Failed to load model",
                        details: nil
                    ))
                }
                return
            }
            
            // Create context
            var ctxParams = llama_context_default_params()
            ctxParams.n_ctx = 15000
            ctxParams.n_threads = 4
            
            self.context = llama_new_context_with_model(self.model, ctxParams)
            
            guard self.context != nil else {
                llama_free_model(self.model)
                self.model = nil
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "CONTEXT_FAILED",
                        message: "Failed to create context",
                        details: nil
                    ))
                }
                return
            }
            
            self.isModelLoaded = true
            
            DispatchQueue.main.async {
                result(nil)
            }
        }
    }
    
    private func unloadModel(result: @escaping FlutterResult) {
        if !isModelLoaded {
            result(nil)
            return
        }
        
        if context != nil {
            llama_free(context)
            context = nil
        }
        
        if model != nil {
            llama_free_model(model)
            model = nil
        }
        
        isModelLoaded = false
        result(nil)
    }
    
    private func generate(args: [String: Any], result: @escaping FlutterResult) {
        guard isModelLoaded, let model = model, let context = context else {
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
        
        let maxTokens = args["maxTokens"] as? Int ?? 6000
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Format prompt for Llama 3.1
            let prompt = """
            <|begin_of_text|><|start_header_id|>system<|end_header_id|>
            
            \(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>
            
            \(userPrompt)<|eot_id|><|start_header_id|>assistant<|end_header_id|>
            
            """
            
            // Tokenize
            let tokens = self.tokenize(text: prompt, model: model)
            
            // Generate response
            var responseTokens: [llama_token] = []
            
            // Evaluate prompt
            llama_decode(context, llama_batch_get_one(&tokens, Int32(tokens.count), 0, 0))
            
            // Generate tokens
            for _ in 0..<maxTokens {
                let token = llama_sample_token_greedy(context, nil)
                
                // Check for EOS
                if token == llama_token_eos(model) {
                    break
                }
                
                responseTokens.append(token)
                
                // Decode next token
                var tokenArray = [token]
                llama_decode(context, llama_batch_get_one(&tokenArray, 1, Int32(tokens.count + responseTokens.count), 0))
            }
            
            // Convert tokens to text
            let response = self.detokenize(tokens: responseTokens, model: model)
            
            DispatchQueue.main.async {
                result(response)
            }
        }
    }
    
    private func tokenize(text: String, model: OpaquePointer) -> [llama_token] {
        let utf8 = text.utf8CString
        let nTokens = -llama_tokenize(model, utf8, Int32(utf8.count), nil, 0, true, true)
        
        var tokens = [llama_token](repeating: 0, count: Int(nTokens))
        llama_tokenize(model, utf8, Int32(utf8.count), &tokens, Int32(nTokens), true, true)
        
        return tokens
    }
    
    private func detokenize(tokens: [llama_token], model: OpaquePointer) -> String {
        var result = ""
        for token in tokens {
            if let cStr = llama_token_to_piece(model, token) {
                result += String(cString: cStr)
            }
        }
        return result
    }
}
