# BLE Connection Flow

## Overview

The Ski Coach app uses Bluetooth Low Energy (BLE) to connect to dual IMU sensors (one per ski). This document explains the connection lifecycle and error handling.

## Connection Lifecycle

### 1. Initial Discovery
**Page**: `connection_page.dart`

```
User launches app
    ↓
Scan for BLE devices
    ↓
Display available sensors
    ↓
User selects LEFT sensor → Connect
    ↓
User selects RIGHT sensor → Connect
    ↓
Navigate to Run Page
```

### 2. Active Recording
**Page**: `run_page.dart`

```
Subscribe to sensor streams
    ↓
Receive real-time IMU data
    ↓
Display live sensor values
    ↓
User starts recording → Collect samples
    ↓
User stops recording → Process data
```

### 3. Disconnection Handling

**Automatic Detection**:
- Watchdog timers check for data every 1 second
- Timeout threshold: 3 seconds without data
- Stream error handlers catch connection drops

**Recovery Flow**:
```
Sensor disconnects
    ↓
Watchdog detects timeout OR Stream error
    ↓
Show reconnection dialog
    ↓
User chooses:
  - Reconnect → Return to connection page
  - Disconnect All → Exit to home
```

## Architecture

### BLE Manager Service
**File**: `lib/services/ble_manager.dart`

**Responsibilities**:
- Device scanning and connection
- Stream management for IMU data
- Device-side registration (left/right)
- Connection state monitoring

**Key Methods**:
```dart
Stream<Map<String, BluetoothDevice>> scanDevices()
Future<void> connectToDevice(String id)
Future<void> disconnectDevice(String id)
Stream<Map<String, double>>? sampleStream(String id)
void registerDeviceSide(String id, String side)
```

### Run Page State Management
**File**: `lib/pages/run_page.dart`

**Connection Monitoring**:
- `_leftWatchdog` - Monitors left sensor data flow
- `_rightWatchdog` - Monitors right sensor data flow
- `_lastLeftData` - Timestamp of last left sensor packet
- `_lastRightData` - Timestamp of last right sensor packet
- `_disconnectHandled` - Prevents duplicate disconnect triggers

**Stream Subscriptions**:
```dart
StreamSubscription<Map<String, double>>? _leftSub;
StreamSubscription<Map<String, double>>? _rightSub;
```

### Watchdog Implementation

```dart
void _startWatchdogs() {
  _leftWatchdog = Timer.periodic(Duration(seconds: 1), (timer) {
    if (_lastLeftData != null) {
      final timeSince = DateTime.now().difference(_lastLeftData!);
      if (timeSince > Duration(seconds: 3)) {
        _handleSensorDisconnect('Left sensor disconnected');
      }
    }
  });
  
  // Same for right sensor...
}
```

## Error Scenarios

### 1. Sensor Times Out During Recording
```
Recording in progress
    ↓
No data for 3+ seconds
    ↓
Watchdog triggers disconnect handler
    ↓
Stop recording (if active)
    ↓
Show reconnection dialog
```

### 2. Sensor Disconnects Before Recording
```
Sensors connected, waiting to record
    ↓
One sensor disconnects
    ↓
Watchdog triggers disconnect handler
    ↓
Show reconnection dialog
```

### 3. Stream Error
```
Active stream subscription
    ↓
BLE error occurs (signal loss, battery dead, etc.)
    ↓
onError callback triggers
    ↓
_handleSensorDisconnect called
    ↓
Show reconnection dialog
```

## Reconnection Dialog

**Implementation**: `run_page.dart` → `_handleSensorDisconnect()`

**Options**:
1. **Reconnect**: 
   - Cancels subscriptions
   - Stops watchdogs
   - Calls `widget.onManualReconnect()`
   - Returns to connection page

2. **Disconnect All**:
   - Cancels subscriptions
   - Stops watchdogs
   - Calls `widget.onDisconnect()`
   - Exits to home screen

## Data Flow

```
BLE Sensor (Left/Right)
    ↓
BLEManager.sampleStream(deviceId)
    ↓
StreamSubscription in RunPage
    ↓
Update _leftLatest / _rightLatest
    ↓
Display in UI
    ↓ (if recording)
Store in samples list
    ↓ (on stop)
Process and analyze
```

## Best Practices

### For Users
1. Ensure sensors are charged before skiing
2. Keep phone within ~10m of sensors
3. Avoid obstacles between phone and sensors
4. If disconnect occurs, use "Reconnect" option

### For Developers

**When adding BLE features**:
- Always handle stream errors with `onError`
- Use watchdog timers for critical connections
- Prevent duplicate error handlers with flags
- Clean up subscriptions in `dispose()`

**Testing disconnections**:
1. Turn off sensor mid-recording
2. Move phone far from sensors
3. Enable airplane mode
4. Verify dialog appears within 3-4 seconds

## Calibration

**Auto-calibration** occurs when sensors connect:
- Left sensor: `registerDeviceSide(leftId, 'left')`
- Right sensor: `registerDeviceSide(rightId, 'right')`
- BLE Manager stores side mapping
- Used during data processing for correct orientation

## Performance Considerations

- **Sampling Rate**: Typically 50-100Hz per sensor
- **Data Latency**: ~20-50ms from sensor to app
- **Buffer Size**: Streams buffer last N samples
- **Memory**: Recording stores all samples in RAM until processing

## Known Limitations

1. **Range**: BLE typically works up to 10-30m
2. **Interference**: 2.4GHz WiFi can cause packet loss
3. **Battery**: Continuous streaming drains phone/sensor batteries
4. **Concurrent Connections**: Some devices limit simultaneous BLE connections
