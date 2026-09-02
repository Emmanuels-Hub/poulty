// =====================================================
//             SMART POULTRY CONTROL SYSTEM
//                  ESP32 DEVKIT V1
// =====================================================
//
// SENSORS
//   DHT22      -> Temperature + Humidity
//   MQ-135     -> Air quality / purity
//   HX711 #1   -> Feed load cell
//   HX711 #2   -> Water load cell
//
// ACTUATORS
//   Relay 1 -> 12V DC ventilation fan
//   Relay 2 -> 12V 35W DC heat bulb
//
// COMMUNICATION
//   BLE -> Flutter mobile application
//
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
#define FEED_HX711_DT 21
#define FEED_HX711_SCK 22

// ---------------- WATER HX711 ----------------
#define WATER_HX711_DT 23
#define WATER_HX711_SCK 27

// ---------------- ACTUATORS ----------------
#define FAN_PIN 25
#define HEAT_LAMP_PIN 26


// =====================================================
//             RELAY CONFIGURATION
// =====================================================
//
// FAN RELAY - GPIO 25
//   ON  = OUTPUT + LOW
//   OFF = INPUT / RELEASED
//
// HEAT BULB RELAY - GPIO 26
//   ON  = OUTPUT + HIGH
//   OFF = OUTPUT + LOW
//
// The two relay channels have DIFFERENT configurations.
// =====================================================


// =====================================================
//                     BLE
// =====================================================

#define BLE_DEVICE_NAME "SmartPoultry-Coop"

#define BLE_SERVICE_UUID \
"6e400001-b5a3-f393-e0a9-e50e24dcca9e"

#define BLE_COMMAND_CHAR_UUID \
"6e400002-b5a3-f393-e0a9-e50e24dcca9e"

#define BLE_TELEMETRY_CHAR_UUID \
"6e400003-b5a3-f393-e0a9-e50e24dcca9e"

#define BLE_CHUNK_SIZE 20
#define BLE_CHUNK_DELAY_MS 8


// =====================================================
//             ENVIRONMENTAL THRESHOLDS
// =====================================================

// ---------------- TEMPERATURE ----------------
//
// <30°C       = CRITICAL LOW
// 30-<32°C    = WARNING LOW
// 32-35°C     = NORMAL
// >35-37°C    = WARNING HIGH
// >37°C       = CRITICAL HIGH
//

#define TEMP_CRITICAL_LOW 30.0
#define TEMP_WARNING_LOW 32.0
#define TEMP_WARNING_HIGH 35.0
#define TEMP_CRITICAL_HIGH 37.0

#define TEMP_HYSTERESIS 0.5


// ---------------- HUMIDITY ----------------
//
// <40%        = CRITICAL LOW
// 40-<50%     = WARNING LOW
// 50-70%      = NORMAL
// >70-80%     = WARNING HIGH
// >80%        = CRITICAL HIGH
//

#define HUM_CRITICAL_LOW 40.0
#define HUM_WARNING_LOW 50.0
#define HUM_WARNING_HIGH 70.0
#define HUM_CRITICAL_HIGH 80.0


// ---------------- AIR PURITY ----------------
//
// Higher percentage = cleaner air.
//
// >=60%       = NORMAL
// 40-<60%     = WARNING
// <40%        = CRITICAL
//

#define AIR_PURITY_WARNING_LOW 60.0
#define AIR_PURITY_CRITICAL_LOW 40.0

#define PURITY_HYSTERESIS 3.0


// =====================================================
//                    SIMULATION
// =====================================================
//
// Simulation lets the app inject sensor values so the REAL relays respond,
// which is how the system is demonstrated without waiting for the coop to
// actually heat up or foul.
//
// It is deliberately hard to leave running:
//
//   1. Real sensors are still read every cycle. Simulation only replaces the
//      numbers handed to the control logic.
//   2. A real CRITICAL HIGH temperature always wins, cancels simulation and
//      forces fan ON / bulb OFF. No injected value can suppress that.
//   3. The session expires on its own, and cannot be extended past
//      SIM_MAX_MINUTES from when it started.
//   4. Losing the BLE link ends it immediately.
//
// See the note on applyCriticalSafety() for why a real CRITICAL LOW is
// treated differently from a real CRITICAL HIGH.
//

#define SIM_DEFAULT_MINUTES 10
#define SIM_MAX_MINUTES 30

#define SIM_TEMPERATURE 0
#define SIM_HUMIDITY 1
#define SIM_AIR_PURITY 2
#define SIM_FEED 3
#define SIM_WATER 4
#define SIM_SENSOR_COUNT 5


// =====================================================
//                MQ-135 CALIBRATION
// =====================================================

#define GAS_CLEAN_ADC 400.0
#define GAS_FOUL_ADC 3200.0

#define GAS_WARMUP_MS 20000UL


// =====================================================
//              LOAD CELL CALIBRATION
// =====================================================

float feedCalibrationFactor = 960.0;
float waterCalibrationFactor = 960.0;


// =====================================================
//              FEED / WATER LEVEL LIMITS
// =====================================================
//
// 118 kg = 100%
// 85 kg  = 50%
// 53 kg  = 20%
// Below 53 kg = EMPTY range
//
// =====================================================

#define LEVEL_FULL_WEIGHT 118.0
#define LEVEL_HALF_WEIGHT 85.0
#define LEVEL_EMPTY_WEIGHT 53.0


// =====================================================
//                  LOAD CELL OBJECTS
// =====================================================

HX711 feedScale;
HX711 waterScale;


// =====================================================
//                  SENSOR OBJECTS
// =====================================================

DHT dht(DHT_PIN, DHT_TYPE);


// =====================================================
//                    TIMING
// =====================================================

#define SENSOR_INTERVAL_MS 2000UL
#define TELEMETRY_INTERVAL_MS 3000UL
#define SERIAL_REPORT_INTERVAL_MS 3000UL


// =====================================================
//                  SENSOR VALUES
// =====================================================

float temperatureC = 0.0;
float humidityPercent = 0.0;
float airPurityPercent = 100.0;

