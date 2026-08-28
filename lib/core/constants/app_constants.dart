class AppConstants {
  AppConstants._();

  static const String appName = 'Smart Poultry';
  static const int maxAdmins = 3;

  /// How often a fresh snapshot is expected/requested from the controller.
  static const Duration telemetryPollInterval = Duration(seconds: 5);

  /// Minimum gap between repeat notifications for the same alert.
  static const Duration notificationInterval = Duration(minutes: 5);

  /// Manual actuator overrides revert automatically after this long.
  static const Duration manualActuatorTimeout = Duration(minutes: 15);

  static const int maxHistoryPoints = 288;
  static const int maxEventLogs = 500;
  static const int maxNotifications = 200;

  /// Number of buckets the analytics charts approximate history into.
  static const int chartApproximationBuckets = 24;

  // --- Starter stage environmental targets ---------------------------------
  // The system runs the starter stage only, so these are fixed.
  //
  // These mirror the thresholds in esp/esp.ino exactly. If you change one
  // side, change the other: the firmware controls the actuators from its
  // copy, and the app raises alerts from this one.
  //
  // The comfort band sits between the warning limits; crossing a critical
  // limit escalates the alert severity.
  static const double starterTempMin = 32;
  static const double starterTempMax = 35;
  static const double starterTempCriticalMin = 30;
  static const double starterTempCriticalMax = 37;

  static const double starterHumidityMin = 50;
  static const double starterHumidityMax = 70;
  static const double starterHumidityCriticalMin = 40;
  static const double starterHumidityCriticalMax = 80;

  /// Air purity is reported as a percentage; higher is cleaner air.
  static const double starterAirPurityMin = 60;
  static const double starterAirPurityCriticalMin = 40;

  static const double starterFeedLowThreshold = 20;
  static const double starterWaterLowThreshold = 20;

  /// The controller has no light sensor or clock, so day/night is derived
  /// from the phone instead of the telemetry frame.
  static const int daytimeStartHour = 6;
  static const int daytimeEndHour = 18;

  // --- BLE (ESP32) ---------------------------------------------------------
  /// Nordic UART style service exposed by the ESP32 firmware.
  static const String bleServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

  /// Notifies JSON telemetry frames to the app.
  static const String bleTelemetryCharUuid =
      '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  /// Accepts JSON command frames from the app.
  static const String bleCommandCharUuid =
      '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  static const String bleDeviceNamePrefix = 'SmartPoultry';
  static const Duration bleScanTimeout = Duration(seconds: 10);

  static const String hiveBoxSettings = 'settings';
  static const String hiveBoxTelemetry = 'telemetry';
  static const String hiveBoxEvents = 'events';
  static const String hiveBoxNotifications = 'notifications';
  static const String hiveBoxUsers = 'users';
  static const String hiveBoxDevices = 'devices';

  static const String secureKeySession = 'session_user_id';
  static const String secureKeyToken = 'session_token';
}
