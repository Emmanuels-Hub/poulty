#include <DHT.h>
#include "HX711.h"

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


// =====================================================
//                  SENSOR OBJECTS
// =====================================================

DHT dht(DHT_PIN, DHT_TYPE);

HX711 feedScale;
HX711 waterScale;


// =====================================================
//              TEMPERATURE THRESHOLDS
// =====================================================

#define TEMP_CRITICAL_LOW     25.0
#define TEMP_WARNING_LOW      27.0

#define TEMP_WARNING_HIGH     32.0
#define TEMP_CRITICAL_HIGH    34.0


// =====================================================
//                HUMIDITY THRESHOLDS
// =====================================================

#define HUM_CRITICAL_LOW      40.0
#define HUM_WARNING_LOW       50.0

#define HUM_WARNING_HIGH      65.0
#define HUM_CRITICAL_HIGH     70.0


// =====================================================
//                 MQ-135 THRESHOLDS
// =====================================================
//
// These are RAW ADC values.
// They are NOT ammonia ppm.
//

#define GAS_NORMAL_LIMIT      1500
#define GAS_WARNING_LIMIT     2500
#define GAS_CRITICAL_LIMIT    3200


// =====================================================
//             LOAD CELL CALIBRATION
// =====================================================
//
// These are temporary calibration factors.
// Replace them with your actual calibration factors.
//

float feedCalibrationFactor = 420.0;
float waterCalibrationFactor = 420.0;


// =====================================================
//              CONTAINER CAPACITIES
// =====================================================

float feedFullWeightKg = 1.0;
float waterFullWeightKg = 1.0;


// =====================================================
//              LEVEL THRESHOLDS
// =====================================================

#define EMPTY_LEVEL_PERCENT 20.0
#define HALF_LEVEL_PERCENT  50.0
#define HIGH_LEVEL_PERCENT  70.0


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

  // Feed HX711
  feedScale.begin(
    FEED_HX711_DT,
    FEED_HX711_SCK
  );

  feedScale.set_scale(feedCalibrationFactor);
  feedScale.tare();

  // Water HX711
  waterScale.begin(
    WATER_HX711_DT,
    WATER_HX711_SCK
  );

  waterScale.set_scale(waterCalibrationFactor);
  waterScale.tare();

  // Actuators
  pinMode(FAN_PIN, OUTPUT);
  pinMode(HEAT_LAMP_PIN, OUTPUT);

  // Start safely with both OFF
  digitalWrite(FAN_PIN, LOW);
  digitalWrite(HEAT_LAMP_PIN, LOW);

  Serial.println("DHT22 initialized.");
  Serial.println("MQ-135 initialized.");
  Serial.println("Feed HX711 initialized.");
  Serial.println("Water HX711 initialized.");
  Serial.println("Fan initialized on GPIO 25.");
  Serial.println("Heat bulb initialized on GPIO 26.");
  Serial.println();

  Serial.println("SYSTEM READY");
  Serial.println();

  delay(2000);
}


// =====================================================
//                       MAIN LOOP
// ===================================