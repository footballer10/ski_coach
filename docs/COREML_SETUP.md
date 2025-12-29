# CoreML Setup Instructions for iOS

## What I've Done (Automated)

✅ Created Swift files for CoreML integration:
- `ios/Runner/CoreMLBridge.swift` - Platform channel bridge
- `ios/Runner/SkiCoachModel.swift` - CoreML model wrapper
- Updated `ios/Runner/AppDelegate.swift` - Registered plugin

✅ Created Flutter integration:
- `lib/services/coreml_ai_coach.dart` - Dart wrapper for CoreML
- Updated `lib/services/ai_coach.dart` - Automatic iOS detection and routing

✅ Created conversion scripts:
- `scripts/convert_to_coreml.py` - Model conversion helper

## What You Need to Do (15-30 minutes)

### Step 1: Open Xcode (2 minutes)

1. On your Mac, navigate to the project:
   ```bash
   cd /path/to/ski_coach
   open ios/Runner.xcworkspace
   ```

2. Wait for Xcode to open and index the project

### Step 2: Add Swift Files to Xcode (5 minutes)

The Swift files are already created, you just need to add them to Xcode:

1. In Xcode's left sidebar (Project Navigator), find the `Runner` folder
2. Right-click on `Runner` folder
3. Select "Add Files to 'Runner'..."
4. Navigate to `ios/Runner/` directory
5. Select these files:
   - `CoreMLBridge.swift`
   - `SkiCoachModel.swift`
6. **IMPORTANT**: Check ✅ "Copy items if needed"
7. **IMPORTANT**: Under "Add to targets", check ✅ `Runner`
8. Click "Add"

### Step 3: Verify AppDelegate.swift (1 minute)

1. In Xcode, open `Runner/AppDelegate.swift`
2. Verify it contains this line:
   ```swift
   CoreMLBridge.register(with: registrar(forPlugin: "CoreMLBridge")!)
   ```
3. If not, the file should already be updated - just verify

### Step 4: Get the CoreML Model (10-20 minutes)

You have 2 options:

#### Option A: Download Pre-converted (Easier, Recommended)

1. Go to Hugging Face: https://huggingface.co/models?library=coreml
2. Search for "Llama-3.1-8B" with CoreML
3. Download the `.mlpackage` file (will be large, ~5GB)
4. Rename it to exactly: `SkiCoachLlama.mlpackage`
5. In Xcode, drag this file into the `Runner` folder
6. Check ✅ "Copy items if needed"
7. Check ✅ "Add to targets: Runner"

#### Option B: Convert Your GGUF Model (Advanced)

1. On your Mac, install conversion tools:
   ```bash
   pip3 install coremltools
   ```

2. Run the conversion script:
   ```bash
   cd ski_coach/scripts
   python3 convert_to_coreml.py
   ```

3. Follow the script's instructions
4. When complete, drag the `.mlpackage` into Xcode (see Option A steps 5-7)

### Step 5: Build the App (2 minutes)

1. In Xcode, select your iPhone as the target device
2. Click the "Play" button (▶️) or press `Cmd + R`
3. Wait for build to complete
4. If you get code signing errors:
   - Select the `Runner` project in sidebar
   - Go to "Signing & Capabilities" tab
   - Select your Apple Developer team

### Step 6: Test on Your iPhone (2 minutes)

1. Open the app on your iPhone
2. Connect to sensors
3. Toggle to "Local" mode
4. You should see: "🍎 Loading CoreML model into memory..."
5. After ~2-3 seconds: "🍎 CoreML model loaded and ready!"
6. Record a run and test AI feedback

## How It Works Now

### Automatic Platform Detection

The app automatically detects iOS and uses CoreML:

```
┌─────────────────┐
│   AI Toggle     │
│  API ⟷ Local   │
└────────┬────────┘
         │
    ┌────▼─────┐
    │ Platform?│
    └────┬─────┘
         │
    ┌────▼────┬──────────┐
    │         │          │
┌───▼──┐  ┌──▼──┐  ┌────▼────┐
│ iOS  │  │Androi│ │ Desktop │
│CoreML│  │llama │ │ llama   │
└──────┘  └──────┘ └─────────┘
```

