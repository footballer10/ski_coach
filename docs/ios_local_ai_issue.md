# iOS Local AI Model Issue

## Problem
The `llama_cpp_dart` package (v0.1.2+1) does not properly support iOS. When trying to load the local AI model on iOS, you'll encounter this error:

```
LlamaException: Failed to initialize Llama (Invalid argument(s): 
Failed to lookup symbol 'llama_log_set': dlsym(RTLD_DEFAULT, llama_log_set): symbol not found)
```

## Root Cause
The llama.cpp native library included in the package is not properly compiled for iOS. The symbol `llama_log_set` is missing from the iOS binary.

## Potential Solutions

### Option 1: Wait for Package Update (Recommended)
The package maintainers need to update the iOS binaries. Check https://pub.dev/packages/llama_cpp_dart for updates.

### Option 2: Build iOS Binary Manually
1. Clone the llama_cpp_dart repository
2. Rebuild the iOS native libraries from llama.cpp source
3. Replace the binaries in the package
4. This requires Xcode and native iOS development knowledge

### Option 3: Use Alternative Package
Consider using a different on-device LLM package that has proper iOS support, such as:
- `flutter_langchain` (if available)
- MLKit or CoreML-based solutions
- Server-based approach with local server on device

### Option 4: Contribute to the Package
If you have iOS development experience:
1. Fork the llama_cpp_dart repository
2. Fix the iOS build configuration
3. Submit a pull request

## Current Workaround
For now, use API mode on iOS devices. The toggle is enabled, but attempting to use Local mode will show an error. The API mode works perfectly on all platforms.

## Files Modified
- Re-enabled the Local AI toggle on iOS (no longer disabled)
- Users will see error if they try to use it, which is better than hiding the feature

## Status
⚠️ Local AI on iOS: **Not Working** (Package limitation)
✅ API AI on iOS: **Working**
✅ Local AI on Android/Desktop: **Working**
