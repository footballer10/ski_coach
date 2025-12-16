# AI Configuration Guide

## Overview
The Ski Coach app now supports **two AI modes**:

1. **Local AI** (Llama 3.1 8B)
   - Runs entirely on-device
   - No internet required
   - No API costs
   - Requires ~5GB storage for model

2. **API AI** (GPT-4)
   - Runs via OpenAI API
   - Requires internet connection
   - Requires OpenAI API key
   - Pay-per-use pricing

## Default Configuration
- **Default mode**: API (GPT-4)
- The local model will NOT load automatically at app startup
- You can switch modes anytime using the toggle in the top-right

## Setting Up API Mode

### 1. Get an OpenAI API Key
- Go to: https://platform.openai.com/api-keys
- Create an account or sign in
- Generate a new API key
- Copy the key (starts with `sk-...`)

### 2. Configure the API Key in the App
1. Open the app
2. On the recording page, tap the **Settings icon** (⚙️) in the top-right
3. Paste your API key
4. Tap **Save**

### 3. Toggle Between Modes
- Use the **Local/API switch** in the top-right corner
- **Local** = On-device Llama 3.1 8B (green)
- **API** = OpenAI GPT-4 (blue)

## How It Works

### API Mode (Default)
1. App sends your run data to OpenAI API
2. GPT-4 processes the data and generates coaching advice
3. Response is displayed in the results view
4. Requires internet and API key

### Local Mode
1. First use: App loads 5GB model into memory (takes ~30 seconds)
2. Your run data is processed entirely on-device
3. Llama 3.1 8B generates coaching advice
4. No internet required

## System Prompt
Both modes use the same system prompt (configured in `main.dart`):
- You can customize the AI's coaching style by editing the system prompt
- The prompt defines how the AI should analyze runs and provide feedback

## Technical Details

### Files Modified
- `lib/services/ai_mode.dart` - AI mode enum and preferences
- `lib/services/ai_coach.dart` - Dual-mode AI logic
- `lib/pages/run_page.dart` - UI toggle for mode selection
- `lib/widgets/ai_config_dialog.dart` - API key configuration dialog
- `lib/main.dart` - Removed automatic model loading

### API Endpoint
- **Base URL**: `https://api.openai.com/v1/chat/completions`
- **Model**: `gpt-4`
- **Temperature**: 0.0 (deterministic)
- **Max tokens**: 2500

### Local Model
- **Model**: Llama-3.1-8B-Instruct-Q4_K_M.gguf
- **Size**: ~4.9GB
- **Context window**: 12,500 tokens
- **Max response**: 2,500 tokens

## Cost Considerations

### API Mode
- Pay per API call to OpenAI
- Pricing: https://openai.com/pricing
- Typical cost: ~$0.01-0.05 per coaching session

### Local Mode
- No ongoing costs
- One-time storage requirement (~5GB)
- May drain battery faster during inference

## Troubleshooting

### API Mode Issues
- **"API key not set"**: Configure API key via settings icon
- **Network error**: Check internet connection
- **401 Unauthorized**: Invalid API key, check your key
- **429 Rate limit**: Too many requests, wait a moment

### Local Mode Issues
- **Model loading timeout**: Give it 30-60 seconds on first load
- **Out of memory**: Close other apps, device may not have enough RAM
- **Model not found**: Ensure assets are bundled with the app

## Next Steps
1. Set your API key (if using API mode)
2. Toggle between modes to compare results
3. Customize the system prompt for your coaching style
4. Enjoy AI-powered ski coaching!
