# Disconnect Handling - Manual Reconnect Only

## Overview

The app now requires **manual reconnection** after any sensor disconnect. Yaw calibration is performed at pairing time, so skis must be parallel when connecting. If sensors disconnect, calibration is lost and must be redone.

## Behavior

### When Disconnect Occurs

**1. On Recording or Pre-Recording Screen:**
- Page is replaced with error message: "Sensors disconnected. Reconnect to continue."
- Shows **Reconnect** button only
- No automatic reconnection

**2. On Results Screen:**
- Temporary error page is added to the right (preserves existing results)
- Shows error message: "Sensors disconnected. Reconnect to continue."
- Shows **Reconnect** button only
- User can swipe left to view previous results
- Error page is temporary and will be removed after reconnection

### After Manual Reconnect

**User presses Reconnect button:**
- Opens connection page (no close button - must connect to proceed)
- User pairs sensors with skis **parallel** (for yaw calibration)
- After successful connection:

**If was on Recording/Pre-Recording:**
- Error is replaced with: "Sensors reconnected. Yaw calibration was reset."
- Shows **Start Another Run** button
- Previous recording session is lost (as calibration changed)

**If was on Results:**
- Temporary error page is automatically removed
- User is returned to their results screen
- Results remain intact

## Key Changes

### No Auto-Reconnect
- Removed all automatic reconnection logic
- Removed `onSensorsReconnected` callbacks
- Removed `_needsResubscribeOnReconnect` flag
- Removed `_resetToRecording` method

### Manual Flow
1. Disconnect detected → Show error with Reconnect button
2. User presses Reconnect → Opens connection page
3. User connects sensors (parallel skis) → Yaw calibration performed
4. App handles post-reconnect state based on where disconnect occurred

### Error States

**showReconnectButton:**
- Displayed immediately after disconnect
- Calls `widget.onManualReconnect()` when pressed

**startAnotherRun:**
- Displayed after reconnect from recording/pre-recording state
- Calls `widget.onRecordAgain()` when pressed
- Acknowledges that calibration was reset

## User Experience

1. **Connect sensors with skis parallel** → Yaw calibration happens
2. **Start recording** → Capture run data
3. **If disconnect during/before recording:**
   - See "Sensors disconnected" error
   - Press Reconnect button
   - Pair sensors again (parallel skis)
   - See "Yaw calibration was reset" message
   - Press "Start Another Run"
4. **If disconnect while viewing results:**
   - Temporary error page appears to the right
   - Press Reconnect button
   - Pair sensors again (parallel skis)
   - Error page auto-removes, back to results

## Technical Details

### AppController
- `_onSensorsDisconnected()`: Determines context and shows appropriate error
- `_onManualReconnectPressed()`: Opens connection page, handles post-reconnect logic
- `_addTemporaryDisconnectErrorPage()`: Adds error page to right of results
- `_removeTemporaryErrorPages()`: Cleans up temporary error pages after reconnect

### RunPage
- `showDisconnectErrorWithReconnectButton()`: Shows initial disconnect error
- `showPostReconnectErrorStartNewRun()`: Shows post-reconnect state for recording pages
- `hasDisconnectError`: Helper to identify disconnect error pages
- `isSummaryWithValidResults`: Helper to identify results pages

### Connection Page
- When opened via Reconnect button: `showCloseButton: false`
- User must successfully connect to proceed
- Yaw calibration performed automatically upon connection
