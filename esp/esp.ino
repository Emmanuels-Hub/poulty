// =====================================================
//            SMART POULTRY CONTROL SYSTEM
//                  ESP32-WROOM-32
// =====================================================
//
// Sensors
//   DHT22   - temperature + humidity
//   MQ-135  - gas / air purity (raw ADC, inverted to a purity %)
//   HX711   - feed level   (load cell)
//   HX711   - water level  (load cell)
//
// Actuators
//   Ventilation fan
//   Heat lamp
//
// The companion Flutter app connects over BLE using a Nordic-UART style
// service. Telemetry is pushed as newline-delimited JSON on the notify
// characteristic; commands arrive as newline-delimited JSON on the write
// characteristic.
//
// Libraries: DHT sensor library (Adafruit), HX711 (bogde).
// BLE comes from the ESP32 Arduino core - no extra install needed.
// =====================================================

#include <DHT.h>
#include "HX711.h"

#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>


// =====================================================
//                  PIN DEFINITIONS
// =====================================================

// ---------------- DHT22 ----------------
#define DHT_PIN 4
#define DHT_TYPE DHT22

// ---------------- MQ-135 ----------------
#define MQ135_PIN 34

// ---------------- FEED HX711 ----------------
#define FEED_HX711_DT 16
#define FEED_HX711_SCK 17

// ---------------- WATER HX711 ----------------
#define WATER_HX711_DT 18
#define WATER_HX711_SCK 19

// ---------------- ACTUATORS ----------------
#define FAN_PIN 25
#define HEAT_LAMP_PIN 26

// Set to 1 if your relay board is active-LOW (most blue relay modules are).
#define RELAY_ACTIVE_LOW 0


// =====================================================
//                  BLE IDENTIFIERS
// =====================================================
//
// These must match AppConstants in the Flutter app.
//

#define BLE_DEVICE_NAME "SmartPoultry-Coop"
#define BLE_SERVICE_UUID "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define BLE_COMMAND_CHAR_UUID "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
#define BLE_TELEMETRY_CHAR_UUID "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

// A telemetry frame is far larger than one BLE packet, so it is split across
// notifications. 20 bytes is what the default 23-byte MTU allows, and is safe
// on every phone. The app reassembles the frame on the newline terminator.
#define BLE_CHUNK_SIZE 20
#define BLE_CHUNK_DELAY_MS 8


// =====================================================
//              ENVIRONMENTAL THRESHOLDS
// =====================================================
//
// Starter stage (brooding). These mirror the app's constants exactly - if you
// change one side, change the other.
//
// Comfort band sits between the WARNING limits; crossing a CRITICAL limit is
// what the app escalates on.
//

#define TEMP_WARNING_LOW 32.0
#define TEMP_WARNING_HIGH 35.0
#define TEMP_CRITICAL_LOW 30.0
#define TEMP_CRITICAL_HIGH 37.0

#define HUM_WARNING_LOW 50.0
#define HUM_WARNING_HIGH 70.0
#define HUM_CRITICAL_LOW 40.0
#define HUM_CRITICAL_HIGH 80.0

// Air purity is a percentage: 100% is clean air, 0% is saturated.
#define AIR_PURITY_WARNING_LOW 60.0
#define AIR_PURITY_CRITICAL_LOW 40.0

#define FEED_WARNING_LOW 20.0
#define WATER_WARNING_LOW 20.0

// Deadband so the relays do not chatter around a threshold.
#define TEMP_HYSTERESIS 0.5
#define PURITY_HYSTERESIS 3.0


// =====================================================
//                 MQ-135 CALIBRATION
// =====================================================
//
// The MQ-135 returns a raw 12-bit ADC value where HIGHER means dirtier air.
// The app wants the opposite, so the reading is inverted into a purity %.
//
// GAS_CLEAN_ADC   - reading in known-good air  -> 100% purity
// GAS_FOUL_ADC    - reading in badly fouled air ->   0% purity
//
// Sample your own coop and adjust: run the sketch, watch the Serial output,
// and note the raw value in fresh air versus a dirty pen.
//