float feedWeightKg = 0.0;
float waterWeightKg = 0.0;

bool haveTemperature = false;
bool haveHumidity = false;


// =====================================================
//                  LEVEL VALUES
// =====================================================

float feedLevelPercent = 0.0;
float waterLevelPercent = 0.0;


// =====================================================
//              EFFECTIVE SENSOR VALUES
// =====================================================
//
// What the control logic and the app actually see: the real reading, or the
// injected one when that sensor is being simulated.
//

float effTemperatureC = 0.0;
float effHumidityPercent = 0.0;
float effAirPurityPercent = 100.0;
float effFeedLevelPercent = 0.0;
float effWaterLevelPercent = 0.0;


// =====================================================
//                 SIMULATION STATE
// =====================================================

bool simulationActive = false;

unsigned long simulationUntil = 0;
unsigned long simulationHardStop = 0;

bool simOverride[SIM_SENSOR_COUNT] = {
  false, false, false, false, false
};

float simValue[SIM_SENSOR_COUNT] = {
  0.0, 0.0, 0.0, 0.0, 0.0
};


// =====================================================
//                  ACTUATOR STATE
// =====================================================

bool fanOn = false;
bool heatLampOn = false;


// =====================================================
//                OPERATING MODE
// =====================================================

enum OperatingMode
{
  MODE_AUTOMATIC,
  MODE_MANUAL
};

OperatingMode operatingMode = MODE_AUTOMATIC;


// =====================================================
//             MANUAL OVERRIDE SYSTEM
// =====================================================

bool fanManual = false;
bool heatLampManual = false;

unsigned long fanManualUntil = 0;
unsigned long heatLampManualUntil = 0;


// =====================================================
//                    BLE STATE
// =====================================================

BLEServer *bleServer = nullptr;

BLECharacteristic *telemetryCharacteristic = nullptr;

bool deviceConnected = false;
bool wasConnected = false;

String commandBuffer = "";


// =====================================================
//                    TIMERS
// =====================================================

unsigned long lastSensorRead = 0;
unsigned long lastTelemetrySend = 0;
unsigned long lastSerialReport = 0;

unsigned long bootMillis = 0;


// =====================================================
//                     HELPERS
// =====================================================

float clampFloat(float value, float low, float high)
{
  if (value < low)
    return low;

  if (value > high)
    return high;

  return value;
}


// =====================================================
//                SIMULATION HELPERS
// =====================================================

int sensorIndex(const String &name)
{
  if (name == "temperature")
    return SIM_TEMPERATURE;

  if (name == "humidity")
    return SIM_HUMIDITY;

  if (name == "airPurity")
    return SIM_AIR_PURITY;

  if (name == "feedLevel")
    return SIM_FEED;

  if (name == "waterLevel")
    return SIM_WATER;

  return -1;
}


// Injected values are clamped to something physically plausible, so a bad
// slider or a corrupted frame cannot drive the relays with nonsense.
float simRangeMin(int index)
{
  if (index == SIM_TEMPERATURE)
    return 0.0;

  return 0.0;
}


float simRangeMax(int index)
{
  if (index == SIM_TEMPERATURE)
    return 60.0;

  return 100.0;
}


int simulatedMask()
{
  int mask = 0;

  for (int i = 0; i < SIM_SENSOR_COUNT; i++)
  {
    if (simOverride[i])
    {
      mask |= (1 << i);
    }
  }

  return mask;
}


void stopSimulation(const char *reason)
{
  if (!simulationActive)
    return;

  simulationActive = false;

  for (int i = 0; i < SIM_SENSOR_COUNT; i++)
  {
    simOverride[i] = false;
  }

  // Hand the actuators straight back to automatic control.
  fanManual = false;
  heatLampManual = false;

  Serial.print(
    "SIMULATION STOPPED: "
  );

  Serial.println(
    reason
  );
}


// Chooses real or injected values for every sensor. Called at the end of each
// sensor read, so the control logic downstream never has to care which is which.
void updateEffectiveValues()
{
  effTemperatureC =
      (simulationActive && simOverride[SIM_TEMPERATURE])
        ? simValue[SIM_TEMPERATURE]
        : temperatureC;

  effHumidityPercent =
      (simulationActive && simOverride[SIM_HUMIDITY])
        ? simValue[SIM_HUMIDITY]
        : humidityPercent;

  effAirPurityPercent =
      (simulationActive && simOverride[SIM_AIR_PURITY])
        ? simValue[SIM_AIR_PURITY]
        : airPurityPercent;

  effFeedLevelPercent =
      (simulationActive && simOverride[SIM_FEED])
        ? simValue[SIM_FEED]
        : feedLevelPercent;

  effWaterLevelPercent =
      (simulationActive && simOverride[SIM_WATER])
        ? simValue[SIM_WATER]
        : waterLevelPercent;
}


// =====================================================
//               CALCULATE LEVEL PERCENTAGE
// =====================================================

float calculateLevelPercent(float weightKg)
{
  if (weightKg >= LEVEL_FULL_WEIGHT)
  {
    return 100.0;
  }

  // 85 kg to 118 kg
  if (weightKg >= LEVEL_HALF_WEIGHT)
  {
    return 50.0 +
           ((weightKg - LEVEL_HALF_WEIGHT) /
            (LEVEL_FULL_WEIGHT - LEVEL_HALF_WEIGHT))
           * 50.0;
  }

  // 53 kg to 85 kg
  if (weightKg >= LEVEL_EMPTY_WEIGHT)
  {
    return 20.0 +
           ((weightKg - LEVEL_EMPTY_WEIGHT) /
            (LEVEL_HALF_WEIGHT - LEVEL_EMPTY_WEIGHT))
           * 30.0;
  }

  // Below 53 kg
  float percentage =
      (weightKg / LEVEL_EMPTY_WEIGHT) * 20.0;

  return clampFloat(
    percentage,
    0.0,
    20.0
  );
}


// =====================================================
//                 LEVEL STATUS
// =====================================================

