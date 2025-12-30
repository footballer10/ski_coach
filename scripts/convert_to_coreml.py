#!/usr/bin/env python3
"""
Convert Hugging Face model to CoreML format for iOS

Requirements:
    pip install coremltools transformers torch sentencepiece huggingface_hub

Usage:
    python convert_to_coreml.py
"""

import coremltools as ct
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch
import os

# CHANGE THIS to choose which model to convert:
MODEL_NAME = "microsoft/Phi-3.5-mini-instruct"  # Recommended: 3.8B, ungated, similar to Llama 3B
# MODEL_NAME = "meta-llama/Llama-3.2-3B-Instruct"  # Requires Hugging Face login
# MODEL_NAME = "meta-llama/Llama-3.1-8B-Instruct"  # Requires Hugging Face login

def convert_hf_to_coreml():
    """
    Convert Llama model from Hugging Face to 4-bit quantized CoreML format
    
    This downloads the model from Hugging Face, quantizes to 4-bit INT4,
    and converts to CoreML format in one step.
    """
    
    print("🔄 Starting Hugging Face → CoreML conversion...")
    print(f"📦 Model: {MODEL_NAME}")
    print("⚠️  Note: This process requires significant RAM (16GB+) and may take 15-30 minutes")
    print("⚠️  First run will download ~6GB for 3B or ~16GB for 8B model")
    
    output_model_path = "SkiCoachLlama.mlpackage"
    
    print(f"📦 Output: {output_model_path}")
    
    try:
        print("\n📋 Step 1: Downloading model from Hugging Face...")
        print("(This may take a while on first run)")
        
        # Load model and tokenizer from Hugging Face
        model = AutoModelForCausalLM.from_pretrained(
            MODEL_NAME,
            torch_dtype=torch.float16,
            low_cpu_mem_usage=True,
        )
        tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
        
        print("✅ Model downloaded")
        
        print("\n📋 Step 2: Converting to CoreML with 4-bit quantization...")
        print("(This is the slow part - 15-30 minutes)")
        
        # Convert to CoreML with 4-bit quantization
        mlmodel = ct.convert(
            model,
            convert_to="mlprogram",
            minimum_deployment_target=ct.target.iOS17,
            compute_units=ct.ComputeUnit.ALL,
            compute_precision=ct.precision.FLOAT16,
        )
        
        # Apply 4-bit quantization
        print("\n📋 Step 3: Applying INT4 quantization...")
        mlmodel = ct.models.neural_network.quantization_utils.quantize_weights(
            mlmodel,
            nbits=4,
            quantization_mode="linear_symmetric"
        )
        
        print("\n📋 Step 4: Saving model...")
        mlmodel.save(output_model_path)
        
        # Get file size
        import subprocess
        try:
            size_output = subprocess.check_output(['du', '-sh', output_model_path]).decode()
            size = size_output.split()[0]
        except:
            size = "unknown"
        
        print(f"""
✅ Conversion complete!

📦 Output: {output_model_path}
💾 Size: {size}

📋 Next steps:
1. Open Xcode: open ../ios/Runner.xcworkspace
2. Drag {output_model_path} into Runner folder
3. Check "Copy items if needed" and "Runner" target
4. Build and run!
        """)
        
        return True
        
    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        print("\n💡 Troubleshooting:")
        print("- Ensure you have 16GB+ RAM available")
        print("- Check internet connection for model download")
        print("- Try the alternative model (edit MODEL_NAME in this script)")
        print("- Consider downloading a pre-converted model from Hugging Face")
        return False

if __name__ == "__main__":
    print("🍎 CoreML Model Converter for Ski Coach")
    print("=" * 50)
    
    success = convert_hf_to_coreml()
    
    if success:
        print("\n✅ All done! Model ready to use.")
    else:
        print("\n⚠️  Conversion failed. See error messages above.")
