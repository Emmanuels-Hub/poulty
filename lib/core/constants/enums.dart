enum UserRole { admin, viewer }

enum OperatingMode { automatic, manual }

/// The system only runs the starter stage.
enum PoultryStage { starter }

enum ActuatorType { ventilationFan, heatLamp }

enum SensorType {
  temperature,
  humidity,
  airPurity,
  feedLevel,
  waterLevel,
}

enum AlertType {
  abnormalTemperature,
  abnormalHumidity,
  poorAirPurity,
  lowFeed,
  lowWater,
  actuatorFailure,
  systemRestart,
  deviceReconnected,
  custom,
}

enum AlertSeverity { info, warning, critical }

enum DeviceConnectionStatus { connected, connecting, disconnected }

enum EventCategory { system, sensor, actuator, alert, user, connection }