String getLevelStatus(float weightKg)
{
  if (weightKg >= LEVEL_HALF_WEIGHT)
  {
    return "FULL";
  }

  if (weightKg >= LEVEL_EMPTY_WEIGHT)
  {
    return "HALF";
  }

  return "EMPTY";
}


// =====================================================
//            LEVEL STATUS FROM PERCENTAGE
// =====================================================
//
// Mirrors getLevelStatus() but works off the percentage, so a simulated feed
// or water level reports a status that matches the number beside it.
//

String getLevelStatusPercent(float percent)
{
  if (percent >= 50.0)
  {
    return "FULL";
  }

  if (percent >= 20.0)
  {
    return "HALF";
  }

  return "EMPTY";
}


bool refillNeededPercent(float percent)
{
  return percent < 20.0;
}


// =====================================================
//                 REFILL STATUS
// =====================================================

bool refillNeeded(float weightKg)
{
  return weightKg < LEVEL_EMPTY_WEIGHT;
}


// =====================================================
//                  FAN RELAY CONTROL
// =====================================================
//
// IMPORTANT:
//
// Fan relay is confirmed to behave as:
//
// ON:
//   GPIO 25 = OUTPUT
//   GPIO 25 = LOW
//
// OFF:
//   GPIO 25 = INPUT
//   GPIO 25 = RELEASED
//
// Do NOT drive GPIO 25 HIGH for OFF.
//
// =====================================================

void setFanRelay(bool state)
{
  if (state)
  {
    pinMode(
      FAN_PIN,
      OUTPUT
    );

    digitalWrite(
      FAN_PIN,
      LOW
    );
  }
  else
  {
    pinMode(
      FAN_PIN,
      INPUT
    );
  }
}


// =====================================================
//                HEAT BULB RELAY CONTROL
// =====================================================
//
// Heat bulb relay is confirmed to behave as:
//
// ON:
//   GPIO 26 = OUTPUT
//   GPIO 26 = HIGH
//
// OFF:
//   GPIO 26 = OUTPUT
//   GPIO 26 = LOW
//
// =====================================================

void setHeatBulbRelay(bool state)
{
  pinMode(
    HEAT_LAMP_PIN,
    OUTPUT
  );

  if (state)
  {
    digitalWrite(
      HEAT_LAMP_PIN,
      HIGH
    );
  }
  else
  {
    digitalWrite(
      HEAT_LAMP_PIN,
      LOW
    );
  }
}


// =====================================================
//                    SAFE START
// =====================================================

void allOff()
{
  // Fan OFF = release GPIO 25
  pinMode(
    FAN_PIN,
    INPUT
  );

  // Heat bulb OFF = GPIO 26 LOW
  pinMode(
    HEAT_LAMP_PIN,
    OUTPUT
  );

  digitalWrite(
    HEAT_LAMP_PIN,
    LOW
  );
}


// =====================================================
//             TEMPERATURE CATEGORY
// =====================================================

String getTemperatureCategory(float t)
{
  if (t < TEMP_CRITICAL_LOW)
    return "CRITICAL LOW";

  if (t < TEMP_WARNING_LOW)
    return "WARNING LOW";

  if (t <= TEMP_WARNING_HIGH)
    return "NORMAL";

  if (t <= TEMP_CRITICAL_HIGH)
    return "WARNING HIGH";

  return "CRITICAL HIGH";
}


// =====================================================
//               HUMIDITY CATEGORY
// =====================================================

String getHumidityCategory(float h)
{
  if (h < HUM_CRITICAL_LOW)
    return "CRITICAL LOW";

  if (h < HUM_WARNING_LOW)
    return "WARNING LOW";

  if (h <= HUM_WARNING_HIGH)
    return "NORMAL";

  if (h <= HUM_CRITICAL_HIGH)
    return "WARNING HIGH";

  return "CRITICAL HIGH";
}


// =====================================================
//              AIR PURITY CATEGORY
// =====================================================

String getAirPurityCategory(float purity)
{
  if (purity < AIR_PURITY_CRITICAL_LOW)
    return "CRITICAL";

  if (purity < AIR_PURITY_WARNING_LOW)
    return "WARNING";

  return "NORMAL";
}


// =====================================================
//             READ TEMPERATURE/HUMIDITY
// =====================================================

void readTemperatureAndHumidity()
{
  float t = dht.readTemperature();
  float h = dht.readHumidity();

  if (!isnan(t))
  {
    temperatureC = t;
    haveTemperature = true;
  }
  else
  {
    Serial.println(
      "WARNING: DHT22 temperature read failed."
    );
  }

  if (!isnan(h))
  {
    humidityPercent = h;
    haveHumidity = true;
  }
  else
  {
    Serial.println(
      "WARNING: DHT22 humidity read failed."
    );
  }
}


// =====================================================
//                   READ MQ-135
// =====================================================

void readAirPurity()
{
  long total = 0;

  const int samples = 8;

  for (int i = 0; i < samples; i++)
  {
    total += analogRead(MQ135_PIN);
    delay(2);
  }

  float raw =
      (float)total / samples;

  float span =
      GAS_FOUL_ADC - GAS_CLEAN_ADC;

  float purity =
      100.0 -
      ((raw - GAS_CLEAN_ADC) / span) * 100.0;

  airPurityPercent =
      clampFloat(
        purity,
        0.0,
        100.0
      );
}


// =====================================================
//                  READ LOAD CELL
// =====================================================

float readWeightKg(
    HX711 &scale,
    float lastValue,
    const char *label)
{
  if (!scale.is_ready())
  {
    Serial.print(
      "WARNING: "
    );

    Serial.print(
      label
    );

    Serial.println(
      " HX711 not ready."
    );

    return lastValue;
  }

  float weightKg =
      scale.get_units(5);

  if (weightKg < 0)
    weightKg = 0;

  return weightKg;
}


// =====================================================
//                    READ ALL SENSORS
// =====================================================

