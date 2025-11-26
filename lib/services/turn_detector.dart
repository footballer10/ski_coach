// User-editable segmentation hook.
// Replace `segmenter` with your own function that takes the recorded samples
// (`List<Map<String,double>>`) and returns a list of segment descriptors.

typedef Segmenter = List<dynamic> Function(List<Map<String, double>> samples);

/// Default no-op segmenter: returns an empty list. Replace this with your
/// implementation (keep the same signature) to have `MemoryRecording.stopAndSegment`
/// call it automatically.
List<dynamic> defaultSegmenter(List<Map<String, double>> samples) => [];

// Global entry point the app will call. Edit this assignment to plug your
// segmentation function.
Segmenter segmenter = defaultSegmenter;