#define GAS_CLEAN_ADC 400.0
#define GAS_FOUL_ADC 3200.0

// The MQ-135 heater needs time to stabilise after power-up.
#define GAS_WARMUP_MS 20000UL


// =====================================================
//             LOAD CELL CALIBRATION
// =====================================================
//
// Replace these with your own calibration factors.
//
// To calibrate: set the factor to 1.0, upload, tare with the container empty,
// place a known weight, then divide the raw reading by the real weight in kg.
//

float feedCalibrationFactor = 420.0;
float waterCalibrationFactor = 420.0;


// =====================================================
//              CONTAINER CAPACITIES
// =====================================================
//
// Weight (kg) of a full container, used to turn kg into a level percentage.
//

float feedFullWeightKg = 1.0;
float waterFullWeightKg = 1.0;


// =====================================================
//                   TIMING
// =====================================================

// The DHT22 cannot be polled faster than once every 2 seconds.
#define SENSOR_INTERVAL_MS 2000UL
#define TELEMETRY_INTERVAL_MS 3000UL
#define SERIAL_REPORT_INTERVAL_MS 10000UL


// =====================================================
//                  SENSOR OBJECTS
// =====================================================

DHT dht(DHT_PIN, DHT_TYPE);

HX711 feedScale;
HX711 waterScale;


// =====================================================
//                   SYSTEM STATE
// =====================================================

enum OperatingMode { MODE_AUTOMATIC, MODE_MANUAL };

OperatingMode operatingMode = MODE_AUTOMATIC;

// Last known-good sensor values, reused when a read fails so the app never
// sees a fabricated zero.
float temperatureC = 0.0;
float humidityPercent = 0.0;
float airPurityPercent = 100.0;
float feedLevelPercent = 0.0;
float waterLevelPercent = 0.0;

bool haveTemperature = false;
bool haveHumidity = false;

bool fanOn = false;
bool heatLampOn = false;

// A manual command pins an actuator until its timeout expires, after which
// automatic control resumes on its own.
bool fanManual = false;
bool heatLampManual = false;
unsigned long fanManualUntil = 0;
unsigned long heatLampManualUntil = 0;

unsigned long lastSensorRead = 0;
unsigned long lastTelemetrySend = 0;
unsigned long lastSerialReport = 0;
unsigned long bootMillis = 0;

BLEServer *bleServer = nullptr;
BLECharacteristic *telemetryCharacteristic = nullptr;
bool deviceConnected = false;
bool wasConnected = false;

String commandBuffer = "";


// =====================================================
//                  SMALL HELPERS
// =====================================================

float clampFloat(float value, float low, float high)
{
  if (value < low) return low;
  if (value > high) return high;
  return value;
}

void writeRelay(int pin, bool on)
{
#if RELAY_ACTIVE_LOW
  digitalWrite(pin, on ? LOW : HIGH);
#else
  digitalWrite(pin, on ? HIGH : LOW);
#endif
}


// =====================================================
//                   JSON PARSING
// =====================================================
//
// The command set is tiny and fixed-shape, so a full JSON library would be
// overkill. This pulls the raw text of a value out by key.
//

bool jsonFindRaw(const String &src, const char *key, String &out)
{
  String needle = String("\"") + key + "\"";

  int keyAt = src.indexOf(needle);
  if (keyAt < 0) return false;

  int colon = src.indexOf(':', keyAt + needle.length());
  if (colon < 0) return false;

  int i = colon + 1;
  while (i < (int)src.length() && isspace((unsigned char)src[i])) i++;
  if (i >= (int)src.length()) return false;

  int end;
  if (src[i] == '"')
  {
    i++;
    end = src.indexOf('"', i);
    if (end < 0) return false;
  }
  else
  {
    end = i;
    while (end < (int)src.length() && src[end] != ',' && src[end] != '}') end++;
  }

  out = src.substring(i, end);
  out.trim();
  return true;
}