void readSensors()
{
  readTemperatureAndHumidity();

  readAirPurity();

  feedWeightKg =
      readWeightKg(
        feedScale,
        feedWeightKg,
        "Feed"
      );

  waterWeightKg =
      readWeightKg(
        waterScale,
        waterWeightKg,
        "Water"
      );


  // Calculate feed and water percentages

  feedLevelPercent =
      calculateLevelPercent(
        feedWeightKg
      );

  waterLevelPercent =
      calculateLevelPercent(
        waterWeightKg
      );


  // Resolve real vs injected values for this cycle.

  updateEffectiveValues();
}


// =====================================================
//                AUTOMATIC CONTROL
// =====================================================
//
// FAN AND HEAT BULB ARE CONTROLLED INDEPENDENTLY.
//
// FAN REQUESTS:
//   - Temperature too high
//   - Humidity too high
//   - Air purity too low
//
// HEAT BULB REQUEST:
//   - Temperature too low
//
// There is NO normal-operation priority between
// the fan and heat bulb.
//
// Both may be ON at the same time if their respective
// conditions require it.
//
// =====================================================

void applyAutomaticControl()
{
  if (operatingMode != MODE_AUTOMATIC)
    return;


  // ===================================================
  // FAN REQUEST
  // ===================================================

  bool fanRequest = false;


  // Temperature too high
  if (effTemperatureC > TEMP_WARNING_HIGH)
  {
    fanRequest = true;
  }


  // Humidity too high
  if (effHumidityPercent > HUM_WARNING_HIGH)
  {
    fanRequest = true;
  }


  // Air purity too low
  if (effAirPurityPercent < AIR_PURITY_WARNING_LOW)
  {
    fanRequest = true;
  }


  // ===================================================
  // FAN CONTROL
  // ===================================================

  if (!fanManual)
  {
    if (fanRequest)
    {
      fanOn = true;
    }
    else
    {
      bool environmentRecovered =
          effTemperatureC <
              (TEMP_WARNING_HIGH -
               TEMP_HYSTERESIS)

          &&

          effHumidityPercent <
              HUM_WARNING_HIGH

          &&

          effAirPurityPercent >
              (AIR_PURITY_WARNING_LOW +
               PURITY_HYSTERESIS);


      if (environmentRecovered)
      {
        fanOn = false;
      }
    }
  }


  // ===================================================
  // HEAT BULB REQUEST
  // ===================================================

  if (!heatLampManual)
  {
    if (effTemperatureC <
        TEMP_WARNING_LOW)
    {
      heatLampOn = true;
    }
    else if (
        effTemperatureC >
        (TEMP_WARNING_LOW +
         TEMP_HYSTERESIS))
    {
      heatLampOn = false;
    }
  }
}


// =====================================================
//              CRITICAL TEMPERATURE SAFETY
// =====================================================
//
// Runs in EVERY mode - automatic, manual and simulation - and always from the
// REAL sensor reading. Simulated values are ignored here on purpose.
//
// CRITICAL HIGH is a hazard to the birds and to the 35W bulb itself, so it
// always wins: fan ON, bulb OFF, manual overrides dropped, simulation
// cancelled. Nothing the app sends can suppress it.
//
// CRITICAL LOW is different. It only endangers live birds, and it is true of
// any bench sitting at room temperature - enforcing it would pin the bulb ON
// and make simulation impossible to demonstrate. So while the operator has
// explicitly declared a simulation session, it is reported but not enforced.
//
// =====================================================

void applyCriticalSafety()
{
  // Never act on a sensor that has not produced a reading yet.
  if (!haveTemperature)
    return;


  if (temperatureC >= TEMP_CRITICAL_HIGH)
  {
    fanOn = true;
    heatLampOn = false;

    fanManual = false;
    heatLampManual = false;

    if (simulationActive)
    {
      stopSimulation(
        "real temperature critically high"
      );
    }

    return;
  }


  if (temperatureC <= TEMP_CRITICAL_LOW)
  {
    if (simulationActive)
    {
      // Reported, not enforced - see the note above.
      return;
    }

    heatLampOn = true;
    fanOn = false;

    fanManual = false;
    heatLampManual = false;
  }
}


// =====================================================
//               EXPIRE SIMULATION
// =====================================================

void expireSimulation()
{
  if (!simulationActive)
    return;


  unsigned long now =
      millis();


  if (
      (long)(now - simulationUntil) >= 0
     )
  {
    stopSimulation(
      "session timed out"
    );

    return;
  }


  if (
      (long)(now - simulationHardStop) >= 0
     )
  {
    stopSimulation(
      "maximum session length reached"
    );
  }
}


// =====================================================
//             EXPIRE MANUAL OVERRIDES
// =====================================================

void expireManualOverrides()
{
  unsigned long now =
      millis();


  if (
      fanManual &&
      (long)(now - fanManualUntil) >= 0
     )
  {
    fanManual = false;

    Serial.println(
      "Fan manual override expired."
    );
  }


  if (
      heatLampManual &&
      (long)(now - heatLampManualUntil) >= 0
     )
  {
    heatLampManual = false;

    Serial.println(
      "Heat bulb manual override expired."
    );
  }
}


// =====================================================
//                  DRIVE RELAYS
// =====================================================
//
// Each relay is driven according to its own actual
// electrical configuration.
//
// FAN:
//   ON  -> OUTPUT LOW
//   OFF -> INPUT
//
// HEAT BULB:
//   ON  -> OUTPUT HIGH
//   OFF -> OUTPUT LOW
//
// =====================================================

void driveActuators()
{
  setFanRelay(
    fanOn
  );

  setHeatBulbRelay(
    heatLampOn
  );
}


// =====================================================
//                SERIAL STATUS DISPLAY
// =====================================================

