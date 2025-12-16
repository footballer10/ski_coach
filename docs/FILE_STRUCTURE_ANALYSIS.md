# Ski Coach - Complete File Structure Analysis

**Total Lines of Code: 7,173 lines**

---

## 📁 Root Level (2 files, 122 lines)

### `main.dart` (29 lines)
**Purpose**: Application entry point

**What it does**:
- Initializes Flutter app with `WidgetsFlutterBinding.ensureInitialized()`
- Gets AI coach singleton and initializes it (loads model if in local mode)
- Sets system prompts for both local and API AI modes
- Launches MaterialApp with AppController as home screen
- Defines app theme (Material 3 with blue color scheme)

**Key components**:
- `main()` - Async entry function
- `MyApp` - Root widget that sets up MaterialApp

---

### `models.dart` (92 lines)
**Purpose**: All data models consolidated in one file

**What it does**:

**ImuSample class** (40 lines):
- Represents a single IMU sensor reading
- Contains accelerometer data (ax, ay, az)
- Contains gyroscope data (gx, gy, gz)
- Contains orientation data (roll, pitch, yaw)
- Optional parallelness field (calculated later)
- `toMap()` method for serialization

**AnalysisResults class** (52 lines):
- Container for complete ski run analysis
- Metadata: sample counts, duration, timestamps, segment indices
- Per-turn arrays: durations, edge angles, directions, parallelness (3 phases), turn shape (3 phases), scores
- Aggregates: symmetry ratio/score, overall score
- Raw data: processed samples and segments for graphing

---

## 📁 config/ (2 files, 1,347 lines)

### `ai_config.dart` (11 lines)
**Purpose**: AI mode configuration and API key storage

**What it does**:
- Defines `AIMode` enum (local, api)
- `AIPreferences` class with static state:
  - `_currentMode` - Currently selected AI mode (defaults to API)
  - `_apiKey` - OpenAI API key (hardcoded constant)
  - Getters and setter for mode switching

**Why it exists**: Separates configuration from business logic

---

### `ai_prompts.dart` (1,336 lines)
**Purpose**: System prompts for AI coaching

**What it does**:
- Contains `localSystemPrompt` (~950 lines) - Detailed instructions for Llama 3.1 8B
- Contains `apiSystemPrompt` (~386 lines) - Similar instructions optimized for GPT-5.2
- Both prompts include:
  - Coaching methodology (category selection, phase analysis, ability calculation)
  - FIS skiing handbook excerpts (drills, techniques, terrain)
  - Output formatting requirements (parseable format)
  - Step-by-step reasoning requirements

**Why it's so large**: Contains entire skiing coaching knowledge base inline

---

## 📁 pages/ (3 files, 1,394 lines)

### `app_controller.dart` (337 lines)
**Purpose**: Root navigation controller managing multiple run sessions

**What it does**:
- Manages PageView with multiple RunPage instances
- Handles BLE connection state (connected/disconnected)
- Shows/hides connection overlay
- Creates new run pages when user taps "Record Again"
- Handles sensor disconnection and reconnection flow
- Maintains list of run page keys for state access
- Implements left/right arrow navigation between runs
- Shows "New Run" button when no runs exist

**State management**:
- `_runPages` - List of RunPage widgets
- `_runPageKeys` - GlobalKeys for accessing RunPage state
- `_bleMgr`, `_leftId`, `_rightId` - BLE connection info
- `_showConnectionOverlay` - Controls connection UI visibility
- `_currentPage` - Current PageView index

**Key callbacks**:
- `_onSensorsConnected()` - Creates first run page
- `_onSensorsDisconnected()` - Shows reconnection dialog
- `_addNewRunPage()` - Adds new run with auto-start

---

### `connection_page.dart` (390 lines)
**Purpose**: BLE sensor discovery and connection UI

**What it does**:
- Scans for nearby BLE devices
- Displays discovered sensors in scrollable list
- Handles left/right sensor selection (must select both)
- Shows connection status and instructions
- Connects to selected sensors
- Navigates back with connected sensors via callback
- Shows error states (Bluetooth off, permission denied)
- Auto-refreshes device list during scanning

**UI components**:
- Device list with signal strength indicators
- Left/Right selection badges
- "Connect Both Sensors" button
- Status messages and instructions
- Bluetooth permission/state error displays

**BLE integration**:
- Uses BleManager for device scanning
- Streams device discovery updates
- Handles connection establishment
- Validates both sensors selected before connecting

---

### `run_page.dart` (667 lines)
**Purpose**: Main recording, analysis, and results screen

**What it does**:

**Recording state**:
- Subscribes to BLE sensor streams
- Displays live IMU values (pitch, roll, yaw)
- Shows AI mode toggle (local/API)
- Starts/stops recording with button
- Collects samples during recording
- Implements watchdog timers (detects sensor disconnection within 3s)

**Processing state**:
- Shows loading indicator while analyzing
- Runs turn segmentation pipeline
- Calculates all metrics (edge angle, parallelness, turn shape, duration, symmetry)
- Computes scores for each metric
- Handles errors (no turns detected, sensor disconnect)

**Results state**:
- Displays ResultsView widget with all turn data
- Shows "Record Again" and "Disconnect All" buttons
- Handles navigation back to new run or connection page

**Error handling**:
- Watchdog timeout detection (3s without data)
- Stream error callbacks
- Sensor disconnect during recording
- Invalid data validation
- User-friendly error messages with recovery options

**State management**:
- `_state` enum (recording, processing, results)
- `_recording` boolean flag
- `_leftLatest`, `_rightLatest` - Latest sensor values
- `_analysisResults` - Map containing all analysis data
- Watchdog timers and timestamps

---

## 📁 services/ (6 files + metrics/, 1,676 lines)

### `ai_coach.dart` (226 lines)
**Purpose**: AI inference engine for both local and API modes

**What it does**:

**Initialization**:
- Singleton pattern via `getAICoach()`
- Loads local model only when in local mode or forced
- Copies 4.9GB model from assets to documents directory (first run)
- Creates Llama instance with 15k context, 5k max response, temp=0
- Falls back to 12.5k/2.5k if device can't handle full context

**Prompt management**:
- `setSystemPromptLocal()` - Sets prompt for Llama 3.1 8B
- `setSystemPromptAPI()` - Sets prompt for GPT-5.2
- `setUserPrompt()` - Sets per-run query with ski data

**Inference**:
- Routes to `_sendPromptsToLocalLLM()` or `_sendPromptsToAPI()` based on mode
- Local: Combines prompts, clears context, streams tokens
- API: Makes HTTPS POST to OpenAI with retry logic
- Handles both `max_tokens` and `max_output_tokens` schemas
- 90-second timeout for API calls
- Robust response parsing (multiple JSON schemas supported)

**Response parsing**:
- `parseAndStoreResponse()` - Extracts category, drill, feedback from `//` delimiters
- Stores coaching history (categories and drills)
- Returns feedback paragraph for display

**Session tracking**:
- Tracks categories coached
- Tracks drills used
- Provides getters for UI display

---

### `ble_manager.dart` (592 lines)
**Purpose**: Bluetooth Low Energy sensor management

**What it does**:

**Device discovery**:
- Scans for BLE devices using flutter_reactive_ble
- Filters for IMU sensors by service UUID
- Streams discovered devices with signal strength
- Maintains device connection state

**Connection management**:
- Connects to specific device by ID
- Subscribes to IMU characteristic notifications
- Handles connection state changes
- Supports multiple simultaneous connections (left + right sensors)

**Data streaming**:
- Parses binary IMU data packets (36 bytes)
- Extracts accelerometer, gyroscope, orientation
- Provides Stream<Map<String, double>> per device
- Converts raw bytes to doubles (little-endian)

**Device-side registration**:
- Maps device ID to "left" or "right" side
- Used for calibration and analysis

**Calibration**:
- Computes yaw offset between sensors
- Stores per-device calibration data

**Data format**:
Each packet contains:
- 3 floats: accelerometer (ax, ay, az)
- 3 floats: gyroscope (gx, gy, gz)
- 3 floats: orientation (roll, pitch, yaw)

---

### `imu_preprocessor.dart` (262 lines)
**Purpose**: Sensor data preprocessing pipeline

**What it does**:

**Step 1 - Unwrap angles** (`unwrapAngles`):
- Removes ±180° discontinuities (sensor wraparound)
- Tracks cumulative angle changes
- Prevents false peaks from angle jumps

**Step 2 - Apply yaw offset** (`applyYawOffset`):
- Calibrates right sensor to match left sensor's reference
- Adjusts for mounting orientation differences

**Step 3 - Correct angle jumps** (`correctAngleJumps`):
- Detects unrealistic angle changes (>10°)
- Filters sensor glitches and noise spikes

**Step 4 - Average yaw signals** (`averageYaw`):
- Combines left and right sensor yaws
- Creates unified turn detection signal
- Preserves individual yaws for parallelness calculation

**Step 5 - Smooth yaw** (`smoothYaw`):
- Moving average filter (window size from sampling rate)
- Reduces high-frequency noise
- Improves peak detection accuracy

