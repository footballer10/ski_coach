# Ski Coach Code Organization

## Overview
The codebase follows **single responsibility principle** with clean separation between data models, configuration, services, UI pages, and reusable widgets.

## Directory Structure

```
lib/
├── main.dart                              # App entry point
├── models.dart                            # Data models (ImuSample, AnalysisResults)
├── config/                                # Configuration files
│   ├── ai_config.dart                    # AI mode selection & API key
│   └── ai_prompts.dart                   # System prompts (local + API)
├── services/                              # Core business logic
│   ├── ai_coach.dart                     # AI inference engine
│   ├── ble_manager.dart                  # Bluetooth sensor management
│   ├── segmentation.dart                 # Turn detection & segmentation
│   ├── imu_preprocessor.dart             # Data preprocessing pipeline
│   ├── scoring.dart                      # Metric scoring functions
│   └── metrics/                          # Individual metric calculators
│       ├── edge_angle_calculator.dart
│       ├── parallelness_calculator.dart
│       ├── turn_shape_calculator.dart
│       ├── duration_calculator.dart
│       └── symmetry_calculator.dart
├── pages/                                 # UI screens
│   ├── app_controller.dart               # Root navigation
│   ├── connection_page.dart              # BLE connection UI
│   └── run_page.dart                     # Recording & results
└── widgets/                               # Reusable UI components
    ├── results_view.dart                 # Turn analysis display
    └── time_series_graph.dart            # Time-series plotting
```

## Module Responsibilities

### 📦 `models.dart`
**Purpose:** Consolidated data models

**Classes:**
- `ImuSample` - Single IMU sensor reading with accelerometer, gyroscope, orientation
- `AnalysisResults` - Complete ski run analysis results container

**Why consolidated:** Simple data classes with no business logic, easier imports

---

### ⚙️ `config/`
**Purpose:** Application configuration and settings

**Files:**
- `ai_config.dart` - AI mode enum, API key, mode switching
- `ai_prompts.dart` - System prompts for local and API AI (~9000 tokens each)

**Why separate folder:** Configuration isolated from business logic, clear separation of concerns

---

### 📊 `segmentation.dart`
**Purpose:** Pure turn segmentation - identifies turn boundaries only

**Responsibilities:**
- Orchestrates the preprocessing pipeline
- Detects yaw peaks and valleys (turn boundaries) 
- Creates `TurnSegment` objects with metric results
- Delegates metric calculations to specialized calculators

**Key Function:**
```dart
List<TurnSegment> TurnSegmentation.segment({
  required List<ImuSample> leftSamples,
  required List<ImuSample> rightSamples,
  required double yawOffset,
  required double samplingRate,
  SegmentationParams? params,
})
```

---

### 🔧 `imu_preprocessor.dart`
**Purpose:** Clean and prepare raw IMU data for analysis

**Pipeline Steps:**
1. **Apply yaw offset** - Calibrate right sensor
2. **Correct angle jumps** - Fix sensor glitches >10°
3. **Unwrap sensor yaws** - Remove ±180° discontinuities (before averaging!)
4. **Average yaw signals** - Combine left/right (preserves originals for parallelness)
5. **Smooth yaw** - Moving average filter
6. **Unwrap smoothed yaw** - Prepare for peak detection

**Key Classes:**
- `ImuPreprocessor` - All preprocessing methods
- `AnglePoint` - Timestamped angle data structure

**Important:** All methods show debug output for EVERY sample when `kDebugMode` is true.

---

### 📐 `metrics/edge_angle_calculator.dart`
**Purpose:** Calculate maximum edge angle (pitch) from both skis

**Metric:** Maximum absolute pitch value across all samples in turn segment

**Debug Output:** Shows every pitch value with "NEW MAX" indicators

**Key Function:**
```dart
double EdgeAngleCalculator.calculateMaxEdgeAngle({
  required List<ImuSample> leftSamples,
  required List<ImuSample> rightSamples,
  required int startIdxLeft,
  required int endIdxLeft,
  required int startIdxRight,
  required int endIdxRight,
  required int turnNumber,
})
```

---

