# Ski Coach

An iPhone app that turns two boot-mounted motion sensors into a ski coach. You ski a run, the app splits it into individual turns, scores five parts of your technique, and an AI coach gives you one thing to fix, one movement cue and one drill.

**Author:** Luke Postma

**Built with:** Flutter (Dart), Bluetooth Low Energy, OpenAI API

> **Reviewers:** you can try the app on a Mac without the sensors, an iPhone or an API key. It includes two runs I recorded on the snow, along with the coaching the AI generated for each. See [Try it without sensors](#try-it-without-sensors).

## What it does

- Connects to two Bluetooth IMU sensors (WitMotion WT9011DCL), one strapped to each ski boot
- Records a run, then detects each turn and whether it went left or right
- Measures five metrics for every turn:
  - **Turn duration:** how long each turn takes
  - **Edge angle:** how far the skis tip onto their edges
  - **Parallelness:** the angle between the two skis, for the whole turn and for the initiation, control and completion phases
  - **Turn shape:** how smooth the turn is (spread of angular velocity), also split into three phases
  - **Turn symmetry:** how left turns compare to right turns
- Converts each metric to a 0–100 score and combines them into a run score
- After the run, sends the scores and measured values to OpenAI GPT-6 Luna, which finds the weakest area and returns coaching based on a drill handbook
- Shows turn-by-turn results and graphs, and exports and imports runs as files

## How it works

Each step of the pipeline lives in its own file:

| Step | What happens | File |
| --- | --- | --- |
| 1. Bytes | Reads 20-byte `0x55 0x61` packets from each sensor and decodes acceleration, angular velocity, roll, pitch and yaw | `lib/services/ble_manager.dart` |
| 2. Angles | Unwraps yaw past ±180°, applies the left/right yaw offset measured during calibration, and averages the two yaw signals | `lib/services/imu_preprocessor.dart` |
| 3. Turns | Finds peaks and valleys in the averaged yaw signal and splits the run into turns | `lib/services/segmentation.dart` |
| 4. Values | Calculates each metric per turn and averages across the run | `lib/services/metrics/` |
| 5. Scores | Maps each value to a 0–100 score with a formula per metric | `lib/services/scoring.dart` |
| 6. Coaching | Builds a prompt from the scores and values, sends it with the system prompt, and extracts the final coaching paragraph | `lib/widgets/results_view.dart`, `lib/services/ai_coach.dart`, `lib/config/ai_prompts.dart` |

### Scoring formulas

| Metric | Optimal | Score |
| --- | --- | --- |
| Turn duration (s) | 1.0 | `100x` below 1 s, `100/x` above |
| Edge angle (°) | as high as possible | `100 − 100·e^(−0.00005·x^2.96)` |
| Parallelness (°) | 0 | `100·e^(−(x/30)²)` |
| Turn shape (SD) | 0 | `100·e^(−(x/46.2)²)` |
| Turn symmetry (ratio) | 1.0 | `100/x²` |

### The coaching prompt

The system prompt in `lib/config/ai_prompts.dart` makes the model work through fixed steps:
1. Choose the lowest-scoring category.
2. Check the phase scores for parallelness and turn shape.
3. Work out an ability level.
4. Compare the measured value to the optimal value.
5. Go through every drill in the handbook and score how well it fits.

The model shows all of its working, but the app only displays the final line after `//`: one sentence on what went wrong, one movement cue and one drill.

## How it was built

I designed the system: the data pipeline, the metrics, the scoring formulas and the coaching prompt. GitHub Copilot wrote the code from my instructions. ChatGPT helped with research and with drafting parts of the prompt. Before submission, Claude (Anthropic) helped clean up the code: switching to GPT-6 Luna, removing unused code, adding tests, and adding the sample-run mode so reviewers can try the app. The commit history shows how the project developed, including approaches I tried and dropped, such as running a Llama model on the phone.

## Try it without sensors

**You need:** a Mac with Xcode, Flutter and CocoaPods. You don't need an iPhone, the sensors or an OpenAI API key, because the app runs in the iPhone simulator that comes with Xcode. Without a Mac, the demo video in my portfolio shows the app in use.

### 1. Check your tools

In Terminal, run:

```bash
flutter doctor
```

If the **Flutter** and **Xcode** lines both have a green ✓, go to step 2. You can ignore the Android, Chrome and Android Studio lines, since this app is iPhone only.

<details>
<summary><b>Missing something? How to install it</b></summary>

- **Xcode:** install it from the Mac App Store, open it once, accept the license, and include **iOS** when it asks which platforms to download.
- **Homebrew** (used for the next two): follow the one-line install at [brew.sh](https://brew.sh).
- **Flutter:**

  ```bash
  brew install --cask flutter
  ```

- **CocoaPods**, if the Xcode line in `flutter doctor` says it's missing:

  ```bash
  brew install cocoapods
  ```

Run `flutter doctor` again until Flutter and Xcode both show a green ✓.

</details>

### 2. Download and run the app

Run these in Terminal, one at a time:

```bash
git clone https://github.com/footballer10/ski_coach.git
```

```bash
cd ski_coach
```

Open the iPhone simulator. The command depends on your Xcode version, which `xcodebuild -version` shows:

- **Xcode 26 or earlier:**

  ```bash
  open -a Simulator
  ```

- **Xcode 27 or later** (Device Hub replaced the Simulator app): run the command below, then select an iPhone simulator in the window that opens.

  ```bash
  open -a DeviceHub
  ```

When a simulated iPhone is showing, start the app:

```bash
flutter run
```

The first build takes a few minutes. When it's done, the app opens on the simulated iPhone. Keep Terminal open while you use it, and press `q` in Terminal to quit.

**Using the simulator:** click to tap. To scroll, click and drag, as if you were dragging with a finger.

### 3. Load a sample run

1. The app opens on **Connect Sensors** and keeps searching, because there are no sensors. Click the **✕** in the top right corner.
2. Click the green **Try a Sample Run** button.
3. Pick **Presentation Run** or **Presentation Run 2**.

### 4. What to look at

- **Top card:** date, run length, number of turns and overall score.
- **Metric list:** the measured value and score for duration, edge angle, parallelness, turn shape and turn symmetry.
- **Colored boxes:** one per turn, with its score. Drag them to see every turn.
- **Category menu** (top left): pick a metric, such as Edge Angle, to see the run's value against the optimal, every turn's value and score, and a dot plot of the values across all turns.
- **Turn menu** (top right): pick a single turn to look at it on its own.
- **AI Coach Advice:** the coaching the AI generated for that run, using the prompt in `lib/config/ai_prompts.dart`. Drag inside the box to read all of it.

To switch between loaded runs, drag sideways.

### Optional: generate new coaching

Click the **↻** button on the AI Coach Advice card, paste an OpenAI API key and click **Save**. The key is stored only in the simulator. Each request uses a small amount of API credit and takes a few minutes, because the model works through every step of the prompt. To change or remove the key later, use the key icon on the start screen.

### Troubleshooting

- **`open -a Simulator` says "Unable to find application":** you have Xcode 27 or later, so use `open -a DeviceHub` instead.
- **`flutter run` says "No devices found":** open the simulator first (step 2) and wait for the iPhone to appear.
- **`flutter run` asks which device to use:** choose the iPhone simulator.
- **The app is running but you can't see it:** open the simulator window with the command from step 2.
- **CocoaPods fails with an "Encoding" or "Unicode" error:** run `export LANG=en_US.UTF-8` in the same Terminal window, then run `flutter run` again.
- **Xcode offers to "Update to recommended settings":** click **Don't Update**.

### Using a real iPhone or the sensors

To install on a real iPhone, open `ios/Runner.xcworkspace` in Xcode, choose your own Apple ID under **Signing & Capabilities**, connect the phone and run `flutter run --release`. Recording new runs requires two WitMotion WT9011DCL sensors named `WTLeft` and `WTRight`, strapped to the boots.

## Tests

```bash
flutter test
```

This runs the tests for the scoring formulas and the API key dialog.

## Project structure

```
lib/
├── main.dart                    # App entry point
├── models.dart                  # Data models (IMU samples, analysis results, exported runs)
├── config/
│   ├── ai_config.dart           # API key entered in the app and saved on the device
│   └── ai_prompts.dart          # Coaching system prompt and drill handbook
├── pages/                       # Connection and run screens
├── services/
│   ├── ble_manager.dart         # Bluetooth connection, packet parsing, calibration
│   ├── imu_preprocessor.dart    # Unwrapping, yaw offset, averaging
│   ├── segmentation.dart        # Turn detection
│   ├── metrics/                 # One calculator per metric
│   ├── scoring.dart             # Value → 0–100 score
│   └── ai_coach.dart            # OpenAI API request
└── widgets/                     # Results view, graphs, API key dialog
assets/
└── sample_runs/                 # Two recorded runs with their saved coaching
test/
├── scoring_test.dart            # Scoring formula tests
└── api_key_dialog_test.dart     # API key dialog tests
```
