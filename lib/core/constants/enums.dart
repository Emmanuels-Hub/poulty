enum UserRole { admin, viewer }

enum OperatingMode { automatic, manual, simulation, hybrid }

enum PoultryStage { starter, grower, finisher }

enum ActuatorType { ventilationFan, heatLamp, lighting }

enum SensorType {
  temperature,
  humidity,
  ammonia,
  ambientLight,
  feedLevel,
  waterLevel,
  battery,
}

enum AlertType {
  abnormalTemperature,
  abnormalHumidity,
  abnormalAmmonia,
  lowFeed,
  lowWater,
  lowBattery,
  actuatorFailure,
  systemRestart,
  internetReconnected,
  custom,
}

enum AlertSeverity { info, warning, critical }

enum DeviceConnectionStatus { online, offline, local, reconnecting }

enum DataSource { live, simulated }

enum EventCategory {
  system,
  sensor,
  actuator,
  alert,
  user,
  network,
  diagnostics,
}