**Step 6 - Final unwrap** (`unwrapAngles`):
- Removes wraparound from smoothed signal
- Prepares for peak/valley detection

**Internal helpers**:
- `AnglePoint` class for timestamped angles
- Debug output in development mode
- Sample-by-sample processing logs

---

### `scoring.dart` (31 lines)
**Purpose**: Convert metric values to 0-100 scores

**What it does**:
Contains 5 static scoring functions using empirical formulas:

1. **Duration**: `100 × 0.0005^((ln(x/2))^2)`
   - Peaks at 2.0 seconds
   - Penalizes too fast or too slow

2. **Edge angle**: `102.552 × 0.99818^((x-45)^2) - 2.552`
   - Optimal at 45°
   - Gaussian-like curve

3. **Parallelness**: `100 × 0.9923^(x^1.623)`
   - Lower is better (0° = perfect)
   - Exponential penalty for wedge

4. **Turn shape**: `100 × 0.998946^(x^2)`
   - Lower is better (0 = smooth)
   - Quadratic penalty for jerkiness

5. **Symmetry**: `100 × 0.028^(ln(ratio))`
   - Peaks at ratio = 1.0
   - Penalizes left/right imbalance

All functions clamp to 0-100 range.

---

### `segmentation.dart` (285 lines)
**Purpose**: Turn detection and segmentation

**What it does**:

**Main pipeline** (`segment()`):
1. Runs full preprocessing pipeline
2. Detects peaks (right turns) and valleys (left turns)
3. Pairs consecutive peaks/valleys into turn segments
4. Calls metric calculators for each turn
5. Returns list of `TurnSegment` objects

**Peak/valley detection**:
- Scans smoothed yaw for local maxima/minima
- Requires minimum 15° change from previous peak/valley
- Filters noise and small fluctuations
- Tracks turn direction (1=right, -1=left)

**Turn pairing**:
- Matches each peak to next valley (or vice versa)
- Finds corresponding sample indices in left/right sensors
- Ensures both sensors have data for the turn

**Metric integration**:
- Calls `EdgeAngleCalculator` for max pitch
- Calls `ParallelnessCalculator` for yaw differences
- Calls `TurnShapeCalculator` for smoothness
- Calls `DurationCalculator` for turn timing

**Data structures**:
- `TurnSegment` - Complete turn with metrics and boundaries
- `SegmentationParams` - Configuration (min peak change)
- `_Peak` - Internal peak/valley representation

**Debug output**:
- Extensive logging in development mode
- Shows every preprocessing step
- Logs detected peaks/valleys
- Reports final turn count

---

## 📁 services/metrics/ (5 files, 380 lines)

### `duration_calculator.dart` (26 lines)
**Purpose**: Calculate turn duration

**What it does**:
- `calculate()` - Returns time difference between start and end
- Simple subtraction: `endTime - startTime` in seconds
- No complex logic needed

---

### `edge_angle_calculator.dart` (66 lines)
**Purpose**: Calculate maximum edge angle (pitch)

**What it does**:
- Scans all samples in turn segment (both sensors)
- Finds maximum absolute pitch value
- Filters unrealistic values (>90°)
- Returns max edge angle in degrees

**Debug output**:
- Shows each pitch value
- Marks when new max is found
- Reports final max

---

### `parallelness_calculator.dart` (111 lines)
**Purpose**: Measure ski parallelness (yaw difference)

**What it does**:

**Calculation**:
- For each sample: `abs(right_yaw - left_yaw)`
- Uses original individual sensor yaws (not averaged)
- Splits turn into thirds (beginning/middle/end)
- Computes average for each third + overall

**Phase detection**:
- Beginning: First 1/3 of samples
- Middle: Middle 1/3 of samples
- End: Final 1/3 of samples

**Returns** (`ParallelnessResult`):
- Overall average parallelness
- Beginning phase average
- Middle phase average
- End phase average

**Debug output**:
- Shows L_yaw, R_yaw, difference for each sample
- Marks which third each sample belongs to
- Reports phase averages

---

### `turn_shape_calculator.dart` (90 lines)
**Purpose**: Measure turn smoothness via angular velocity SD

**What it does**:

**Calculation**:
- Computes angular velocities between samples (Δyaw / Δtime)
- Calculates standard deviation of velocities
- Higher SD = more jerky/inconsistent
- Lower SD = smoother/more consistent

**Phase analysis**:
- Same thirds logic as parallelness
- SD computed per phase

**Returns** (`TurnShapeResult`):
- Overall SD
- Beginning phase SD
- Middle phase SD
- End phase SD

**Debug output**:
- Shows each angular velocity
- Lists phase assignments
- Reports SD for each phase