void printStatus()
{
  Serial.println();
  Serial.println(
    "================================================"
  );

  Serial.println(
    "             SMART POULTRY STATUS"
  );

  Serial.println(
    "================================================"
  );


  // ---------------- TEMPERATURE ----------------

  Serial.print(
    "Temperature : "
  );

  if (haveTemperature)
  {
    Serial.print(
      temperatureC,
      1
    );

    Serial.print(
      " °C"
    );

    Serial.print(
      " | Category: "
    );

    Serial.println(
      getTemperatureCategory(
        temperatureC
      )
    );
  }
  else
  {
    Serial.println(
      "No reading"
    );
  }


  // ---------------- HUMIDITY ----------------

  Serial.print(
    "Humidity    : "
  );

  if (haveHumidity)
  {
    Serial.print(
      humidityPercent,
      1
    );

    Serial.print(
      " %"
    );

    Serial.print(
      " | Category: "
    );

    Serial.println(
      getHumidityCategory(
        humidityPercent
      )
    );
  }
  else
  {
    Serial.println(
      "No reading"
    );
  }


  // ---------------- AIR PURITY ----------------

  Serial.print(
    "Air Purity  : "
  );

  Serial.print(
    airPurityPercent,
    1
  );

  Serial.print(
    " %"
  );

  Serial.print(
    " | Category: "
  );

  Serial.println(
    getAirPurityCategory(
      airPurityPercent
    )
  );


  // =================================================
  //                     FEED
  // =================================================

  Serial.println();

  Serial.print(
    "Feed Level  : "
  );

  Serial.print(
    feedLevelPercent,
    1
  );

  Serial.print(
    "% | Status: "
  );

  Serial.println(
    getLevelStatus(
      feedWeightKg
    )
  );


  if (
      refillNeeded(
        feedWeightKg
      )
     )
  {
    Serial.println(
      "FEED: REFILL NEEDED!"
    );
  }


  // =================================================
  //                     WATER
  // =================================================

  Serial.print(
    "Water Level : "
  );

  Serial.print(
    waterLevelPercent,
    1
  );

  Serial.print(
    "% | Status: "
  );

  Serial.println(
    getLevelStatus(
      waterWeightKg
    )
  );


  if (
      refillNeeded(
        waterWeightKg
      )
     )
  {
    Serial.println(
      "WATER: REFILL NEEDED!"
    );
  }


  // ---------------- ACTUATORS ----------------

  Serial.println();

  Serial.print(
    "Fan         : "
  );

  Serial.println(
    fanOn
      ? "ON"
      : "OFF"
  );


  Serial.print(
    "Heat Bulb   : "
  );

  Serial.println(
    heatLampOn
      ? "ON"
      : "OFF"
  );


  // ---------------- MODE ----------------

  Serial.print(
    "Mode        : "
  );

  Serial.println(
    operatingMode ==
        MODE_MANUAL
      ? "MANUAL"
      : "AUTOMATIC"
  );


  // ---------------- BLE ----------------

  Serial.print(
    "BLE App     : "
  );

  Serial.println(
    deviceConnected
      ? "CONNECTED"
      : "NOT CONNECTED"
  );


  // ---------------- SIMULATION ----------------

  if (simulationActive)
  {
    Serial.println();

    Serial.println(
      "*** SIMULATION ACTIVE ***"
    );

    Serial.print(
      "Ends in     : "
    );

    Serial.print(
      (long)(simulationUntil - millis()) / 1000
    );

    Serial.println(
      " s"
    );

    Serial.print(
      "Simulated   : "
    );

    if (simulatedMask() == 0)
    {
      Serial.println(
        "none yet"
      );
    }
    else
    {
      if (simOverride[SIM_TEMPERATURE])
        Serial.print("temperature ");

      if (simOverride[SIM_HUMIDITY])
        Serial.print("humidity ");

      if (simOverride[SIM_AIR_PURITY])
        Serial.print("airPurity ");

      if (simOverride[SIM_FEED])
        Serial.print("feedLevel ");

      if (simOverride[SIM_WATER])
        Serial.print("waterLevel ");

      Serial.println();
    }

    Serial.print(
      "Real temp   : "
    );

    Serial.print(
      temperatureC,
      1
    );

    Serial.println(
      " °C (safety still watches this)"
    );

    Serial.println();
  }


  // ---------------- MQ RAW ----------------

  Serial.print(
    "MQ-135 Raw  : "
  );

  Serial.println(
    analogRead(MQ135_PIN)
  );


  if (
      millis() - bootMillis <
      GAS_WARMUP_MS
     )
  {
    Serial.println();

    Serial.println(
      "NOTE: MQ-135 is still warming up."
    );
  }


  Serial.println(
    "================================================"
  );
}


// =====================================================
//                  TELEMETRY JSON
// =====================================================

String buildTelemetryJson()
{
  char buffer[900];


  // Everything reported is the EFFECTIVE value, so the app always shows what
  // the controller is actually acting on.

  int written =
      snprintf(
        buffer,
        sizeof(buffer),

        "{\"temperatureC\":%.1f,"
        "\"humidityPercent\":%.1f,"
        "\"airPurityPercent\":%.1f,"
        "\"feedLevelPercent\":%.1f,"
        "\"waterLevelPercent\":%.1f,"
        "\"operatingMode\":\"%s\","
        "\"poultryStage\":\"starter\","

        "\"simulationMode\":%s,"
        "\"simulatedMask\":%d,"

        "\"temperatureCategory\":\"%s\","
        "\"humidityCategory\":\"%s\","
        "\"airPurityCategory\":\"%s\","

        "\"feedStatus\":\"%s\","
        "\"waterStatus\":\"%s\","

        "\"feedRefillNeeded\":%s,"
        "\"waterRefillNeeded\":%s,"

        "\"actuators\":["

        "{\"type\":\"ventilationFan\","
        "\"isOn\":%s,"
        "\"isManualOverride\":%s,"
        "\"hasFailure\":false},"

        "{\"type\":\"heatLamp\","
        "\"isOn\":%s,"
        "\"isManualOverride\":%s,"
        "\"hasFailure\":false}"

        "],"

        "\"deviceId\":\"%s\"}
",

        effTemperatureC,

        effHumidityPercent,

        effAirPurityPercent,

        effFeedLevelPercent,

        effWaterLevelPercent,

        operatingMode ==
            MODE_MANUAL
          ? "manual"
          : "automatic",

        simulationActive
          ? "true"
          : "false",

        simulatedMask(),

        getTemperatureCategory(
          effTemperatureC
        ).c_str(),

        getHumidityCategory(
          effHumidityPercent
        ).c_str(),

        getAirPurityCategory(
          effAirPurityPercent
        ).c_str(),

        getLevelStatusPercent(
          effFeedLevelPercent
        ).c_str(),

        getLevelStatusPercent(
          effWaterLevelPercent
        ).c_str(),

        refillNeededPercent(
          effFeedLevelPercent
        )
          ? "true"
          : "false",

        refillNeededPercent(
          effWaterLevelPercent
        )
          ? "true"
          : "false",

        fanOn
          ? "true"
          : "false",

        fanManual
          ? "true"
          : "false",

        heatLampOn
          ? "true"
          : "false",

        heatLampManual
          ? "true"
          : "false",

        BLE_DEVICE_NAME
      );


  // A truncated frame loses its closing newline, and the app would sit there
  // reassembling forever. Fail loudly instead of shipping a broken frame.
  if (
      written < 0 ||
      written >= (int)sizeof(buffer)
     )
  {
    Serial.println(
      "ERROR: telemetry frame exceeded its buffer; frame not sent."
    );

    return String();
  }


  return String(buffer);
}


