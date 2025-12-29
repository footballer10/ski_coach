import Foundation
import CoreML
import NaturalLanguage

enum SkiCoachModelError: Error {
    case modelNotFound
    case compilationFailed
    case predictionFailed
    case invalidInput
    case invalidOutput
}

class SkiCoachModel {
    private var model: MLModel?
    private let modelName = "SkiCoachLlama"
    
    init() throws {
        try loadModel()
    }
    
    private func loadModel() throws {
        // Try to load compiled model from bundle
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc") else {
            // If compiled model not found, try to compile the mlpackage
            guard let packageURL = Bundle.main.url(forResource: modelName, withExtension: "mlpackage") else {
                throw SkiCoachModelError.modelNotFound
            }
            
            do {
                let compiledURL = try MLModel.compileModel(at: packageURL)
                model = try MLModel(contentsOf: compiledURL)
            } catch {
                throw SkiCoachModelError.compilationFailed
            }
            return
        }
        
        // Load compiled model
        do {
            model = try MLModel(contentsOf: modelURL)
        } catch {
            throw SkiCoachModelError.compilationFailed
        }
    }
    
    func generate(systemPrompt: String, 
                 userPrompt: String,
                 temperature: Double,
                 maxTokens: Int) throws -> String {
        
        guard let model = model else {
            throw SkiCoachModelError.modelNotFound
        }
        
        // Construct the full prompt in Llama format
        let fullPrompt = """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>
        
        \(systemPrompt)<|eot_id|><|start_header_id|>user<|end_header_id|>
        
        \(userPrompt)<|eot_id|><|start_header_id|>assistant<|end_header_id|>
        
        """
        
        // Create input feature provider
        let inputDict: [String: Any] = [
            "input_text": fullPrompt,
            "max_tokens": maxTokens,
            "temperature": temperature
        ]
        
        guard let inputFeatures = try? MLDictionaryFeatureProvider(dictionary: inputDict) else {
            throw SkiCoachModelError.invalidInput
        }
        
        // Run prediction
        let prediction: MLFeatureProvider
        do {
            prediction = try model.prediction(from: inputFeatures)
        } catch {
            throw SkiCoachModelError.predictionFailed
        }
        
        // Extract output
        guard let output = prediction.featureValue(for: "output_text")?.stringValue else {
            throw SkiCoachModelError.invalidOutput
        }
        
        return output
    }
    
    deinit {
        model = nil
    }
}
