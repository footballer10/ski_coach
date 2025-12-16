# AI Model File Location

## Required for Local AI Mode

**File**: `llama-3.1-8b-instruct-q4_k_m.gguf` (~4.9GB)

## Download Instructions

1. Visit: https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF
2. Download: `Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf` (4.9GB)
3. Rename to: `llama-3.1-8b-instruct-q4_k_m.gguf`
4. Place in this directory

## Expected Structure

```
ski_coach/
  assets/
    models/
      llama-3.1-8b-instruct-q4_k_m.gguf  ← Place here
      README.md                           ← This file
```

## Verification

Windows:
```powershell
dir assets\models\*.gguf
```

Mac/Linux:
```bash
ls -lh assets/models/*.gguf
```

Expected: ~4.9GB file

## Important Notes

- **Not in Git**: File excluded due to size (gitignored)
- **Only for Local Mode**: API mode doesn't need this file
- **First Launch**: App copies from assets to documents directory
- **Storage**: Requires ~5GB free space on device

See [docs/AI_SETUP.md](../../docs/AI_SETUP.md) for detailed setup instructions.
