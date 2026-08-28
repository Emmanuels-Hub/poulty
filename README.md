# Smart Poultry — IoT Environmental Monitoring & Control

Cross-platform Flutter application for monitoring and controlling poultry farm environmental systems via ESP32 hardware.

## Features

- **Authentication & RBAC** — Up to 3 administrators with full control; additional view-only users
- **Real-time dashboard** — Temperature, humidity, ammonia, light/day-night, feed, water, battery, actuators, and growth stage
- **Operating modes** — Automatic, manual, simulation, and hybrid
- **Manual actuator control** — Confirmation prompts with automatic timeout restoration
- **Diagnostics** — Actuator testing and sensor value simulation without hardware
- **Analytics** — Historical charts for all monitored parameters
- **Notifications** — Critical alerts with repeat intervals; auto-clear when conditions normalize
- **ESP32-CAM** — On-demand snapshot capture (no continuous streaming)
- **Settings** — Thresholds, notification intervals, lighting schedules, stage parameters
- **Offline support** — Local caching, command queueing, and sync on reconnect
- **Extensible** — Species support (broiler, layer, turkey) and modular sensor/actuator architecture

## Getting Started

### Prerequisites

- Flutter SDK 3.11+
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
│   ├── diagnostics/    # Testing & simulation
│   ├── camera/         # ESP32-CAM snapshots
│   ├── settings/       # Configuration
│   ├── users/          # User management (admin)
│   └── devices/        # Device management (admin)
├── routes/             # GetX routing
└── widgets/            # Shared UI components
```

## ESP32 Integration

The app communicates with ESP32 over HTTP REST. Configure device endpoints in **Device Management**:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/status` | GET | Connection health check |
| `/api/telemetry` | GET | Full sensor/actuator snapshot |
| `/api/mode` | POST | Set operating mode |
| `/api/stage` | POST | Set poultry growth stage |
| `/api/actuators/{type}` | POST | Control actuator |
| `/api/sensors/source` | POST | Set live/simulated per sensor |
| `/api/settings` | PUT | Push threshold configuration |
| `/capture` | GET | ESP32-CAM JPEG snapshot |

### Telemetry JSON Schema

```json
{
  "timestamp": "2026-07-12T14:30:00.000Z",
  "temperatureC": 31.5,
  "humidityPercent": 62.0,
  "ammoniaPpm": 12.0,
  "isDaytime": true,
  "ambientLightLux": 450.0,
  "feedLevelPercent": 78.0,
  "waterLevelPercent": 85.0,
  "batteryPercent": 92.0,
  "operatingMode": "automatic",
  "poultryStage": "starter",
  "actuators": [
    {"type": "ventilationFan", "isOn": false, "isManualOverride": false, "hasFailure": false},
    {"type": "heatLamp", "isOn": true, "isManualOverride": false, "hasFailure": false},
    {"type": "lighting", "isOn": true, "isManualOverride": false, "hasFailure": false}
  ],
  "sensorSources": {"temperature": "live", "humidity": "live"},
  "uptimeSeconds": 86400,
  "wifiRssi": -55,
  "deviceId": "esp32-main"
}
```

### Development Without Hardware

Enable **Simulation mode** in Settings to run the full UI and control logic with generated data. This is enabled by default on first launch.

## State Management & Storage

- **GetX** — Controllers, reactive UI, routing, dependency injection
- **Hive** — Local cache for telemetry, events, notifications, command queue
- **flutter_secure_storage** — Encrypted session tokens

## License

Private project — not published to pub.dev.
