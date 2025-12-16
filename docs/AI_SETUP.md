# AI Setup Guide

## Overview

Ski Coach supports two AI modes for generating coaching advice:

1. **Local AI** - Llama 3.1 8B (on-device, no internet)
2. **API AI** - OpenAI GPT-5.2 (cloud-based)

## Switching Between Modes

Use the toggle in the top-right corner of the recording screen:
- 📱 (phone icon) = Local mode (green when active)
- ☁️ (cloud icon) = API mode (blue when active)

Default: API mode

---

## Local AI Setup

### Requirements
- ~5GB device storage for model file
- iPhone 15 Pro Max (or device with sufficient RAM)

### Installation Steps

1. **Download the model file**:
   - Visit: https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF
   - Download: `Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf` (~4.9GB)

2. **Place the model**:
   - Location: `assets/models/llama-3.1-8b-instruct-q4_k_m.gguf`

3. **Build the app**:
   ```bash
   flutter pub get
   flutter build ios --release
   ```

### How It Works
- Model is bundled with the app in `assets/models/`
- On first run, copied to app's documents directory
- Runs entirely on-device using llama_cpp_dart
- Context: 15,000 tokens
- Max response: 5,000 tokens
- Temperature: 0.0 (deterministic)

### Fallback
If device can't handle 15k context:
- Falls back to 12,500 context / 2,500 response

---

## API AI Setup

### Requirements
- Internet connection
- OpenAI API key

### Installation Steps

1. **Get API key**:
   - Go to: https://platform.openai.com/api-keys
   - Create account or sign in
   - Generate new API key (starts with `sk-proj-...`)

2. **Configure the key**:
   - Open: `lib/services/ai_mode.dart`
   - Find: `static const String _apiKey = 'YOUR_KEY_HERE';`
   - Replace with your actual API key

3. **Run the app**:
   ```bash
   flutter run
   ```

### How It Works
- Makes HTTPS requests to OpenAI API
- Model: gpt-5.2
- Context: 15,000 tokens (system + user prompts)
- Max response: 5,000 tokens
- Temperature: 0.0 (deterministic)
- Timeout: 90 seconds

### Pricing
- Pay-per-use based on OpenAI's pricing
- Check current rates: https://openai.com/api/pricing/

---

## System Prompts

Both modes use separate system prompts (defined in `lib/prompts/system_prompts.dart`):

- `localSystemPrompt` - Optimized for Llama 3.1 8B
- `apiSystemPrompt` - Optimized for GPT-5.2

User prompts (run data) are identical for both modes.

---

## Configuration Files

### `lib/services/ai_mode.dart`
```dart
enum AIMode { local, api }

class AIPreferences {
  static AIMode _currentMode = AIMode.api;
  static const String _apiKey = 'YOUR_API_KEY_HERE';
  
  static AIMode get currentMode => _currentMode;
  static String get apiKey => _apiKey;
  static void setMode(AIMode mode) => _currentMode = mode;
}
```

### `lib/services/ai_coach.dart`
- Singleton service managing both AI backends
- Routes requests based on `AIPreferences.currentMode`
- Handles model loading, prompt formatting, response parsing

### `lib/prompts/system_prompts.dart`
- `localSystemPrompt` - ~9000 tokens
- `apiSystemPrompt` - ~9000 tokens
- Both contain detailed skiing expertise and formatting instructions

---

## Troubleshooting

### Local Mode Issues

**Model won't load**:
- Check file exists: `assets/models/llama-3.1-8b-instruct-q4_k_m.gguf`
- Verify file size: ~4.9GB
- Ensure device has enough RAM

**App crashes on model load**:
- Device may not have enough memory
- Try using API mode instead

### API Mode Issues

**API key error**:
- Verify key is set in `lib/services/ai_mode.dart`
- Ensure key starts with `sk-proj-`
- Check key is valid at platform.openai.com

**Timeout errors**:
- Check internet connection
- API may be experiencing high load
- Default timeout is 90 seconds

**Rate limit errors**:
- You've exceeded OpenAI API quota
- Wait and retry, or upgrade plan

---

## Performance Comparison

| Feature | Local AI | API AI |
|---------|----------|--------|
| Internet Required | No | Yes |
| First-time Setup | Download 4.9GB model | Get API key |
| Response Time | 10-30s | 2-10s |
| Cost | Free (after model) | Pay-per-use |
| Privacy | 100% on-device | Data sent to OpenAI |
| Quality | Good | Excellent |
| Reliability | Depends on device | Depends on internet |

---

## Best Practices

1. **Use Local mode** when:
   - Skiing in areas with poor connectivity
   - Want to avoid API costs
   - Privacy is paramount

2. **Use API mode** when:
   - Need fastest response times
   - Want highest quality advice
   - Have reliable internet connection
   - Device storage is limited