### 📏 `metrics/parallelness_calculator.dart`
**Purpose:** Measure how parallel the skis are throughout turns

**Metric:** Absolute yaw difference `|right_yaw - left_yaw|`
- Calculated per sample using **original individual sensor yaws** (not averaged)
- Split into turn thirds (beginning, middle, end)
- Returns overall average plus averages per third

**Debug Output:** Shows L_yaw, R_yaw, difference, and third assignment for ALL samples

**Key Function:**
```dart
ParallelnessResult ParallelnessCalculator.calculate({
  required List<ImuSample> leftSamples,
  required List<ImuSample> rightSamples,
  required int startIdxLeft,
  required int endIdxLeft,
  required int startIdxRight,
  required int endIdxRight,
  required DateTime startTime,
  required DateTime endTime,
  required int turnNumber,
})
```

**Returns:**
```dart
class ParallelnessResult {
  final double average;     // Overall average
  final double beginning;   // First third average
  final double middle;      // Middle third average  
  final double end;         // Final third average
}
```

---

### 🌊 `metrics/smoothness_calculator.dart`
**Purpose:** Measure how smooth/consistent turn execution is

**Metric:** Standard deviation of angular velocity
- Angular velocity = `Δyaw × sampling_rate` 
- Calculated from **smoothed averaged yaw**
- Split into turn thirds
- Lower SD = smoother turn

**Debug Output:** Shows yaw values, delta, angular velocity, and third assignment for ALL samples

**Key Function:**
```dart
SmoothnessResult SmoothnessCalculator.calculate({
  required List<AnglePoint> smoothedYaw,
  required List<double> unwrappedSmoothedYaw,
  required DateTime startTime,
  required DateTime endTime,
  required double samplingRate,
  required int turnNumber,
})
```

**Returns:**
```dart
class SmoothnessResult {
  final double average;     // Average of 3 SDs
  final double beginning;   // First third SD
  final double middle;      // Middle third SD
  final double end;         // Final third SD
}
```

---

### ⏱️ `metrics/duration_calculator.dart`
**Purpose:** Calculate individual turn duration

**Metric:** Time elapsed from turn start to turn end in seconds

**Debug Output:** Shows start time, end time, and calculated duration

**Key Function:**
```dart
double DurationCalculator.calculate({
  required DateTime startTime,
  required DateTime endTime,
  required int turnNumber,
})
```

---

### ⚖️ `metrics/symmetry_calculator.dart`
**Purpose:** Measure balance between left and right turns

**Metric:** Ratio of average durations
- Separates turns by direction (-1 = left, +1 = right)
- Calculates average duration for each direction
- Returns `bigger_average / smaller_average`
- 1.0 = perfect symmetry, higher = more asymmetric

**Debug Output:** Shows all left turn durations, all right turn durations, averages, and final ratio

**Key Function:**
```dart
SymmetryResult SymmetryCalculator.calculate({
  required List<double> turnDurations,
  required List<int> turnDirections,
})
```

**Returns:**
```dart
class SymmetryResult {
  final double? ratio;           // null if can't calculate
  final int leftCount;           // Number of left turns
  final int rightCount;          // Number of right turns
  final double? leftAverage;     // Average left turn duration
  final double? rightAverage;    // Average right turn duration
}
```

---

## Data Flow

```
Raw IMU Data (left, right)
    ↓
╔═══════════════════════════════════════════╗
║   ImuPreprocessor (processing/)           ║
║  1. Apply calibration offset (right)      ║
║  2. Correct angle jumps (>10°)            ║
║  3. Unwrap individual sensor yaws         ║
║  4. Average unwrapped yaws                ║
║  5. Smooth averaged yaw                   ║
║  6. Unwrap smoothed yaw                   ║
╚═══════════════════════════════════════════╝
    ↓
╔═══════════════════════════════════════════╗
║   TurnSegmentation                        ║
║   - Detect peaks/valleys                  ║
║   - Create turn boundaries                ║
╚═══════════════════════════════════════════╝
    ↓
╔═══════════════════════════════════════════╗
║   Metric Calculators (metrics/)           ║
║                                           ║
║   EdgeAngleCalculator                     ║
║   → max |pitch| from both sensors         ║
║                                           ║
║   ParallelnessCalculator                  ║
║   → |right_yaw - left_yaw| per third      ║
║                                           ║
║   SmoothnessCalculator                    ║
║   → SD(angular_velocity) per third        ║
║                                           ║
║   DurationCalculator                      ║
║   → turn end - turn start (seconds)       ║
║                                           ║
║   SymmetryCalculator                      ║
║   → avg_left / avg_right ratio            ║
╚═══════════════════════════════════════════╝
    ↓
TurnSegment objects
    ↓
Results visualization
```