// =====================================================
//                 SEND BLE TELEMETRY
// =====================================================

void sendTelemetry()
{
  if (
      !deviceConnected ||
      telemetryCharacteristic == nullptr
     )
    return;


  String frame =
      buildTelemetryJson();

  int length =
      frame.length();


  if (length == 0)
    return;


  for (
      int offset = 0;
      offset < length;
      offset += BLE_CHUNK_SIZE
      )
  {
    int size =
        min(
          (int)BLE_CHUNK_SIZE,
          length - offset
        );


    telemetryCharacteristic->setValue(
        (uint8_t *)
          (frame.c_str() + offset),
        size
    );


    telemetryCharacteristic->notify();


    delay(
      BLE_CHUNK_DELAY_MS
    );
  }
}


// =====================================================
//                   JSON PARSING
// =====================================================

bool jsonFindRaw(
    const String &src,
    const char *key,
    String &out)
{
  String needle =
      String("\"") +
      key +
      "\"";


  int keyAt =
      src.indexOf(
        needle
      );


  if (keyAt < 0)
    return false;


  int colon =
      src.indexOf(
        ':',
        keyAt +
        needle.length()
      );


  if (colon < 0)
    return false;


  int i =
      colon + 1;


  while (
      i < (int)src.length() &&
      isspace(
        (unsigned char)src[i]
      )
      )
  {
    i++;
  }


  if (
      i >=
      (int)src.length()
     )
    return false;


  int end;


  if (
      src[i] ==
      '"'
     )
  {
    i++;

    end =
        src.indexOf(
          '"',
          i
        );

    if (end < 0)
      return false;
  }
  else
  {
    end = i;

    while (
        end <
        (int)src.length() &&
        src[end] != ',' &&
        src[end] != '}'
        )
    {
      end++;
    }
  }


  out =
      src.substring(
        i,
        end
      );


  out.trim();


  return true;
}


bool jsonGetString(
    const String &src,
    const char *key,
    String &out)
{
  return jsonFindRaw(
    src,
    key,
    out
  );
}


bool jsonGetBool(
    const String &src,
    const char *key,
    bool &out)
{
  String raw;


  if (
      !jsonFindRaw(
        src,
        key,
        raw
      )
     )
    return false;


  raw.toLowerCase();


  out =
      (
        raw == "true" ||
        raw == "1"
      );


  return true;
}


bool jsonGetLong(
    const String &src,
    const char *key,
    long &out)
{
  String raw;


  if (
      !jsonFindRaw(
        src,
        key,
        raw
      )
     )
    return false;


  out =
      raw.toInt();


  return true;
}


// =====================================================
//                  COMMAND HANDLING
// =====================================================

void handleSetMode(
    const String &json)
{
  String mode;


  if (
      !jsonGetString(
        json,
        "mode",
        mode
      )
     )
    return;


  if (
      mode ==
      "manual"
     )
  {
    operatingMode =
        MODE_MANUAL;


    Serial.println(
      "Operating mode -> MANUAL"
    );
  }
  else
  {
    operatingMode =
        MODE_AUTOMATIC;


    fanManual =
        false;

    heatLampManual =
        false;


    Serial.println(
      "Operating mode -> AUTOMATIC"
    );
  }
}


// =====================================================
//                 SET STAGE
// =====================================================

void handleSetStage(
    const String &json)
{
  String stage;


  if (
      !jsonGetString(
        json,
        "stage",
        stage
      )
     )
    return;


  Serial.print(
    "Production stage requested: "
  );


  Serial.println(
    stage
  );
}


// =====================================================
//               MANUAL ACTUATOR COMMAND
// =====================================================

void handleSetActuator(
    const String &json)
{
  String actuator;

  bool state = false;


  if (
      !jsonGetString(
        json,
        "actuator",
        actuator
      )
     )
    return;


  if (
      !jsonGetBool(
        json,
        "state",
        state
      )
     )
    return;


  if (
      operatingMode !=
      MODE_MANUAL
     )
  {
    Serial.println(
      "Actuator command ignored: "
      "system is AUTOMATIC."
    );

    return;
  }


  long timeoutMinutes =
      15;


  jsonGetLong(
    json,
    "timeoutMinutes",
    timeoutMinutes
  );


  if (
      timeoutMinutes <= 0
     )
  {
    timeoutMinutes =
        15;
  }


  unsigned long until =
      millis() +
      (unsigned long)
      timeoutMinutes *
      60000UL;


  if (
      actuator ==
      "ventilationFan"
     )
  {
    fanOn =
        state;


    fanManual =
        true;


    fanManualUntil =
        until;


    Serial.print(
      "Fan manually set: "
    );


    Serial.println(
      state
        ? "ON"
        : "OFF"
    );
  }


  else if (
      actuator ==
      "heatLamp"
     )
  {
    heatLampOn =
        state;


    heatLampManual =
        true;


    heatLampManualUntil =
        until;


    Serial.print(
      "Heat bulb manually set: "
    );


    Serial.println(
      state
        ? "ON"
        : "OFF"
    );
  }


  else
  {
    Serial.print(
      "Unknown actuator: "
    );


    Serial.println(
      actuator
    );


    return;
  }


  driveActuators();
}


