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
- **Alerts & push notifications** — Delivered to the phone's notification shade even when the app is closed, with severity-tiered priority; they auto-clear when conditions normalise
- **Data logging** — Readings averaged and logged once a minute (~24 h retained), with per-parameter statistics and CSV export
- **Simulation** — Inject sensor readings and watch the real actuators respond, under firmware-enforced safety limits
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

Firmware lives in [`esp/Smart_Poultry/Smart_Poultry.ino`](esp/Smart_Poultry/Smart_Poultry.ino) and targets an ESP32-WROOM-32.

| Component | Pin(s) | Provides |
|---|---|---|
| DHT22 | GPIO 4 | temperature, humidity |
| MQ-135 gas sensor | GPIO 34 (ADC) | air purity |
| HX711 + load cell | GPIO 21 / 22 | feed level |
| HX711 + load cell | GPIO 23 / 27 | water level |
| Ventilation fan | GPIO 25 | cooling, air exchange |
| Heat lamp | GPIO 26 | brooding heat |

Arduino libraries: **DHT sensor library** (Adafruit) and **HX711** (bogde). BLE
comes from the ESP32 Arduino core, so there is nothing extra to install.

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
  "temperatureC": 33.2,
  "humidityPercent": 62.0,
  "airPurityPercent": 88.0,
  "feedLevelPercent": 78.0,
  "waterLevelPercent": 85.0,
  "operatingMode": "automatic",
  "poultryStage": "starter",
  "simulationMode": false,
  "simulatedMask": 0,
  "actuators": [
    {"type": "ventilationFan", "isOn": false, "isManualOverride": false, "hasFailure": false},
    {"type": "heatLamp", "isOn": true, "isManualOverride": false, "hasFailure": false}
  ],
  "deviceId": "SmartPoultry-Coop"
}
```

The firmware also sends `temperatureCategory`, `humidityCategory`,
`airPurityCategory`, `feedStatus`, `waterStatus`, `feedRefillNeeded` and
`waterRefillNeeded`. The app derives those itself from the shared thresholds
and ignores them, so they are free to change without breaking anything.

`simulatedMask` is a bitmask of which sensors are currently being simulated:
bit 0 temperature, 1 humidity, 2 air purity, 3 feed, 4 water. The order is part
of the contract and is covered by `test/ble_contract_test.dart`.

Every field is optional — a missing or unrecognised value falls back to a safe
default rather than dropping the frame. Two fields are deliberately absent:

- **`timestamp`** — the ESP32 has no RTC, so the app stamps each frame with the
  phone's clock on arrival.
- **`isDaytime`** — there is no light sensor on the board, so the app derives
  day/night from the phone clock (06:00–18:00) instead.

### Command frames (app → ESP32)

Newline-delimited JSON on the command characteristic.

| `cmd` | Payload | Effect |
|---|---|---|
| `setMode` | `{"mode":"automatic"\|"manual"}` | Switches control mode |
| `setStage` | `{"stage":"starter"}` | Acknowledged; starter is the only stage |
| `setActuator` | `{"actuator":"ventilationFan"\|"heatLamp","state":true,"timeoutMinutes":15}` | Manual override, reverts on timeout. Ignored unless in Manual mode |
| `setSimulation` | `{"enabled":true,"timeoutMinutes":10}` | Starts/stops a simulation session |
| `setSensor` | `{"sensor":"temperature","value":36.5}` or `{"sensor":"temperature","clear":true}` | Injects or releases one reading. Ignored unless simulation is active |
| `tareScale` | `{"scale":"feed"\|"water"}` | Records the current weight as the empty point and saves it

Sensor names are `temperature`, `humidity`, `airPurity`, `feedLevel`, `waterLevel`
— matching the app's `SensorType` and the firmware's `SIM_*` bit order.

## Load cell calibration

Both level readings depend on a **zero point** — the reading that counts as an
empty container. This is set once per container from
**Settings → Load Cell Calibration**, with the container actually empty. The
controller saves the offset to NVS and restores it on every boot.

Do not zero a container that has anything in it: the contents would be treated
as "empty" and every level reading would be wrong until you redo it. The app
confirms before sending the command, and the dashboard reports
`feedTared` / `waterTared` so an uncalibrated scale is visible rather than
silently reading 0%.

You also need a **calibration factor** (`feedCalibrationFactor` /
`waterCalibrationFactor` in the sketch) to convert raw counts to kilograms:
zero the scale, place a known weight, and divide the raw reading by the real
weight in kg.

## Simulation

Simulation injects sensor readings so the **real relays respond**, which is how
the system is demonstrated without waiting for the coop to actually heat up or
foul. Open it from **Settings → Simulation**.

With no controller connected the same screen drives the on-screen demo instead,
so the flow can still be shown without hardware.

### How it is kept safe

The firmware owns every rule — the app cannot talk it out of any of them:

1. **Real sensors keep running.** Simulation only replaces the numbers handed
   to the control logic. The controller never stops measuring.
2. **A real over-temperature always wins.** At or above the critical high limit
   the session is cancelled, the fan forced on and the heat lamp off. This runs
   in *every* mode, including Manual, and always from the real reading.
3. **Sessions expire.** They stop on their own, and cannot be extended past
   `SIM_MAX_MINUTES` from when they started.
4. **Losing the link ends it.** A BLE disconnect stops simulation immediately.
5. **Injected values are clamped** to physically plausible ranges.
6. **It is visible.** A banner sits across every screen while a session runs,
   and each simulated reading is flagged on the dashboard.

One deliberate asymmetry: a real **critically low** temperature is reported but
not enforced while a session is running. It is true of any bench sitting at room
temperature, so enforcing it would pin the heat lamp on and make simulation
impossible to demonstrate. A critically *high* temperature can damage equipment
and is never suppressed.

> Injected readings only move the relays while the system is in **Automatic**
> mode — in Manual the controller is waiting for you, not for the sensors.

### Air purity from the MQ-135

The gas sensor reports a raw 12-bit ADC value where **higher means dirtier air**,
while the app expects `airPurityPercent` where **higher means cleaner**. The
firmware inverts it against two calibration points:

```c
#define GAS_CLEAN_ADC 400.0    // reading in known-good air   -> 100%
#define GAS_FOUL_ADC  3200.0   // reading in badly fouled air ->   0%

float purity = 100.0 - ((raw - GAS_CLEAN_ADC) / (GAS_FOUL_ADC - GAS_CLEAN_ADC)) * 100.0;
```

**Calibrate these to your own coop**: watch the Serial monitor (the status block
prints the raw ADC alongside the purity) in fresh air and in a dirty pen, then
set the two constants accordingly. The MQ-135 heater also needs ~20 s to settle
after power-up; readings before that are not trustworthy.

### Shared thresholds

The comfort bands live in **both** `esp/Smart_Poultry/Smart_Poultry.ino` and `lib/core/constants/app_constants.dart`
and must be kept identical — the firmware drives the relays from its copy, the
app raises alerts from its own.

| Reading | Warning band | Critical band |
|---|---|---|
| Temperature | 32–35 °C | below 30 / above 37 °C |
| Humidity | 50–70 % | below 40 / above 80 % |
| Air purity | at or above 60 % | below 40 % |
| Feed level | at or above 20 % | — |
| Water level | at or above 20 % | — |

Automatic control uses a 0.5 °C / 3 % deadband so the relays do not chatter, and
the heat and fan bands do not overlap, so the two actuators never fight.

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
