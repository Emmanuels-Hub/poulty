import '../../core/constants/enums.dart';

class EnumLabels {
  EnumLabels._();

  static String operatingMode(OperatingMode mode) {
    switch (mode) {
      case OperatingMode.automatic:
        return 'Automatic';
      case OperatingMode.manual:
        return 'Manual';
      case OperatingMode.simulation:
        return 'Simulation';
      case OperatingMode.hybrid:
        return 'Hybrid';
    }
  }

  static String poultryStage(PoultryStage stage) {
    switch (stage) {
      case PoultryStage.starter:
        return 'Starter';
      case PoultryStage.grower:
        return 'Grower';
      case PoultryStage.finisher:
        return 'Finisher';
    }
  }

  static String actuator(ActuatorType type) {
    switch (type) {
      case ActuatorType.ventilationFan:
        return 'Ventilation Fan';
      case ActuatorType.heatLamp:
        return 'Heat Lamp';
      case ActuatorType.lighting:
        return 'Lighting';
    }
  }

  static String sensor(SensorType type) {
    switch (type) {
      case SensorType.temperature:
        return 'Temperature';
      case SensorType.humidity:
        return 'Humidity';
      case SensorType.ammonia:
        return 'Ammonia';
      case SensorType.ambientLight:
        return 'Ambient Light';
      case SensorType.feedLevel:
        return 'Feed Level';
      case SensorType.waterLevel:
        return 'Water Level';
      case SensorType.battery:
        return 'Battery';
    }
  }

  static String connectionStatus(DeviceConnectionStatus status) {
    switch (status) {
      case DeviceConnectionStatus.online:
        return 'Online (Internet)';
      case DeviceConnectionStatus.local:
        return 'Online (Local Network)';
      case DeviceConnectionStatus.offline:
        return 'Offline';
      case DeviceConnectionStatus.reconnecting:
        return 'Reconnecting';
    }
  }

  static String userRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.viewer:
        return 'View Only';
    }
  }
}