bool jsonGetString(const String &src, const char *key, String &out)
{
  return jsonFindRaw(src, key, out);
}

bool jsonGetBool(const String &src, const char *key, bool &out)
{
  String raw;
  if (!jsonFindRaw(src, key, raw)) return false;
  raw.toLowerCase();
  out = (raw == "true" || raw == "1");
  return true;
}

bool jsonGetLong(const String &src, const char *key, long &out)
{
  String raw;
  if (!jsonFindRaw(src, key, raw)) return false;
  out = raw.toInt();
  return true;
}


// =====================================================
//                  SENSOR READING
// =====================================================

void readTemperatureAndHumidity()
{
  float t = dht.readTemperature();
  float h = dht.readHumidity();

  if (isnan(t))
  {
    Serial.println("WARN: DHT22 temperature read failed; keeping last value.");
  }
  else
  {
    temperatureC = t;
    haveTemperature = true;
  }

  if (isnan(h))
  {
    Serial.println("WARN: DHT22 humidity read failed; keeping last value.");
  }
  else
  {
    humidityPercent = h;
    haveHumidity = true;
  }
}

void readAirPurity()
{
  // Average a few samples: the MQ-135 is noisy.
  long total = 0;
  const int samples = 8;
  for (int i = 0; i < samples; i++)
  {
    total += analogRead(MQ135_PIN);
    delay(2);
  }
  float raw = (float)total / samples;

  // Invert: a high ADC value means dirty air, which is a low purity.
  float span = GAS_FOUL_ADC - GAS_CLEAN_ADC;
  float purity = 100.0 - ((raw - GAS_CLEAN_ADC) / span) * 100.0;

  airPurityPercent = clampFloat(purity, 0.0, 100.0);
}

float readLevelPercent(HX711 &scale, float fullWeightKg, float lastValue,
                       const char *label)
{
  if (!scale.is_ready())
  {
    Serial.print("WARN: ");
    Serial.print(label);
    Serial.println(" load cell not ready; keeping last value.");
    return lastValue;
  }

  float weight = scale.get_units(5);
  if (weight < 0) weight = 0;

  if (fullWeightKg <= 0) return lastValue;

  return clampFloat((weight / fullWeightKg) * 100.0, 0.0, 100.0);
}

void readSensors()
{
  readTemperatureAndHumidity();
  readAirPurity();

  feedLevelPercent =
      readLevelPercent(feedScale, feedFullWeightKg, feedLevelPercent, "Feed");
  waterLevelPercent = readLevelPercent(waterScale, waterFullWeightKg,
                                       waterLevelPercent, "Water");
}


// =====================================================
//                 ACTUATOR CONTROL
// =====================================================

void applyAutomaticControl()
{
  // Ventilation: extract heat, or clear the air when the gas sensor is unhappy.
  if (!fanManual)
  {
    if (temperatureC > TEMP_WARNING_HIGH ||
        airPurityPercent < AIR_PURITY_WARNING_LOW)
    {
      fanOn = true;
    }
    else if (temperatureC < (TEMP_WARNING_HIGH - TEMP_HYSTERESIS) &&
             airPurityPercent > (AIR_PURITY_WARNING_LOW + PURITY_HYSTERESIS))
    {
      fanOn = false;
    }
  }

  // Brooding heat. The bands do not overlap, so the lamp and fan never fight.
  if (!heatLampManual)
  {
    if (temperatureC < TEMP_WARNING_LOW)
    {
      heatLampOn = true;
    }
    else if (temperatureC > (TEMP_WARNING_LOW + TEMP_HYSTERESIS))
    {
      heatLampOn = false;
    }
  }
}