## Key Architectural Decisions

### 1. **Unwrap BEFORE Averaging**
The yaw signals are unwrapped at the individual sensor level BEFORE averaging to prevent wraparound corruption when sensors are on opposite sides of ±180°.

### 2. **Preserve Original Sensor Data**
Individual sensor yaw values are preserved throughout the pipeline because parallelness calculation requires the original (not averaged) yaw from each ski.

### 3. **Extreme Verbosity Debugging**
All processing steps output debug information for EVERY sample (not just first 10) when `kDebugMode` is enabled, providing complete visibility into the pipeline.

### 4. **Separate Concerns**
- **Processing** = Clean data
- **Segmentation** = Find turn boundaries  
- **Metrics** = Calculate performance values

This separation makes the code:
- ✅ Easier to test
- ✅ Easier to maintain
- ✅ Easier to extend with new metrics
- ✅ Easier to understand

## Usage Example

```dart
// In run_page.dart
final segments = TurnSegmentation.segment(
  leftSamples: leftImu,
  rightSamples: rightImu,
  yawOffset: calibrationOffset,
  samplingRate: 100.0,  // Hz
);

// Access metrics from segments
for (final seg in segments) {
  print('Turn: ${seg.durationSeconds}s');
  print('Max Edge: ${seg.maxEdgeAngle}°');
  print('Parallelness: ${seg.avgParallelness}° '
        '(1st=${seg.beginningParallelness}°, '
        'mid=${seg.middleParallelness}°, '
        'end=${seg.endParallelness}°)');
  print('Smoothness: ${seg.avgSmoothnessSD}°/s '
        '(1st=${seg.beginningSmoothnessSD}°/s, '
        'mid=${seg.middleSmoothnessSD}°/s, '
        'end=${seg.endSmoothnessSD}°/s)');
}
```

## Adding New Metrics

To add a new metric:

1. Create `lib/services/metrics/your_metric_calculator.dart`
2. Implement calculation with debug output
3. Add result class if needed (e.g., `YourMetricResult`)
4. Call from `segmentation.dart` in the turn loop
5. Add fields to `TurnSegment` class
6. Update visualization in `results_view.dart`

Example template:

```dart
class YourMetricCalculator {
  static YourMetricResult calculate({
    required List<ImuSample> leftSamples,
    required List<ImuSample> rightSamples,
    // ... other required data
    required int turnNumber,
  }) {
    if (kDebugMode) {
      debugPrint('📊 METRIC X: YOUR METRIC - ALL SAMPLES');
    }
    
    // Your calculation here
    
    return YourMetricResult(/* ... */);
  }
}
```

## Migration Notes

### Old API (deprecated):
```dart
TurnSegmentation.segment(
  left: leftSamples,
  right: rightSamples,
  yawOffset: offset,
)
```

### New API:
```dart
TurnSegmentation.segment(
  leftSamples: leftSamples,
  rightSamples: rightSamples,
  yawOffset: offset,
  samplingRate: 100.0,  // NEW: required for smoothness calculation
)
```

## Testing

Each module can now be unit tested independently:

- **Preprocessor tests**: Verify calibration, jump correction, unwrapping
- **Segmentation tests**: Verify peak detection with known yaw patterns
- **Metric tests**: Verify calculations with synthetic turn data

## Performance

The reorganization has **no performance impact**. The same calculations are performed, just organized differently. All expensive operations (filtering, unwrapping, etc.) remain unchanged.

---

**Last Updated:** December 2, 2025
**Version:** 2.0 (Modular Architecture)
