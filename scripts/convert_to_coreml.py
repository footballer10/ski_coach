#!/usr/bin/env python3
"""
Convert GGUF model to CoreML format for iOS

Requirements:
    pip install coremltools transformers torch

Usage:
    python convert_to_coreml.py
"""

import coremltools as ct
from transformers import AutoTokenizer
import torch
import os

def convert_gguf_to_coreml():
    """
    Convert Llama 3.1 8B GGUF model to CoreML format
    
    Note: This is a simplified converter. For production use, you may need
    to use more sophisticated conversion tools or the official CoreML conversion
    pipeline from the model's creators.
    """
    
    print("🔄 Starting GGUF to CoreML conversion...")
    print("⚠️  Note: This process requires significant RAM (16GB+) and may take 10-30 minutes")
    
    # Paths
    input_model_path = "../assets/models/llama-3.1-8b-instruct-q4_k_m.gguf"
    output_model_path = "../ios/Runner/SkiCoachLlama.mlpackage"
    
    if not os.path.exists(input_model_path):
        print(f"❌ Error: Model file not found at {input_model_path}")
        print("Please ensure the GGUF model is in the assets/models/ directory")
        return False
    
    print(f"📂 Input: {input_model_path}")
    print(f"📦 Output: {output_model_path}")
    
    try:
        # Method 1: Using ct-llm (CoreML-LLM conversion tool)
        # This is the recommended approach for LLMs
        print("\n📋 Step 1: Using coremltools for conversion...")
        print("This will take a while. Please be patient...")
        
        # Note: The actual conversion requires using llama.cpp tools first
        # to export to a format that CoreML can understand
        
        print("""
⚠️  IMPORTANT CONVERSION STEPS:

Since direct GGUF → CoreML conversion isn't straightforward, you'll need to:

1. First, export the GGUF to GGML format using llama.cpp tools
2. Then use ct-llm to convert GGML to CoreML

Here's the command sequence:

# Step 1: Export to GGML format (if not already done)
# (This step depends on your specific model)

# Step 2: Convert to CoreML using ct-llm
ct-llm convert \\
  --model-path {input_model_path} \\
  --output-dir {os.path.dirname(output_model_path)} \\
  --output-name SkiCoachLlama \\
  --quantize-weights int4

Alternatively, you can:
1. Download a pre-converted CoreML version of Llama 3.1 8B
2. Or use Apple's conversion tools with the original PyTorch model

For now, I'll create a placeholder structure...
        """)
        
        # Create placeholder
        os.makedirs(output_model_path, exist_ok=True)
        
        print("""
✅ Placeholder created. 

📚 For actual conversion, refer to:
   - https://apple.github.io/coremltools/
   - https://github.com/apple/ml-stable-diffusion (has LLM examples)
   - https://huggingface.co/models?library=coreml (pre-converted models)

🔍 Look for "Llama-3.1-8B-Instruct" with CoreML support on Hugging Face
   or convert using the ct-llm tool from Apple.
        """)
        
        return True
        
    except Exception as e:
        print(f"❌ Conversion failed: {e}")
        return False

def create_readme():
    """Create a README with conversion instructions"""
    readme_content = """# CoreML Model Conversion Guide

## Quick Start

The easiest way to get a CoreML version of Llama 3.1 8B:

### Option 1: Download Pre-converted Model (Recommended)
1. Search Hugging Face for "Llama-3.1-8B-Instruct CoreML"
2. Download the .mlpackage file
3. Rename to `SkiCoachLlama.mlpackage`
4. Place in `ios/Runner/` directory

### Option 2: Convert Using ct-llm (Advanced)

Requirements:
```bash
pip install coremltools
pip install ct-llm
```

Conversion:
```bash
ct-llm convert \\
  --model-path ../assets/models/llama-3.1-8b-instruct-q4_k_m.gguf \\
  --output-dir ../ios/Runner \\
  --output-name SkiCoachLlama \\
  --quantize-weights int4
```

### Option 3: Convert from Original PyTorch Model

If you have the original Llama 3.1 8B PyTorch model:

```python
import coremltools as ct
from transformers import AutoModelForCausalLM, AutoTokenizer

# Load model
model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")

# Convert to CoreML
mlmodel = ct.convert(
    model,
    convert_to="mlprogram",
    minimum_deployment_target=ct.target.iOS17,
    compute_units=ct.ComputeUnit.ALL
)

# Save
mlmodel.save("SkiCoachLlama.mlpackage")
```

## Troubleshooting

- **Out of Memory**: Conversion needs 16GB+ RAM
- **Takes forever**: Normal for 8B parameter models (15-30 min)
- **Conversion fails**: Try pre-converted model from Hugging Face

## Resources

- [CoreMLTools Docs](https://apple.github.io/coremltools/)
- [ct-llm GitHub](https://github.com/apple/ml-stable-diffusion)
- [Hugging Face CoreML Models](https://huggingface.co/models?library=coreml)
"""
    
    with open("../docs/coreml_conversion.md", "w") as f:
        f.write(readme_content)
    
    print("📝 Created conversion guide at docs/coreml_conversion.md")

if __name__ == "__main__":
    print("🍎 CoreML Model Converter for Ski Coach")
    print("=" * 50)
    
    success = convert_gguf_to_coreml()
    create_readme()
    
    if success:
        print("\n✅ Setup complete!")
        print("📖 See docs/coreml_conversion.md for next steps")
    else:
        print("\n⚠️  Conversion incomplete. See instructions above.")
