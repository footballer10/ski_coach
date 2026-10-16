# lib/ - Source Code Structure

## Quick Reference

```
lib/
├── main.dart                    # App entry point & initialization
├── models.dart                  # Data models (ImuSample, AnalysisResults)
├── models/
│   └── daily_summary.dart      # Daily summary model
├── config/                      # Configuration files
│   ├── ai_config.dart          # Reads the API key from secrets.dart
│   ├── ai_prompts.dart         # Coaching system prompt + drill handbook
│   └── secrets.dart            # OpenAI API key (gitignored, create locally)
├── pages/                       # UI screens
│   ├── app_controller.dart     # Root navigation controller
│   ├── connection_page.dart    # BLE sensor connection UI
│   ├── daily_summary_page.dart # End-of-day summary
│   └── run_page.dart           # Recording & results screen
├── services/                    # Business logic
│   ├── ai_coach.dart           # OpenAI API call (GPT-6 Luna)
│   ├── ble_manager.dart        # Bluetooth sensor management
│   ├── imu_preprocessor.dart   # Sensor data preprocessing
│   ├── scoring.dart            # Metric → score conversion
│   ├── segmentation.dart       # Turn detection & segmentation
│   └── metrics/                # Individual metric calculators
│       ├── duration_calculator.dart
│       ├── edge_angle_calculator.dart
│       ├── parallelness_calculator.dart
│       ├── symmetry_calculator.dart
│       └── turn_shape_calculator.dart
└── widgets/                     # Reusable UI components
    ├── results_view.dart       # Turn analysis visualization
    └── time_series_graph.dart  # Time-series data plotting
```

## Module Types

### Models (Single File)
All data structures consolidated in `models.dart`.

### Config
API key and the coaching prompt.

### Pages
Full-screen UI with state management.

### Services
Core business logic, isolated from UI.

### Widgets
Reusable UI components used across pages.

## Import Patterns

### Models
```dart
import 'package:ski_coach/models.dart';
```

### Config
```dart
import 'package:ski_coach/config/ai_config.dart';
import 'package:ski_coach/config/ai_prompts.dart';
```

### Services
```dart
import 'package:ski_coach/services/ai_coach.dart';
import 'package:ski_coach/services/metrics/edge_angle_calculator.dart';
```

## Design Principles

1. **Single Responsibility**: Each file has one clear purpose
2. **Service Isolation**: Business logic independent of UI
3. **Metric Modularity**: Each metric in its own calculator
4. **Clean Dependencies**: UI depends on services, not vice versa
5. **Consolidated Models**: Simple data classes in one file

See the [main README](../README.md) for the full data pipeline.
