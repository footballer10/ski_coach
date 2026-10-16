# Ski Coach

An iPhone app that turns two boot-mounted motion sensors into ski coaching. You ski a run, the app breaks it into turns, scores five parts of your technique, and an AI coach gives you one fix, one cue and one drill after each run.

**Author:** Luke Postma

## What it does

- Connects to two Bluetooth IMU sensors (WitMotion WT9011DCL), one strapped to each ski boot
- Records a run, then detects each turn and whether it went left or right
- Measures five metrics for every turn:
  - **Turn duration**: how long each turn takes
  - **Edge angle**: how far the skis tip onto their edges
  - **Parallelness**: the angle between the two skis, for the whole turn and for the initiation, control and completion phases
  - **Turn shape**: how smooth the turn is (spread of angular velocity), also split into three phases
  - **Turn symmetry**: how left turns compare to right turns
- Converts each metric to a 0–100 score and averages them into a run score
- After the run, sends the scores and measured values to OpenAI GPT-6 Luna, which picks your weakest area and returns coaching from a drill handbook
- Shows turn-by-turn graphs, saves a daily summary, and exports or imports runs as files

## How it works

Each step of the pipeline lives in its own file:

| Step | What happens | File |
| --- | --- | --- |
| 1. Bytes | Reads 20-byte `0x55 0x61` packets from each sensor and decodes acceleration, angular velocity, roll, pitch and yaw | `lib/services/ble_manager.dart` |
| 2. Angles | Unwraps yaw past ±180°, applies the left/right yaw offset measured during calibration, and averages the two yaw signals | `lib/services/imu_preprocessor.dart` |
| 3. Turns | Finds peaks and valleys in the averaged yaw signal and splits the run into turns | `lib/services/segmentation.dart` |
| 4. Values | Calculates each metric per turn and averages across the run | `lib/services/metrics/` |
| 5. Scores | Maps each value to a 0–100 score with a formula per metric | `lib/services/scoring.dart` |
| 6. Coaching | Builds the user prompt from the scores and values, sends it with the system prompt, and extracts the final coaching paragraph | `lib/widgets/results_view.dart`, `lib/services/ai_coach.dart`, `lib/config/ai_prompts.dart` |

### Scoring formulas

| Metric | Optimal | Score |
| --- | --- | --- |
| Turn duration (s) | 1.0 | `100x` below 1 s, `100/x` above |
| Edge angle (°) | as high as possible | `100 − 100·e^(−0.00005·x^2.96)` |
| Parallelness (°) | 0 | `100·e^(−(x/30)²)` |
| Turn shape (SD) | 0 | `100·e^(−(x/46.2)²)` |
| Turn symmetry (ratio) | 1.0 | `100/x²` |

### The coaching prompt

The system prompt in `lib/config/ai_prompts.dart` makes the model work through fixed steps: choose the lowest-scoring category, check the phase scores for parallelness and turn shape, work out an ability level, compare the measured value to the optimal value, then go through every drill in the handbook and score how well it fits. The model shows all of its working, and the app only displays the final line after `//`: one sentence on what went wrong, one movement cue, and one drill.

## How it was built

I designed the system: the data pipeline, the scoring formulas, the metrics and the coaching prompt. GitHub Copilot wrote the code from my instructions. ChatGPT helped with research and with drafting parts of the prompt. The commit history shows how the project developed, including approaches I tried and dropped, like running a Llama model on the phone.

## Setup

### Requirements

- macOS with Xcode and the Flutter SDK (Dart 3.9 or later)
- An iPhone (iOS 15 or later)
- Two WitMotion WT9011DCL Bluetooth IMU sensors
- An OpenAI API key with credits

### Steps

1. Clone the repository:

   ```bash
   git clone https://github.com/footballer10/ski_coach.git
   cd ski_coach
   ```

2. Create `lib/config/secrets.dart` with your OpenAI API key. This file is in `.gitignore`, so it never gets committed.

   ```dart
   const String openAiApiKey = 'sk-...';
   ```

3. Install dependencies:

   ```bash
   flutter pub get
   cd ios && pod install && cd ..
   ```

4. Connect your iPhone and run:

   ```bash
   flutter run
   ```

5. Run the tests:

   ```bash
   flutter test
   ```

## Project structure

```
lib/
├── main.dart                    # App entry point
├── models.dart                  # Data models (ImuSample, analysis results)
├── models/daily_summary.dart    # Daily summary model
├── config/
│   ├── ai_config.dart           # Reads the API key
│   ├── ai_prompts.dart          # Coaching system prompt and drill handbook
│   └── secrets.dart             # Your API key (not committed)
├── pages/                       # Connection, run, and daily summary screens
├── services/
│   ├── ble_manager.dart         # Bluetooth connection, packet parsing, calibration
│   ├── imu_preprocessor.dart    # Unwrapping, yaw offset, averaging
│   ├── segmentation.dart        # Turn detection
│   ├── metrics/                 # One calculator per metric
│   ├── scoring.dart             # Value → 0–100 score
│   └── ai_coach.dart            # OpenAI API call
└── widgets/                     # Results view and graphs
test/
└── scoring_test.dart            # Tests for the scoring formulas
```
