import '../../core/constants/enums.dart';

class EnumLabels {
  EnumLabels._();

  static String operatingMode(OperatingMode mode) {
    switch (mode) {
      case OperatingMode.automatic:
        return 'Automatic';
      case OperatingMode.manual:
        return 'Manual';
    }
  }

  static String poultryStage(PoultryStage stage) {
    switch (stage) {
      case PoultryStage.starter:
        return 'Starter';
    }
  }

  static String actuator(ActuatorType type) {
    switch (type) {
      case ActuatorType.ventilationFan:
        return 'Ventilation Fan';
      case ActuatorType.heatLamp:
        return 'Heat Lamp';
    }
  }

  static String sensor(SensorType type) {
    switch (type) {
      case SensorType.temperature:
        return 'Temperature';
      case SensorType.humidity:
        return 'Humidity';
      case SensorType.airPurity:
        return 'Air Purity';
      case SensorType.feedLevel:
        return 'Feed Level';
      case SensorType.waterLevel:
        return 'Water Level';
    }
  }

  static String connectionStatus(DeviceConnectionStatus status) {
    switch (status) {
      case DeviceConnectionStatus.connected:
        return 'Connected';
      case DeviceConnectionStatus.connecting:
        return 'Connecting';
      case DeviceConnectionStatus.disconnected:
        return 'Disconnected';
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
