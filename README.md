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

I designed the system: the data pipeline, the scoring formulas, the metrics and the coaching prompt. GitHub Copilot wrote the code from my instructions. ChatGPT helped with research and with drafting parts of the prompt. Before submitting, Claude (Anthropic) helped clean up the code: switching to GPT-6 Luna, removing unused code, adding tests, and setting up the sample-run mode so reviewers can try the app. The commit history shows how the project developed, including approaches I tried and dropped, like running a Llama model on the phone.

## Try it without sensors

**You need:** a Mac with Xcode, Flutter and CocoaPods. You don't need an iPhone, the sensors or an OpenAI API key. The app runs in the iPhone simulator that comes with Xcode. (No Mac? The demo video in my portfolio shows the app in use.)

### 1. Check your tools

In **Terminal**, run:

```bash
flutter doctor
```

If the **Flutter** and **Xcode** lines both have a green ✓, skip to step 2. Ignore the Android, Chrome and Android Studio lines; this app is iPhone only.

<details>
<summary><b>Missing something? How to install it</b></summary>

- **Xcode:** install it from the Mac App Store, open it once, accept the license, and include **iOS** when it asks which platforms to download.
- **Homebrew** (used for the next two): follow the one-line install at [brew.sh](https://brew.sh).
- **Flutter:**

  ```bash
  brew install --cask flutter
  ```

- **CocoaPods** (if the Xcode line in `flutter doctor` says it's missing):

  ```bash
  brew install cocoapods
  ```

Run `flutter doctor` again until Flutter and Xcode both show a green ✓.

</details>

### 2. Download the app and open the simulator

Run these in Terminal, one at a time:

```bash
git clone https://github.com/footballer10/ski_coach.git
```

```bash
cd ski_coach
```

The app is designed for a large iPhone, so use a **Pro Max** simulator. On a smaller one, part of the results screen will be cut off.

1. See which Pro Max simulators you have:

   ```bash
   xcrun simctl list devices available | grep "Pro Max"
   ```

2. Start one, using a name from that list. For example:

   ```bash
   xcrun simctl boot "iPhone 17 Pro Max"
   ```

3. Open the simulator window so you can see it. Which command depends on your Xcode version (`xcodebuild -version` shows it):

   - **Xcode 26 or earlier:**

     ```bash
     open -a Simulator
     ```

   - **Xcode 27 or later** (the Simulator app was replaced by Device Hub):

     ```bash
     open -a DeviceHub
     ```

     Then select the Pro Max you started.

4. Start the app on that simulator, using the same name as in step 2:

   ```bash
   flutter run -d "iPhone 17 Pro Max"
   ```

The first build takes a few minutes. When it finishes, the app appears on the simulated iPhone. Leave Terminal open while you try it, and press `q` there to quit.

**Using the simulator:** click to tap. To scroll, **click and drag** up or down, as if you were dragging with a finger.

### 3. Load a sample run

1. The app opens on **Connect Sensors**. It will keep searching because there are no sensors. Click the **✕** in the top right corner.
2. Click the green **Try a Sample Run** button.
3. Pick **Presentation Run** or **Presentation Run 2**.

### 4. What to look at

- **Top card:** date, run length, number of turns and the overall score.
- **Metric list:** the measured value and score for duration, edge angle, parallelness, turn shape and turn symmetry.
- **Coloured boxes:** one per turn with its score. Click and drag them to see every turn.
- **Category menu** (top left): pick a metric, such as Edge Angle, to see the run's value against the optimal, every turn's value and score, and a dot plot of values across all turns.
- **Turn menu** (top right): pick one turn to look at it on its own.
- **AI Coach Advice:** the coaching GPT generated for that run, made from the prompt in `lib/config/ai_prompts.dart`.

To move between runs you've loaded, click and drag sideways.

### Optional: generate new coaching

Click the **↻** button on the AI Coach Advice card, paste an OpenAI API key, and click **Save**. The key is stored only in the simulator, and each request costs a few cents of API credit. The full working takes a few minutes. You can also change or remove the key with the key icon on the start screen.

### If something goes wrong

- **`flutter run` says "No devices found" or can't find the name:** check the name with `xcrun simctl list devices available | grep "Pro Max"` and start that simulator first (step 2).
- **`xcrun simctl boot` says "Unable to boot device in current state: Booted":** that simulator is already running, so carry on.
- **The simulator window shows a different, smaller iPhone:** select the Pro Max in the Simulator or Device Hub window.
- **`open -a Simulator` says "Unable to find application":** you have Xcode 27 or later; use `open -a DeviceHub` instead.
- **The app is running but you can't see it:** open the simulator window (step 2, part 3).
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