void expireManualOverrides()
{
  unsigned long now = millis();

  if (fanManual && (long)(now - fanManualUntil) >= 0)
  {
    fanManual = false;
    Serial.println("Fan manual override expired; back to automatic.");
  }

  if (heatLampManual && (long)(now - heatLampManualUntil) >= 0)
  {
    heatLampManual = false;
    Serial.println("Heat lamp manual override expired; back to automatic.");
  }
}

void driveActuators()
{
  writeRelay(FAN_PIN, fanOn);
  writeRelay(HEAT_LAMP_PIN, heatLampOn);
}


// =====================================================
//                 TELEMETRY FRAME
// =====================================================

String buildTelemetryJson()
{
  char buffer[420];

  // No timestamp is sent: the ESP32 has no RTC, so the app stamps each frame
  // with the phone's clock on arrival.
  snprintf(
      buffer, sizeof(buffer),
      "{\"temperatureC\":%.1f,"
      "\"humidityPercent\":%.1f,"
      "\"airPurityPercent\":%.1f,"
      "\"feedLevelPercent\":%.1f,"
      "\"waterLevelPercent\":%.1f,"
      "\"operatingMode\":\"%s\","
      "\"poultryStage\":\"starter\","
      "\"actuators\":["
      "{\"type\":\"ventilationFan\",\"isOn\":%s,\"isManualOverride\":%s,"
      "\"hasFailure\":false},"
      "{\"type\":\"heatLamp\",\"isOn\":%s,\"isManualOverride\":%s,"
      "\"hasFailure\":false}"
      "],"
      "\"deviceId\":\"%s\"}\n",
      temperatureC, humidityPercent, airPurityPercent, feedLevelPercent,
      waterLevelPercent,
      operatingMode == MODE_MANUAL ? "manual" : "automatic",
      fanOn ? "true" : "false", fanManual ? "true" : "false",
      heatLampOn ? "true" : "false", heatLampManual ? "true" : "false",
      BLE_DEVICE_NAME);

  return String(buffer);
}

void sendTelemetry()
{
  if (!deviceConnected || telemetryCharacteristic == nullptr) return;

  String frame = buildTelemetryJson();
  int length = frame.length();

  for (int offset = 0; offset < length; offset += BLE_CHUNK_SIZE)
  {
    int size = min((int)BLE_CHUNK_SIZE, length - offset);
    telemetryCharacteristic->setValue(
        (uint8_t *)(frame.c_str() + offset), size);
    telemetryCharacteristic->notify();
    delay(BLE_CHUNK_DELAY_MS);
  }
}


// =====================================================
//                 COMMAND HANDLING
// =====================================================

void handleSetMode(const String &json)
{
  String mode;
  if (!jsonGetString(json, "mode", mode)) return;

  if (mode == "manual")
  {
    operatingMode = MODE_MANUAL;
    Serial.println("Operating mode -> MANUAL");
  }
  else
  {
    operatingMode = MODE_AUTOMATIC;

    // Leaving manual hands both actuators straight back to the controller.
    fanManual = false;
    heatLampManual = false;
    Serial.println("Operating mode -> AUTOMATIC");
  }
}

void handleSetStage(const String &json)
{
  String stage;
  if (!jsonGetString(json, "stage", stage)) return;

  // Starter is the only stage this system runs; acknowledge and move on.
  Serial.print("Production stage requested: ");
  Serial.println(stage);
}

void handleSetActuator(const String &json)
{
  String actuator;
  bool state = false;

  if (!jsonGetString(json, "actuator", actuator)) return;
  if (!jsonGetBool(json, "state", state)) return;

  if (operatingMode != MODE_MANUAL)
  {
    Serial.println("Ignoring actuator command: system is in AUTOMATIC mode.");
    return;
  }

  long timeoutMinutes = 15;
  jsonGetLong(json, "timeoutMinutes", timeoutMinutes);
  if (timeoutMinutes <= 0) timeoutMinutes = 15;

  unsigned long until = millis() + (unsigned long)timeoutMinutes * 60000UL;

  if (actuator == "ventilationFan")
  {
    fanOn = state;
    fanManual = true;
    fanManualUntil = until;
    Serial.print("Fan manually set ");
    Serial.println(state ? "ON" : "OFF");
  }
  else if (actuator == "heatLamp")
  {
    heatLampOn = state;
    heatLampManual = true;
    heatLampManualUntil = until;
    Serial.print("Heat lamp manually set ");
    Serial.println(state ? "ON" : "OFF");
  }
  else
  {
    Serial.print("Unknown actuator: ");
    Serial.println(actuator);
    return;
  }

  driveActuators();
}

