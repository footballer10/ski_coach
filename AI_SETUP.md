# AI Coach Setup Instructions

## Step 1: Download the Model

1. Go to: https://huggingface.co/hugging-quants/Llama-3.2-3B-Instruct-GGUF
2. Download the file: `Llama-3.2-3B-Instruct-Q4_K_M.gguf` (~2.3 GB)
3. Place it in: `assets/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf`

## Step 2: Build the App

```bash
flutter pub get
flutter build ios --release  # For iOS
# or
flutter build apk --release  # For Android
```

## How It Works

1. **Model Bundled**: The GGUF model file is bundled with your app in the `assets/models/` folder
2. **First Launch**: On first run, the app copies the model from assets to the app's documents directory
3. **Local Inference**: The AI runs entirely on-device using llama.cpp (no internet needed)
4. **Session Memory**: Tracks last 3 drills to avoid repetition
5. **Fallback**: If AI fails to load, uses rule-based coaching advice

## Usage in Code

```dart
import 'package:ski_coach/services/ai_coach.dart';

final aiCoach = AICoach();
await aiCoach.initialize();

final advice = await aiCoach.generateCoachingAdvice(
  edgeAngleScore: 0.7,
  parallelScore: 0.6,
  turnShapeScore: 0.8,
  durationScore: 0.75,
  runScore: 0.72,
  categoryScores: {
    'Edge Angle': 0.7,
    'Parallel': 0.6,
    'Turn Shape': 0.8,
    'Duration': 0.75,
  },
);

print(advice);
// Output:
// **Category to work on:** Parallel
// **What you're doing wrong:** Your skis aren't matching...
// **Tip:** Focus on equal weight distribution...
// **Drill:** Railroad Tracks - Make turns while...
```

## Model Size & Performance

- **Model Size**: ~2.3 GB (Q4 quantization)
- **RAM Usage**: ~3-4 GB during inference
- **Speed on iPhone 15 Pro Max**: ~10-20 tokens/second
- **Context Window**: 2048 tokens
- **Works Offline**: Yes, completely local

## Customizing the AI

Edit `lib/services/ai_coach.dart`:
- `_handbookContext`: Add more drills from the FIS handbook
- `_buildPrompt`: Adjust the prompt format
- `temperature`, `topK`, `topP`: Adjust AI creativity/randomness

## Troubleshooting

**Q: App crashes on first launch?**
A: The model file might be too large for assets. Consider downloading it on first launch instead.

**Q: AI responses are slow?**
A: Reduce `contextSize` to 1024 or use a smaller model variant (Q3 instead of Q4).

**Q: Model not found error?**
A: Make sure the GGUF file is in `assets/models/` and `flutter pub get` was run.

## Alternative: Download Model on First Launch

If the app bundle is too large, you can download the model on first launch:

```dart
// In ai_coach.dart, replace the asset loading with:
if (!await modelFile.exists()) {
  final url = 'https://huggingface.co/hugging-quants/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf';
  // Download from URL to modelFile
  // Show progress to user
}
```
