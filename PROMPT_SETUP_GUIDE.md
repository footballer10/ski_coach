# AI Prompt Setup Guide

## ✅ Everything is now set up!

### Where to customize prompts:

---

## 1. **SYSTEM PROMPT** (Instructions for the AI)
**Location:** `lib/main.dart` - lines 10-14

**What it does:** Sets the AI's behavior, personality, and instructions (sent once on app startup)

**How to change it:**
```dart
aiCoach.setSystemPrompt(
  "PASTE YOUR SYSTEM PROMPT HERE - this defines how the AI should behave"
);
```

**Current placeholder:**
```dart
aiCoach.setSystemPrompt(
  "You are an expert ski coach AI. Analyze the skier's performance data and provide "
  "clear, actionable coaching advice. Focus on the weakest category and suggest specific "
  "drills to improve technique. Keep responses concise and skiing-focused."
);
```

---

## 2. **USER PROMPT** (Run data sent each time)
**Location:** `lib/widgets/results_view.dart` - lines 558-566

**What it does:** Sends the actual ski run data to the AI (sent after each run)

**How to change it:**
```dart
aiCoach.setUserPrompt(
  'PASTE YOUR USER PROMPT FORMAT HERE - include placeholders for run data'
);
```

**Current format:**
```dart
aiCoach.setUserPrompt(
  'Run Analysis:\n'
  'Overall Score: ${widget.results?.overallScore?.toStringAsFixed(1) ?? "N/A"}\n'
  'Edge Angle: ${avgEdgeAngle.toStringAsFixed(1)}° (Score: ${categoryScores["Edge Angle"]?.toStringAsFixed(1)})\n'
  'Parallel: ${avgParallel.toStringAsFixed(1)}° (Score: ${categoryScores["Parallel"]?.toStringAsFixed(1)})\n'
  'Turn Shape: ${avgTurnShape.toStringAsFixed(2)} (Score: ${categoryScores["Turn Shape"]?.toStringAsFixed(1)})\n'
  'Duration: ${avgDuration.toStringAsFixed(2)}s (Score: ${categoryScores["Duration"]?.toStringAsFixed(1)})\n\n'
  'What should I focus on to improve my skiing?'
);
```

---

## 3. **OUTPUT DISPLAY** (Where AI response appears)
**Location:** `lib/widgets/results_view.dart` - automatically displayed at bottom of results page

**How it works:**
- After each run, the app automatically:
  1. Sets the user prompt with run data
  2. Calls `generateCoachingAdvice()`
  3. Displays the response in a Card widget at the bottom of the results page

**UI States:**
- ⏳ Loading: Shows "Generating coaching advice..." spinner
- ✅ Success: Displays AI response
- ❌ Error: Shows error message with details

---

## 4. **Testing the prompts:**

1. **In LM Studio:**
   - Paste your system prompt in the "System Prompt" field
   - Paste sample user prompt data in the chat input
   - Test different variations

2. **In the app:**
   - Update the prompts in the code (locations above)
   - Run the app
   - Complete a ski run
   - Check the results page for AI coaching advice

---

## 5. **Next step: Wire up llama_cpp_dart**

**Current status:**
- ✅ Model file ready in `assets/models/`
- ✅ System prompt set in `main.dart`
- ✅ User prompt set in `results_view.dart`
- ✅ Output display ready
- ⏳ Need to confirm llama_cpp_dart API

**To complete:**
- Verify the correct class/method names for llama_cpp_dart v0.1.2+1
- Uncomment the inference code in `ai_coach.dart` line 156-162
- Update with correct API calls

**Location:** `lib/services/ai_coach.dart` - lines 156-171

---

## Summary:

| What | Where | Status |
|------|-------|--------|
| System Prompt | `lib/main.dart` lines 10-14 | ✅ Ready to customize |
| User Prompt | `lib/widgets/results_view.dart` lines 558-566 | ✅ Ready to customize |
| Output Display | `lib/widgets/results_view.dart` (automatic) | ✅ Working |
| LLM Integration | `lib/services/ai_coach.dart` lines 156-171 | ⏳ Needs API verification |

**You can now paste your system and user prompts in the locations above!**
