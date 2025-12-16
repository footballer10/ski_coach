# Ski Coach

AI-powered ski coaching app using dual-sensor IMU technology for real-time turn analysis and personalized feedback.

## Overview

Ski Coach uses Bluetooth IMU sensors on each ski to analyze your skiing technique in real-time. The app detects turns, measures edge angles, parallelness, turn shape, and symmetry, then provides AI-generated coaching advice.

## Features

- **Dual-Sensor Analysis**: Synchronized left/right ski IMU data
- **Turn Detection**: Automatic turn segmentation and direction detection
- **Comprehensive Metrics**:
  - Edge Angle (maximum tilt per turn)
  - Parallelness (whole turn + initiation/control/completion phases)
  - Turn Shape (smoothness via angular velocity standard deviation)
  - Turn Duration and Symmetry
- **Dual AI Modes**:
  - Local: On-device Llama 3.1 8B (no internet required)
  - API: OpenAI GPT-5.2 via API calls
- **Real-time Visualization**: Turn-by-turn metrics with graphs and dot plots

## Quick Start

### Prerequisites
- Flutter SDK
- iPhone 15 Pro Max (or compatible device)
- 2x Bluetooth IMU sensors

### Installation

1. Clone the repository:
```bash
git clone https://github.com/footballer10/ski_coach.git
cd ski_coach
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure AI mode (see [AI Setup Guide](docs/AI_SETUP.md))

4. Build and run:
```bash
flutter run
```

## Documentation

- [AI Setup Guide](docs/AI_SETUP.md) - Configure local and API AI modes
- [Code Organization](docs/CODE_ORGANIZATION.md) - Project structure and architecture
- [BLE Connection Flow](docs/BLE_CONNECTION.md) - Bluetooth sensor connection handling

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
├── pages/                       # UI pages (connection, run, results)
├── services/                    # Core business logic
│   ├── ai_coach.dart           # AI inference (local + API)
│   ├── ai_mode.dart            # AI mode configuration
│   ├── ble_manager.dart        # Bluetooth sensor management
│   ├── segmentation.dart       # Turn detection
│   ├── imu_preprocessor.dart   # Sensor data preprocessing
│   ├── scoring.dart            # Metric scoring system
│   └── metrics/                # Individual metric calculators
├── prompts/                     # AI system prompts
└── widgets/                     # Reusable UI components
```

## License

MIT

## Author

footballer10