void handleCommand(const String &json)
{
  if (json.length() == 0) return;

  String command;
  if (!jsonGetString(json, "cmd", command))
  {
    Serial.println("Command frame had no \"cmd\" field; ignored.");
    return;
  }

  if (command == "setMode")
  {
    handleSetMode(json);
  }
  else if (command == "setStage")
  {
    handleSetStage(json);
  }
  else if (command == "setActuator")
  {
    handleSetActuator(json);
  }
  else
  {
    Serial.print("Unknown command: ");
    Serial.println(command);
  }
}


// =====================================================
//                  BLE CALLBACKS
// =====================================================

class ServerCallbacks : public BLEServerCallbacks
{
  void onConnect(BLEServer *server) override
  {
    deviceConnected = true;
    Serial.println("BLE: app connected.");
  }

  void onDisconnect(BLEServer *server) override
  {
    deviceConnected = false;
    Serial.println("BLE: app disconnected.");
  }
};

class CommandCallbacks : public BLECharacteristicCallbacks
{
  void onWrite(BLECharacteristic *characteristic) override
  {
    uint8_t *data = characteristic->getData();
    size_t length = characteristic->getLength();
    if (data == nullptr || length == 0) return;

    for (size_t i = 0; i < length; i++)
    {
      commandBuffer += (char)data[i];
    }

    // Commands are newline-delimited and may span several writes.
    int newline;
    while ((newline = commandBuffer.indexOf('\n')) >= 0)
    {
      String line = commandBuffer.substring(0, newline);
      commandBuffer = commandBuffer.substring(newline + 1);
      line.trim();
      handleCommand(line);
    }

    // A frame with no trailing newline is still valid if it closes cleanly.
    String pending = commandBuffer;
    pending.trim();
    if (pending.startsWith("{") && pending.endsWith("}"))
    {
      commandBuffer = "";
      handleCommand(pending);
    }

    if (commandBuffer.length() > 512) commandBuffer = "";
  }
};


// =====================================================
//                    BLE SETUP
// =====================================================

void setupBle()
{
  BLEDevice::init(BLE_DEVICE_NAME);

  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new ServerCallbacks());

  BLEService *service = bleServer->createService(BLE_SERVICE_UUID);

  telemetryCharacteristic = service->createCharacteristic(
      BLE_TELEMETRY_CHAR_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  telemetryCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic *commandCharacteristic = service->createCharacteristic(
      BLE_COMMAND_CHAR_UUID,
      BLECharacteristic::PROPERTY_WRITE |
          BLECharacteristic::PROPERTY_WRITE_NR);
  commandCharacteristic->setCallbacks(new CommandCallbacks());

  service->start();

  // Advertise the service UUID so the app can filter for it by more than name.
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.print("BLE advertising as \"");
  Serial.print(BLE_DEVICE_NAME);
  Serial.println("\".");
}


// =====================================================
//                       SETUP
// =====================================================