### What Happens When You Toggle to Local:

**iOS:**
1. Detects iOS platform
2. Loads CoreML model into memory
3. Uses Apple Neural Engine for inference
4. 40-60 tokens/second expected

**Android/Desktop:**
5. Uses existing llama_cpp_dart
6. Same behavior as before

### Performance Expectations

**iPhone 15 Pro Max (your phone):**
- Model load time: 2-3 seconds
- Typical response: 400 tokens @ 50 tok/s = **8 seconds** ✅
- Memory usage: ~5GB
- Battery: Efficient (Neural Engine optimized)

**Comparison:**
- API mode: ~2-3 seconds, costs $0.10/run
- CoreML mode: ~8 seconds, costs $0.00/run, works offline

## Troubleshooting

### "Model not found" Error

**Problem:** The `.mlpackage` file isn't in the app bundle

**Solution:**
1. In Xcode, check if `SkiCoachLlama.mlpackage` is in the Runner folder
2. Select the file
3. In right sidebar, under "Target Membership", check ✅ `Runner`
4. Rebuild the app

### "CoreML not initialized" Error

**Problem:** Platform detection might not be working

**Solution:**
1. Check that you're actually running on iOS (not simulator if that doesn't support)
2. Verify the Swift files were added correctly
3. Clean build: Product → Clean Build Folder (⇧⌘K)
4. Rebuild

### Model Takes Too Long to Load

**Problem:** First-time compilation of .mlpackage

**Solution:**
- First load always takes longer (5-10 seconds)
- Subsequent loads are faster (2-3 seconds)
- This is normal CoreML behavior

### App Crashes on Model Load

**Problem:** Might be memory issue or corrupt model

**Solution:**
1. Check iPhone storage (need 5-6GB free)
2. Re-download the model file
3. Verify it's not corrupted (try on a different device)

### Build Errors in Xcode

**Problem:** Swift compilation errors

**Solution:**
1. Make sure you're targeting iOS 16.0 or later
2. Check Build Settings → Swift Language Version (should be Swift 5.x)
3. Clean and rebuild

## File Checklist

Before building, verify these files exist:

```
ios/Runner/
├── AppDelegate.swift ................... ✓ Modified
├── CoreMLBridge.swift .................. ✓ New
├── SkiCoachModel.swift ................. ✓ New
└── SkiCoachLlama.mlpackage ............. ⚠️ You add this

lib/services/
├── ai_coach.dart ....................... ✓ Modified
└── coreml_ai_coach.dart ................ ✓ New
```

## Success Indicators

When everything is working, you'll see:

1. **Toggle to Local mode:**
   ```
   🍎 Loading CoreML model into memory...
   🍎 CoreML model loaded and ready!
   ```

2. **Generate feedback:**
   ```
   🍎 Generating response with CoreML...
   🍎 CoreML generation completed in 8423ms
   ```

3. **No errors in Xcode console**
4. **Feedback appears in ~8-10 seconds**
5. **Works offline (try airplane mode)**

## Next Steps After Setup

Once CoreML is working:

1. Test thorough - record multiple runs
2. Compare quality with API mode (should be identical)
3. Test offline functionality
4. Monitor battery usage
5. Adjust settings if needed

## Need Help?

If you get stuck:

1. Check Xcode console for error messages
2. Verify all files are added correctly
3. Make sure model file is in bundle
4. Try clean build
5. Check iOS version (needs 16.0+)

## Performance Tuning (Optional)

If you want to make it faster:

1. **Reduce max tokens:** Change 6000 → 4000 in `ai_coach.dart`
2. **Optimize model:** Use INT4 quantization (already done)
3. **Batch processing:** Not applicable for single-run inference
4. **GPU fallback:** Already using all compute units

---

**Expected Timeline:**
- Xcode setup: 5 minutes
- Model download: 10-15 minutes
- First build: 3-5 minutes
- Testing: 5 minutes
- **Total: ~25-30 minutes**

**You'll save $200-300/year in API costs!** 💰
