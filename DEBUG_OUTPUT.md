# Debug Output Guide

This document describes the debug logging added to track data flow during a ski run.

## Connection Flow

### Scanning
- `🔍 Starting new scan` - New BLE scan initiated

### Connection
- `✓ Connected, waiting for data` - Both sensors connected
- `✓ Left data OK` - First data packet received from left sensor
- `✓ Right data OK` - First data packet received from right sensor
- `✓ Both sensors ready` - Both sensors streaming data, proceeding to run page
- `❌ Connection failed: L=<bool> R=<bool>` - Connection attempt failed
- `❌ No sensor data` - Connected but no data received within timeout

### Calibration
- `🎯 Yaw calibration: right=<angle>° left=<angle>° offset=<offset>°` - Yaw offset calculated at connection

## Recording Flow

### Start/Stop
- `🔴 Recording started` - Recording initiated
- `⏹️ Recording stopped: <duration>s, <left>L/<right>R samples (~<hz> Hz)` - Recording stopped with metrics

### Data Collection
- `📊 Recording: <left>L/<right>R samples` - Sample count at recording stop

## Analysis Flow

### Segmentation
- `📊 Segmentation: <left>L/<right>R samples` - Starting analysis
- `📊 Detected <count> peaks` - Yaw peaks (turn points) detected
- `📊 Created <count> turns` - Final turn segments created

### Results
- `📊 Analysis: <count> turns detected` - Turn detection complete
- `📊 Results ready: <count> turns` - All metrics computed and ready for display

## Disconnect Handling

### Detection
- `⚠️ Left sensor timeout (<seconds>s)` - Left sensor data timeout
- `⚠️ Right sensor timeout (<seconds>s)` - Right sensor data timeout
- `⚠️ Left sensor disconnected` - Left stream closed
- `⚠️ Right sensor disconnected` - Right stream closed
- `⚠️ Left sensor error: <error>` - Left stream error
- `⚠️ Right sensor error: <error>` - Right stream error

### Recovery
- `⚠️ Disconnect: <message>` - Disconnect handler invoked
- `⚠️ Idle disconnect` - Disconnect while not recording
- `⚠️ Analysis aborted` - Analysis canceled due to disconnect
- `📊 Reconnected (idle)` - Sensors reconnected after idle disconnect
- `📊 Reconnected (recording reset)` - Sensors reconnected, recording reset
- `⚠️ Sensors disconnected, showing reconnect` - Reconnect modal displayed
- `🔌 Disconnecting <count> devices` - Disconnecting all devices

## Error Conditions

### BLE Errors
- `❌ Subscription error: <error>` - BLE characteristic subscription failed
- `❌ Subscribe error: <error>` - Exception during subscription
- `Subscription closed` - BLE subscription stream closed
- `[<deviceId>] MTU request failed: <error>` - MTU negotiation failed
- `[<deviceId>] Service discovery error: <error>` - Service discovery failed

### Navigation Errors
- `⚠️ jumpToPage error: <error>` - PageView navigation error

## Typical Run Sequence

```
Connection:
  🔍 Starting new scan
  ✓ Connected, waiting for data
  ✓ Left data OK
  ✓ Right data OK
  🎯 Yaw calibration: right=45.2° left=43.8° offset=1.4°
  ✓ Both sensors ready

Recording:
  🔴 Recording started
  (user skis...)
  ⏹️ Recording stopped: 62s, 6200L/6198R samples (~100.0 Hz)

Analysis:
  📊 Recording: 6200L/6198R samples
  📊 Segmentation: 6200L/6198R samples
  📊 Detected 26 peaks
  📊 Created 12 turns
  📊 Analysis: 12 turns detected
  📊 Results ready: 12 turns
```

## Benefits

- **Concise**: Each log line contains key metrics without verbose details
- **Scannable**: Emoji prefixes make it easy to spot different event types
- **Informative**: Shows data flow, sample counts, timing, and errors
- **Non-intrusive**: Only appears in debug mode, minimal console space