void setup()
{
  Serial.begin(115200);

  delay(1000);

  Serial.println();
  Serial.println("==============================================");
  Serial.println("       SMART POULTRY CONTROL SYSTEM");
  Serial.println("              ESP32-WROOM-32");
  Serial.println("==============================================");
  Serial.println();

  // DHT22
  dht.begin();

  // MQ-135
  pinMode(MQ135_PIN, INPUT);
  analogSetPinAttenuation(MQ135_PIN, ADC_11db);

  // Feed HX711
  feedScale.begin(FEED_HX711_DT, FEED_HX711_SCK);
  feedScale.set_scale(feedCalibrationFactor);
  feedScale.tare();

  // Water HX711
  waterScale.begin(WATER_HX711_DT, WATER_HX711_SCK);
  waterScale.set_scale(waterCalibrationFactor);
  waterScale.tare();

  // Actuators
  pinMode(FAN_PIN, OUTPUT);
  pinMode(HEAT_LAMP_PIN, OUTPUT);

  // Start safely with both OFF
  fanOn = false;
  heatLampOn = false;
  driveActuators();

  Serial.println("DHT22 initialized.");
  Serial.println("MQ-135 initialized.");
  Serial.println("Feed HX711 initialized.");
  Serial.println("Water HX711 initialized.");
  Serial.println("Fan initialized on GPIO 25.");
  Serial.println("Heat bulb initialized on GPIO 26.");

  setupBle();

  Serial.println();
  Serial.println("SYSTEM READY");
  Serial.println();

  bootMillis = millis();

  // Prime the readings so the first telemetry frame is not all zeros.
  readSensors();
}


// =====================================================
//                       MAIN LOOP
// =====================================================

void printStatus()
{
  Serial.println("---------------------------------------------");
  Serial.print("Mode        : ");
  Serial.println(operatingMode == MODE_MANUAL ? "MANUAL" : "AUTOMATIC");

  Serial.print("Temperature : ");
  if (haveTemperature)
  {
    Serial.print(temperatureC, 1);
    Serial.println(" C");
  }
  else
  {
    Serial.println("no reading yet");
  }

  Serial.print("Humidity    : ");
  if (haveHumidity)
  {
    Serial.print(humidityPercent, 1);
    Serial.println(" %");
  }
  else
  {
    Serial.println("no reading yet");
  }

  Serial.print("Air purity  : ");
  Serial.print(airPurityPercent, 1);
  Serial.print(" % (raw ADC ");
  Serial.print(analogRead(MQ135_PIN));
  Serial.println(")");

  Serial.print("Feed level  : ");
  Serial.print(feedLevelPercent, 1);
  Serial.println(" %");

  Serial.print("Water level : ");
  Serial.print(waterLevelPercent, 1);
  Serial.println(" %");

  Serial.print("Fan         : ");
  Serial.print(fanOn ? "ON" : "OFF");
  Serial.println(fanManual ? " (manual)" : "");

  Serial.print("Heat lamp   : ");
  Serial.print(heatLampOn ? "ON" : "OFF");
  Serial.println(heatLampManual ? " (manual)" : "");

  Serial.print("App         : ");
  Serial.println(deviceConnected ? "connected" : "not connected");

  if (millis() - bootMillis < GAS_WARMUP_MS)
  {
    Serial.println("NOTE: MQ-135 still warming up; purity is not reliable yet.");
  }

  Serial.println("---------------------------------------------");
}

void loop()
{
  unsigned long now = millis();

  if (now - lastSensorRead >= SENSOR_INTERVAL_MS)
  {
    lastSensorRead = now;

    readSensors();
    expireManualOverrides();
    applyAutomaticControl();
    driveActuators();
  }

  if (now - lastTelemetrySend >= TELEMETRY_INTERVAL_MS)
  {
    lastTelemetrySend = now;
    sendTelemetry();
  }

  if (now - lastSerialReport >= SERIAL_REPORT_INTERVAL_MS)
  {
    lastSerialReport = now;
    printStatus();
  }

  // Re-advertise once the app drops the link, so it can reconnect.
  if (!deviceConnected && wasConnected)
  {
    delay(500);
    BLEDevice::startAdvertising();
    Serial.println("BLE: advertising restarted.");
  }
  wasConnected = deviceConnected;

  delay(10);
}