// =====================================================
//                SIMULATION COMMANDS
// =====================================================

void handleSetSimulation(
    const String &json)
{
  bool enabled = false;


  if (
      !jsonGetBool(
        json,
        "enabled",
        enabled
      )
     )
    return;


  if (!enabled)
  {
    stopSimulation(
      "stopped from the app"
    );

    return;
  }


  long minutes =
      SIM_DEFAULT_MINUTES;


  jsonGetLong(
    json,
    "timeoutMinutes",
    minutes
  );


  if (minutes <= 0)
    minutes = SIM_DEFAULT_MINUTES;


  if (minutes > SIM_MAX_MINUTES)
    minutes = SIM_MAX_MINUTES;


  unsigned long now =
      millis();


  // A fresh session gets its own hard ceiling. Later commands may push the
  // soft deadline out, but never past this.
  if (!simulationActive)
  {
    simulationHardStop =
        now +
        (unsigned long)SIM_MAX_MINUTES *
        60000UL;
  }


  simulationActive = true;


  simulationUntil =
      now +
      (unsigned long)minutes *
      60000UL;


  if (
      (long)(simulationUntil -
             simulationHardStop) > 0
     )
  {
    simulationUntil =
        simulationHardStop;
  }


  Serial.print(
    "SIMULATION STARTED for "
  );

  Serial.print(
    minutes
  );

  Serial.println(
    " minute(s). Real sensors are still being read."
  );
}


void handleSetSensor(
    const String &json)
{
  if (!simulationActive)
  {
    Serial.println(
      "setSensor ignored: simulation is not active."
    );

    return;
  }


  String sensor;


  if (
      !jsonGetString(
        json,
        "sensor",
        sensor
      )
     )
    return;


  int index =
      sensorIndex(
        sensor
      );


  if (index < 0)
  {
    Serial.print(
      "Unknown sensor: "
    );

    Serial.println(
      sensor
    );

    return;
  }


  // An explicit clear hands that one sensor back to its real reading.
  bool clear = false;

  if (
      jsonGetBool(
        json,
        "clear",
        clear
      ) &&
      clear
     )
  {
    simOverride[index] = false;


    Serial.print(
      "Simulation cleared for: "
    );

    Serial.println(
      sensor
    );


    updateEffectiveValues();

    return;
  }


  String rawValue;


  if (
      !jsonFindRaw(
        json,
        "value",
        rawValue
      )
     )
    return;


  float value =
      clampFloat(
        rawValue.toFloat(),
        simRangeMin(index),
        simRangeMax(index)
      );


  simValue[index] = value;

  simOverride[index] = true;


  // Keep an active session alive while it is being driven, up to the ceiling.
  unsigned long extended =
      millis() +
      (unsigned long)SIM_DEFAULT_MINUTES *
      60000UL;


  simulationUntil =
      (long)(extended -
             simulationHardStop) > 0
        ? simulationHardStop
        : extended;


  Serial.print(
    "Simulated "
  );

  Serial.print(
    sensor
  );

  Serial.print(
    " = "
  );

  Serial.println(
    value,
    1
  );


  updateEffectiveValues();


  // Respond on the next control cycle rather than waiting for a sensor tick.
  applyAutomaticControl();

  applyCriticalSafety();

  driveActuators();
}


// =====================================================
//                  HANDLE COMMAND
// =====================================================

void handleCommand(
    const String &json)
{
  if (
      json.length() ==
      0
     )
    return;


  String command;


  if (
      !jsonGetString(
        json,
        "cmd",
        command
      )
     )
  {
    Serial.println(
      "Command missing cmd field."
    );


    return;
  }


  if (
      command ==
      "setMode"
     )
  {
    handleSetMode(
      json
    );
  }


  else if (
      command ==
      "setStage"
     )
  {
    handleSetStage(
      json
    );
  }


  else if (
      command ==
      "setActuator"
     )
  {
    handleSetActuator(
      json
    );
  }


  else if (
      command ==
      "setSimulation"
     )
  {
    handleSetSimulation(
      json
    );
  }


  else if (
      command ==
      "setSensor"
     )
  {
    handleSetSensor(
      json
    );
  }


  else
  {
    Serial.print(
      "Unknown command: "
    );


    Serial.println(
      command
    );
  }
}


// =====================================================
//                   BLE CALLBACKS
// =====================================================

class ServerCallbacks :
    public BLEServerCallbacks
{
  void onConnect(
      BLEServer *server)
      override
  {
    deviceConnected =
        true;


    Serial.println(
      "BLE: App connected."
    );
  }


  void onDisconnect(
      BLEServer *server)
      override
  {
    deviceConnected =
        false;


    // No app, no supervision: drop straight back to real sensor readings.
    stopSimulation(
      "app disconnected"
    );


    Serial.println(
      "BLE: App disconnected."
    );
  }
};


class CommandCallbacks :
    public BLECharacteristicCallbacks
{
  void onWrite(
      BLECharacteristic *
      characteristic)
      override
  {
    uint8_t *data =
        characteristic->getData();


    size_t length =
        characteristic->getLength();


    if (
        data == nullptr ||
        length == 0
       )
      return;


    for (
        size_t i = 0;
        i < length;
        i++
        )
    {
      commandBuffer +=
          (char)data[i];
    }


    int newline;


    while (
        (
          newline =
            commandBuffer.indexOf(
              '\n'
            )
        ) >= 0
        )
    {
      String line =
          commandBuffer.substring(
            0,
            newline
          );


      commandBuffer =
          commandBuffer.substring(
            newline + 1
          );


      line.trim();


      handleCommand(
        line
      );
    }


    String pending =
        commandBuffer;


    pending.trim();


    if (
        pending.startsWith("{") &&
        pending.endsWith("}")
       )
    {
      commandBuffer = "";


      handleCommand(
        pending
      );
    }


    if (
        commandBuffer.length() >
        512
       )
    {
      commandBuffer = "";
    }
  }
};


