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

If the **Flutter** and **Xcode** lines both have a green ✓, go to step 2. Errors on the Android, Chrome and Android Studio lines are fine, since this app is iPhone only.

<details>
<summary><b>Missing something? How to install it</b></summary>

- **Xcode:** install it from the Mac App Store, then open it once and accept the license. When it asks which platforms to download, tick **iOS**. It's listed as optional, but the iPhone simulator needs it.
- **Homebrew** (used for the next two). This is the official install command from [brew.sh](https://brew.sh):

  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

  It asks for your Mac password. If it finishes with "Next steps" commands, run those. Then **quit Terminal completely and reopen it**, or the `brew` command won't be found.
- **Flutter:**

  ```bash
  brew install --cask flutter
  ```

- **CocoaPods**, if the Xcode line in `flutter doctor` says it's missing:

  ```bash
  brew install cocoapods
  ```

Run `flutter doctor` again until Flutter and Xcode both show a green ✓.

If the Xcode line says **"Xcode installation is incomplete"**, run these two commands one at a time. Each asks for your Mac password.

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

```bash
sudo xcodebuild -runFirstLaunch
```

Then run `flutter doctor` again.

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

- **Xcode 27 or later** (Device Hub replaced the Simulator app):

  ```bash
  open -a DeviceHub
  ```

  If no iPhone is listed in the Device Hub window, add one:
  1. Click **+**, then choose **iPhone**.
  2. Choose **iOS 27**, not iOS 27.1. iOS 27.1 only offers the iPhone Duo.
  3. Pick any iPhone model, then select it so it starts up.

When a simulated iPhone is showing, start the app:

```bash
flutter run
```

The first build takes a few minutes. When it's done, the app opens on the simulated iPhone. Keep Terminal open while you use it, and press `q` in Terminal to quit.

**Using the simulator:** click to tap. To scroll, click and drag, as if you were dragging with a finger.

### 3. Load a sample run

1. The app opens on **Connect Sensors**, where it searches for the sensors. Click the green **No sensors? Try a sample run** button at the bottom.
2. Pick **Presentation Run** or **Presentation Run 2**.

To load another sample later, drag sideways back to the **Recording Session** screen and click **Try a Sample Run**.

### 4. What to look at

- **Top card:** date, run length, number of turns and overall score.
- **Metric list:** the measured value and score for duration, edge angle, parallelness, turn shape and turn symmetry.
- **Colored boxes:** one per turn, with its score. Drag them to see every turn.
- **Category menu** (top left): pick a metric, such as Edge Angle, to see the run's value against the optimal, every turn's value and score, and a dot plot of the values across all turns.
- **Turn menu** (top right): pick a single turn to look at it on its own.
- **AI Coach Advice:** the coaching the AI generated for that run, using the prompt in `lib/config/ai_prompts.dart`. Drag inside the box to read all of it.

To switch between loaded runs, drag sideways.

### Optional: generate new coaching

Click the **↻** button on the AI Coach Advice card, paste an OpenAI API key and click **Save**. The key is stored only in the simulator. Each request uses a small amount of API credit and takes a few minutes, because the model works through every step of the prompt. To change or remove the key later, use the key icon on the **Recording Session** screen.

### Troubleshooting

- **`open -a Simulator` says "Unable to find application":** you have Xcode 27 or later, so use `open -a DeviceHub` instead.
- **`flutter doctor` says "Xcode installation is incomplete":** run the two `sudo` commands at the end of "Missing something? How to install it" in step 1.
- **Device Hub shows no iPhone:** click **+**, choose **iPhone**, pick **iOS 27** (not 27.1) and any iPhone model.
- **`flutter run` says "No devices found":** open the simulator first (step 2) and wait for the iPhone to appear.
- **`flutter run` asks which device to use:** choose the iPhone simulator.
- **The app is running but you can't see it:** open the simulator window with the command from step 2.
- **CocoaPods fails with an "Encoding" or "Unicode" error:** run `export LANG=en_US.UTF-8` in the same Terminal window, then run `flutter run` again.
- **Xcode offers to "Update to recommended settings":** click **Don't Update**.

### Optional: run it on a real iPhone

This also needs the Mac setup from step 1, plus a USB cable. A free Apple ID is enough.

1. Plug the iPhone into the Mac, unlock it, and tap **Trust** if it asks.
2. Open the project in Xcode:

   ```bash
   open ios/Runner.xcworkspace
   ```

3. In Xcode, click **Runner** at the top of the left sidebar, then the **Signing & Capabilities** tab.
   - Under **Team**, choose your Apple ID. If it isn't listed, click **Add an Account…** and sign in, then pick **(Personal Team)**.
   - Change **Bundle Identifier** to something unique, for example `com.yourname.skicoach`. Xcode shows an error until the identifier is unique.
4. On the iPhone, turn on **Developer Mode** in **Settings → Privacy & Security → Developer Mode**, then let the phone restart. If the option isn't there, unplug the phone, plug it back in, and check again.
5. Back in Terminal, in the `ski_coach` folder, run the command below. If Flutter asks which device to use, pick the iPhone.

   ```bash
   flutter run --release
   ```

6. The first time, the iPhone blocks the app as coming from an "Untrusted Developer". Go to **Settings → General → VPN & Device Management**, tap your Apple ID, then tap **Trust**. Open the app from the home screen.

On a free Apple ID, the app keeps working for 7 days.

Recording new runs requires two WitMotion WT9011DCL sensors named `WTLeft` and `WTRight`, strapped to the boots. Without them, use the sample runs, just like in the simulator.

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
