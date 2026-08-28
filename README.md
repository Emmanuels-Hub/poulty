# Smart Poultry — IoT Environmental Monitoring & Control

Cross-platform Flutter application for monitoring and controlling poultry farm environmental systems via an ESP32 controller over Bluetooth Low Energy.

## Features

- **Authentication & RBAC** — Up to 3 administrators with full control; additional view-only users
- **Real-time dashboard** — Temperature, humidity, air purity, day/night, feed and water levels, and actuators
- **BLE connectivity** — Scan for and pair with the ESP32 controller; telemetry streams over a notify characteristic
- **Operating modes** — Automatic and manual
- **Manual actuator control** — Disabled until Manual mode is activated in Settings, then confirmation-prompted with an automatic timeout
- **Light & dark theme** — Follows the system, or pin it to light/dark; the choice is persisted
- **Analytics** — Approximated trend charts (readings are bucket-averaged, so values are indicative rather than exact)
- **Notifications** — Critical alerts with repeat intervals; auto-clear when conditions normalize
- **Live feed** — Continuous MJPEG video from the ESP32-CAM
- **Production stage** — Starter only
- **Offline support** — Local caching, plus optional generated demo data while no controller is linked

## Getting Started

### Prerequisites

- Flutter SDK 3.10+
- Android Studio / Xcode for mobile builds

### Install & Run

```bash
cd poulty
flutter pub get
flutter run
```

### Demo Accounts

| Username | Password   | Role        |
|----------|------------|-------------|
| admin    | admin123   | Administrator |
| admin2   | admin123   | Administrator |
| viewer   | viewer123  | View Only     |

## Project Structure

```
lib/
├── app/bindings/       # GetX dependency injection
├── core/
│   ├── constants/      # Enums, app constants
│   ├── services/       # Auth, ESP32 API, alerts, storage, simulation
│   ├── theme/          # Material 3 theme
│   └── utils/          # Label helpers
├── data/models/        # User, device, telemetry, settings models
├── modules/
│   ├── auth/           # Login
│   ├── shell/          # Main navigation shell
│   ├── dashboard/      # Home dashboard
│   ├── analytics/      # Historical charts
│   ├── notifications/  # Alert center
│   ├── livefeed/       # ESP32-CAM live video
│   ├── settings/       # Configuration
│   ├── users/          # User management (admin)
│   └── devices/        # Device management (admin)
├── routes/             # GetX routing
└── widgets/            # Shared UI components
```

## ESP32 Integration (Bluetooth Low Energy)

The app talks to the controller over BLE using a Nordic-UART style service.
Pair from **Settings → ESP32 Connection**; the app lists devices advertising the
service UUID or a name containing `SmartPoultry`.

| Role | UUID |
|------|------|
| Service | `6e400001-b5a3-f393-e0a9-e50e24dcca9e` |
| Telemetry (notify → app) | `6e400003-b5a3-f393-e0a9-e50e24dcca9e` |
| Command (write ← app) | `6e400002-b5a3-f393-e0a9-e50e24dcca9e` |

Frames are newline-delimited JSON, so a payload larger than one MTU can be split
across notifications.

### Telemetry frame (ESP32 → app)

```json
{
  "timestamp": "2026-08-28T14:30:00.000Z",
  "temperatureC": 33.2,
  "humidityPercent": 62.0,
  "airPurityPercent": 88.0,
  "isDaytime": true,
  "feedLevelPercent": 78.0,
  "waterLevelPercent": 85.0,
  "operatingMode": "automatic",
  "poultryStage": "starter",
  "actuators": [
    {"type": "ventilationFan", "isOn": false, "isManualOverride": false, "hasFailure": false},
    {"type": "heatLamp", "isOn": true, "isManualOverride": false, "hasFailure": false}
  ],
  "deviceId": "esp32-main"
}
```

Every field is optional — a missing or unrecognised value falls back to a safe
default rather than dropping the frame.

### Command frames (app → ESP32)

```json
{"cmd": "setMode",     "mode": "automatic"}
{"cmd": "setStage",    "stage": "starter"}
{"cmd": "setActuator", "actuator": "ventilationFan", "state": true, "timeoutMinutes": 15}
```

### Air purity from the MQ-135

The gas sensor reports a raw 12-bit ADC value where **higher means dirtier air**,
while the app expects `airPurityPercent` where **higher means cleaner**. The
firmware should invert and scale it, e.g.:

```c
float airPurityPercent = 100.0 - (rawAdc / 4095.0) * 100.0;
```

Using `GAS_NORMAL_LIMIT` (1500) as the comfort ceiling puts normal air at roughly
63% purity or better, which sits above the app's 60% alert threshold.

### Live camera feed

Video is separate from BLE: the ESP32-CAM serves an MJPEG stream over Wi-Fi. Set
its URL (e.g. `http://192.168.1.100:81/stream`) on the **Live Feed** tab or in
Device Management.

### Development Without Hardware

**Demo data when disconnected** is on by default in Settings, so the full UI and
control logic run on generated readings until a controller is paired.

## State Management & Storage

- **GetX** — Controllers, reactive UI, routing, dependency injection
- **Hive** — Local cache for telemetry, history, events, and notifications
- **flutter_secure_storage** — Encrypted session tokens

## License

Private project — not published to pub.dev.
