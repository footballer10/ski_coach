# ✅ AI DUAL-MODE SETUP COMPLETE

## What's Ready

### ✅ 1. Toggle Functionality
- **Location**: Top-right of recording page
- **Default**: API mode (GPT-5.2)
- **Toggle**: Switch between Local (Llama 3.1 8B) and API (GPT-5.2)
- **Auto-loads**: When toggled to Local, model loads automatically on first use

### ✅ 2. System Prompt
- **Location**: `lib/main.dart` (line 13)
- **Status**: Already configured
- **Usage**: SAME prompt for both Local and API modes
- **Current**: Expert ski coach with actionable advice

### ✅ 3. User Prompt
- **Location**: Generated in `lib/widgets/results_view.dart` (line ~850)
- **Status**: Ready to use
- **Usage**: SAME prompt for both Local and API modes
- **Format**: JSON with run scores, turn data, and session history

### ✅ 4. API Key Configuration
**Option A - In Code (Recommended for your use):**
- **File**: `lib/services/ai_mode.dart`
- **Line**: 12
- **Current**: `static String? _apiKey = 'YOUR_API_KEY_HERE';`
- **Action needed**: Replace `'YOUR_API_KEY_HERE'` with your actual OpenAI API key

**Option B - In App (Dynamic):**
- Tap settings icon (⚙️) on recording page
- Enter API key in dialog
- Will override the hardcoded key

### ✅ 5. API Calls
- **Endpoint**: `https://api.openai.com/v1/chat/completions`
- **Model**: `gpt-5.2`
- **Method**: `_sendPromptsToAPI()` in `ai_coach.dart`
- **Status**: Fully implemented and ready
- **Routing**: Automatically called when toggle is set to API

### ✅ 6. Local Model Loading
- **Trigger**: Automatically loads when toggle is set to Local
- **Lazy loading**: Only loads if/when needed
- **Status**: Fully implemented
- **Location**: `_loadLocalModel()` in `ai_coach.dart`

## How It Works

### Flow Diagram
```
User finishes run
    ↓
Results view calls generateCoachingAdvice()
    ↓
Checks AIPreferences.currentMode
    ↓
    ├─→ Local? → Load model (if needed) → _sendPromptsToLocalLLM()
    │                                              ↓
    │                                     On-device inference
    │
    └─→ API? → Check API key → _sendPromptsToAPI()
                                       ↓
                                 OpenAI GPT-5.2 call
```

### Prompts Are Identical
Both modes use:
1. **System Prompt**: Set once in `main.dart`
2. **User Prompt**: Generated per-run in `results_view.dart`

The only difference is WHERE the prompts are processed:
- **Local**: On your phone (Llama 3.1 8B)
- **API**: OpenAI servers (GPT-5.2)

## What You Need to Do

### ⚠️ REQUIRED: Set API Key
1. Open: `lib/services/ai_mode.dart`
2. Find line 12: `static String? _apiKey = 'YOUR_API_KEY_HERE';`
3. Replace with: `static String? _apiKey = 'sk-proj-...';` (your actual key)
4. Save the file

### That's It!
Everything else is ready to go:
- ✅ System prompt configured
- ✅ User prompt auto-generated
- ✅ Toggle switches modes
- ✅ Local model loads on demand
- ✅ API calls implemented
- ✅ Routing logic complete

## Testing

### Test API Mode
1. Ensure API key is set
2. Toggle should show "API" with cloud icon (blue)
3. Run a session
4. View results
5. AI feedback will come from GPT-5.2

### Test Local Mode
1. Toggle to "Local" with phone icon (green)
2. First use: Model loads (~30 seconds)
3. Run a session
4. View results
5. AI feedback will come from on-device Llama 3.1 8B

### Compare Results
- Use toggle to switch between modes
- Same prompts, different models
- Compare coaching advice quality/style

## Verification Checklist
- ✅ AI mode enum created (Local/API)
- ✅ Default set to API
- ✅ API key can be set in code
- ✅ GPT-5.2 model name configured
- ✅ System prompt ready (main.dart)
- ✅ User prompt auto-generated (results_view.dart)
- ✅ Toggle UI implemented (run_page.dart)
- ✅ Routing logic implemented (ai_coach.dart)
- ✅ Local model lazy-loads on toggle
- ✅ API calls properly formatted
- ✅ Both use same prompts
- ✅ No compilation errors

## Next Step
**Add your OpenAI API key to `lib/services/ai_mode.dart` line 12, and you're ready to go!**