---

### `symmetry_calculator.dart` (87 lines)
**Purpose**: Calculate left/right turn balance

**What it does**:

**Data collection**:
- Separates turns by direction (-1 = left, +1 = right)
- Averages duration for left turns
- Averages duration for right turns

**Ratio calculation**:
- `ratio = avgLeftDuration / avgRightDuration`
- ratio > 1.0 → left turns longer
- ratio < 1.0 → right turns longer
- ratio = 1.0 → balanced

**Score calculation**:
- Uses scoring formula from `Scoring.symmetry()`
- Converts ratio to 0-100 score

**Returns** (`SymmetryResult`):
- Left/right turn counts
- Average durations
- Symmetry ratio
- Symmetry score

**Edge cases**:
- Returns null if no left or right turns exist
- Handles division by zero

---

## 📁 widgets/ (2 files, 2,535 lines)

### `results_view.dart` (2,381 lines)
**Purpose**: Display comprehensive turn analysis results

**What it does**:

**Component 1 - DotPlotScaler** (230 lines):
- Creates histogram binning for dot plots
- Computes optimal column boundaries
- Handles scaling to show data distribution
- Finds column containing optimal value
- Complex math for nice round numbers

**Component 2 - DotPlot widget** (197 lines):
- Visualizes turn metric distribution
- Shows dots for each turn in columns
- Highlights selected turn
- Draws vertical line at optimal value
- Custom painting for dots and line

**Component 3 - Main ResultsView** (~1,900 lines):

**Header section**:
- Overall score (large, colored)
- Turn count and run duration
- Sample counts (left/right sensors)

**Metrics cards** (4 cards):
Each shows:
- Category name and icon
- Average score (colored)
- Measured value vs optimal
- Dot plot distribution
- Expandable detail with turn-by-turn table

**Categories**:
1. Turn Duration (⏱️)
2. Edge Angle (📐)
3. Parallelness (🎿) - 4 rows (overall + 3 phases)
4. Turn Shape (〰️) - 4 rows (overall + 3 phases)

**Symmetry section**:
- Turn counts (left vs right)
- Average durations
- Symmetry ratio and score
- Visual balance indicator

**Time-series graphs**:
- Yaw over time (shows turns)
- Tap to select turn
- Highlights selected turn region

**AI Coaching section**:
- "Get AI Coaching" button
- Generates coaching advice
- Shows loading state
- Displays feedback paragraph
- Extracts and shows drill name

**State management**:
- Selected turn index
- AI loading state
- AI response text
- Expansion states for cards

**Helper methods**:
- Score color coding (red/yellow/green)
- Optimal value formatting
- Turn direction labels (L/R)
- Metric value formatting

---

### `time_series_graph.dart` (154 lines)
**Purpose**: Plot time-series data with interactive selection

**What it does**:

**Data model**:
- `GraphPoint` - Single (timestamp, value) pair

**Widget** (`TimeSeriesGraph`):
- Displays line graph of values over time
- Shows turn segments as colored regions
- Highlights selected turn
- Interactive tap to select turns
- Auto-scales to fit data

**Rendering** (`TimeSeriesGraphPainter`):
- Custom painter for graph
- Draws grid lines
- Plots data line
- Draws turn regions (alternating colors)
- Highlights selected turn with distinct color
- Labels axes

**Features**:
- Tap detection to select nearest turn
- Automatic padding and margins
- Responsive to screen size
- Clean, minimal design

---

## Summary Statistics

### By Category

| Category | Files | Lines | Percentage |
|----------|-------|-------|------------|
| Widgets | 2 | 2,535 | 35.3% |
| Config (AI Prompts) | 1 | 1,336 | 18.6% |
| Pages | 3 | 1,394 | 19.4% |
| Services | 6 | 1,454 | 20.3% |
| Metrics | 5 | 380 | 5.3% |
| Models | 1 | 92 | 1.3% |
| **Total** | **19** | **7,173** | **100%** |

### Largest Files

1. `results_view.dart` - 2,381 lines (33.2%)
2. `ai_prompts.dart` - 1,336 lines (18.6%)
3. `run_page.dart` - 667 lines (9.3%)
4. `ble_manager.dart` - 592 lines (8.3%)
5. `connection_page.dart` - 390 lines (5.4%)

### Architecture Quality

✅ **Strengths**:
- Clean separation of concerns
- Single responsibility per file
- Metrics isolated in calculators
- Configuration separate from logic
- Well-structured data flow

✅ **Code organization**:
- 19 focused files vs monolithic structure
- Average 377 lines per file
- Clear import dependencies
- Minimal coupling between modules