// =====================================================
//                     BLE SETUP
// =====================================================

void setupBle()
{
  BLEDevice::init(
    BLE_DEVICE_NAME
  );


  bleServer =
      BLEDevice::createServer();


  bleServer->setCallbacks(
    new ServerCallbacks()
  );


  BLEService *service =
      bleServer->createService(
        BLE_SERVICE_UUID
      );


  telemetryCharacteristic =
      service->createCharacteristic(
        BLE_TELEMETRY_CHAR_UUID,
        BLECharacteristic::
          PROPERTY_NOTIFY
      );


  telemetryCharacteristic->
      addDescriptor(
        new BLE2902()
      );


  BLECharacteristic *
      commandCharacteristic =
        service->createCharacteristic(
          BLE_COMMAND_CHAR_UUID,

          BLECharacteristic::
            PROPERTY_WRITE |

          BLECharacteristic::
            PROPERTY_WRITE_NR
        );


  commandCharacteristic->
      setCallbacks(
        new CommandCallbacks()
      );


  service->start();


  BLEAdvertising *
      advertising =
        BLEDevice::
          getAdvertising();


  advertising->
      addServiceUUID(
        BLE_SERVICE_UUID
      );


  advertising->
      setScanResponse(
        true
      );


  advertising->
      setMinPreferred(
        0x06
      );


  advertising->
      setMinPreferred(
        0x12
      );


  BLEDevice::
      startAdvertising();


  Serial.print(
    "BLE advertising as: "
  );


  Serial.println(
    BLE_DEVICE_NAME
  );
}


// =====================================================
//                       SETUP
// =====================================================

void setup()
{
  Serial.begin(
    115200
  );


  delay(
    1000
  );


  Serial.println();

  Serial.println(
    "=============================================="
  );

  Serial.println(
    "       SMART POULTRY CONTROL SYSTEM"
  );

  Serial.println(
    "              ESP32 DEVKIT V1"
  );

  Serial.println(
    "=============================================="
  );


  // ---------------- DHT22 ----------------

  dht.begin();


  // ---------------- MQ-135 ----------------

  pinMode(
    MQ135_PIN,
    INPUT
  );


  analogSetPinAttenuation(
    MQ135_PIN,
    ADC_11db
  );


  // ---------------- FEED HX711 ----------------

  feedScale.begin(
    FEED_HX711_DT,
    FEED_HX711_SCK
  );


  feedScale.set_scale(
    feedCalibrationFactor
  );


  feedScale.tare();


  // ---------------- WATER HX711 ----------------

  waterScale.begin(
    WATER_HX711_DT,
    WATER_HX711_SCK
  );


  waterScale.set_scale(
    waterCalibrationFactor
  );


  waterScale.tare();


  // ---------------- RELAYS ----------------
  //
  // Start both actuators OFF using their actual
  // relay configurations.
  //

  allOff();


  fanOn = false;

  heatLampOn = false;


  // ---------------- DISPLAY PIN CONFIG ----------------

  Serial.println();

  Serial.println(
    "PIN CONFIGURATION:"
  );

  Serial.println(
    "DHT22 DATA       -> GPIO 4"
  );

  Serial.println(
    "MQ-135 AO        -> GPIO 34"
  );

  Serial.println(
    "Feed HX711 DT    -> GPIO 21"
  );

  Serial.println(
    "Feed HX711 SCK   -> GPIO 22"
  );

  Serial.println(
    "Water HX711 DT   -> GPIO 23"
  );

  Serial.println(
    "Water HX711 SCK  -> GPIO 27"
  );

  Serial.println(
    "Fan Relay IN1    -> GPIO 25"
  );

  Serial.println(
    "Fan Relay ON     -> OUTPUT LOW"
  );

  Serial.println(
    "Fan Relay OFF    -> INPUT / RELEASED"
  );

  Serial.println(
    "Bulb Relay IN2   -> GPIO 26"
  );

  Serial.println(
    "Bulb Relay ON    -> OUTPUT HIGH"
  );

  Serial.println(
    "Bulb Relay OFF   -> OUTPUT LOW"
  );


  // ---------------- BLE ----------------

  setupBle();


  bootMillis =
      millis();


  // Initial sensor reading

  readSensors();


  Serial.println();

  Serial.println(
    "SYSTEM READY"
  );

  Serial.println();
}


// =====================================================
//                        LOOP
// =====================================================

void loop()
{
  unsigned long now =
      millis();


  // ---------------- SENSOR UPDATE ----------------

  if (
      now - lastSensorRead >=
      SENSOR_INTERVAL_MS
     )
  {
    lastSensorRead =
        now;


    readSensors();


    expireSimulation();


    expireManualOverrides();


    applyAutomaticControl();


    // Always last, so a real critical temperature overrides everything the
    // mode logic just decided.
    applyCriticalSafety();


    driveActuators();
  }


  // ---------------- BLE TELEMETRY ----------------

  if (
      now - lastTelemetrySend >=
      TELEMETRY_INTERVAL_MS
     )
  {
    lastTelemetrySend =
        now;


    sendTelemetry();
  }


  // ---------------- SERIAL MONITOR ----------------

  if (
      now - lastSerialReport >=
      SERIAL_REPORT_INTERVAL_MS
     )
  {
    lastSerialReport =
        now;


    printStatus();
  }


  // ---------------- BLE RECONNECT ----------------

  if (
      !deviceConnected &&
      wasConnected
     )
  {
    delay(
      500
    );


    BLEDevice::
      startAdvertising();


    Serial.println(
      "BLE: advertising restarted."
    );
  }


  wasConnected =
      deviceConnected;


  delay(
    10
  );
}