# AI Model File

**Required File**: `Llama-3.2-3B-Instruct-Q4_K_M.gguf`

## Download Instructions

1. Go to: https://huggingface.co/hugging-quants/Llama-3.2-3B-Instruct-GGUF
2. Download: `Llama-3.2-3B-Instruct-Q4_K_M.gguf` (2.3 GB)
3. Place it in this directory: `assets/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf`

**Note**: This file is NOT included in git due to its size (2.3 GB). You must download it separately.

## File Should Be Located At:
```
ski_coach/
  assets/
    models/
      Llama-3.2-3B-Instruct-Q4_K_M.gguf  <-- Download this file here
      README.md  <-- This file
```

## Verify Download
After downloading, verify the file is in the correct location:
- Windows: `dir assets\models\*.gguf`
- Mac/Linux: `ls -lh assets/models/*.gguf`

You should see a file around 2.3 GB in size.

## Without This File
The app will still work, but AI coaching will use simple rule-based fallback advice instead of the intelligent LLM-powered coaching.
