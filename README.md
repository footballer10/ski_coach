# Ski Coach

An iPhone app that turns two boot-mounted motion sensors into ski coaching. You ski a run, the app breaks it into turns, scores five parts of your technique, and an AI coach gives you one fix, one cue and one drill after each run.

**Author:** Luke Postma

> **Reviewers:** you can try the app on a Mac with no sensors, no iPhone and no API key. It includes two runs I recorded on the snow, with the coaching GPT gave me for each. See [Try it without sensors](#try-it-without-sensors).

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
- Shows turn-by-turn graphs and exports or imports runs as files

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

## Try it without sensors

You need a **Mac**. You don't need an iPhone, sensors or an OpenAI API key. The app runs in the iPhone Simulator that comes with Xcode.

### 1. Install the tools (one time)

1. Install **Xcode** from the Mac App Store. It's a large download.
2. Open Xcode once. Accept the license, and when it asks which platforms to install, include **iOS**.
3. Install **Homebrew** if you don't have it, by following the one-line install at [brew.sh](https://brew.sh).
4. Install Flutter and CocoaPods by running these in **Terminal**, one at a time:

   ```bash
   brew install --cask flutter
   ```

   ```bash
   brew install cocoapods
   ```

5. Check that everything is ready:

   ```bash
   flutter doctor
   ```

   The **Flutter** and **Xcode** lines should have green check marks. You can ignore Android, Chrome and Android Studio.

### 2. Download and start the app

Run these in Terminal, one at a time:

```bash
git clone https://github.com/footballer10/ski_coach.git
```

```bash
cd ski_coach
```

```bash
open -a Simulator
```

Wait until a simulated iPhone appears on screen, then run:

```bash
flutter run
```

The first build takes a few minutes. When it finishes, the app opens in the simulated iPhone.

### 3. Load a sample run

1. The app opens on **Connect Sensors**. It will keep searching because there are no sensors. Tap the **✕** in the top right corner.
2. Tap the green **Try a Sample Run** button.
3. Pick **Presentation Run** or **Presentation Run 2**.

### 4. What to look at

- **Top card:** date, run length, number of turns and the overall score.
- **Metric list:** the measured value and score for duration, edge angle, parallelness, turn shape and turn symmetry.
- **Coloured boxes:** one per turn with its score. Scroll them to see every turn.
- **Category menu** (top left): pick a metric, such as Edge Angle, to see the run's value against the optimal, every turn's value and score, and a dot plot of values across all turns.
- **Turn menu** (top right): pick one turn to look at it on its own.
- **AI Coach Advice:** the coaching GPT generated for that run, made from the prompt in `lib/config/ai_prompts.dart`.

Swipe left or right to move between runs you've loaded.

### Optional: generate new coaching

Tap the **↻** button on the AI Coach Advice card, paste an OpenAI API key, and tap **Save**. The key is stored only in the simulator, and each request costs a few cents of API credit. The full working takes a few minutes. You can also change or remove the key with the key icon on the start screen.

### If something goes wrong

- **`flutter run` says "No devices found":** run `open -a Simulator` first and wait for the iPhone to appear.
- **CocoaPods fails with an "Encoding" or "Unicode" error:** run `export LANG=en_US.UTF-8` in the same Terminal window, then `flutter run` again.
- **Xcode offers to "Update to recommended settings":** click **Don't Update**.

### Using a real iPhone or the sensors

To install on a real iPhone, open `ios/Runner.xcworkspace` in Xcode, choose your own Apple ID under **Signing & Capabilities**, then connect the phone and run `flutter run --release`. Recording new runs needs two WitMotion WT9011DCL sensors named `WTLeft` and `WTRight`, strapped to the boots.

## Tests

```bash
flutter test
```

This runs the tests for the scoring formulas in `test/scoring_test.dart`.

## Project structure

```
lib/
├── main.dart                    # App entry point
├── models.dart                  # Data models (ImuSample, analysis results)
├── config/
│   ├── ai_config.dart           # API key entered in the app, saved on the device
│   └── ai_prompts.dart          # Coaching system prompt and drill handbook
├── pages/                       # Connection and run screens
├── services/
│   ├── ble_manager.dart         # Bluetooth connection, packet parsing, calibration
│   ├── imu_preprocessor.dart    # Unwrapping, yaw offset, averaging
│   ├── segmentation.dart        # Turn detection
│   ├── metrics/                 # One calculator per metric
│   ├── scoring.dart             # Value → 0–100 score
│   └── ai_coach.dart            # OpenAI API call
└── widgets/                     # Results view, graphs, API key dialog
assets/
└── sample_runs/                 # Two recorded runs with their saved coaching
test/
└── scoring_test.dart            # Tests for the scoring formulas
```
