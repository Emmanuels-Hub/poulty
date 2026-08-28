import 'dart:math';

import '../../core/constants/enums.dart';
import '../../data/models/device_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/telemetry_model.dart';

class SimulationService {
  SimulationService();

  final _random = Random();
  double _tempBase = 31.5;
  double _humidityBase = 62;
  double _ammoniaBase = 12;
  double _feedLevel = 78;
  double _waterLevel = 85;
  double _battery = 92;
  bool _isDaytime = true;
  OperatingMode _mode = OperatingMode.automatic;
  PoultryStage _stage = PoultryStage.starter;
  final Map<SensorType, DataSource> _sensorSources = {
    for (final s in SensorType.values) s: DataSource.live,
  };
  final Map<ActuatorType, bool> _actuators = {
    ActuatorType.ventilationFan: false,
    ActuatorType.heatLamp: true,
    ActuatorType.lighting: true,
  };
  final Map<ActuatorType, bool> _failures = {
    ActuatorType.ventilationFan: false,
    ActuatorType.heatLamp: false,
    ActuatorType.lighting: false,
  };

  int _tick = 0;

  void setMode(OperatingMode mode) => _mode = mode;
  void setStage(PoultryStage stage) => _stage = stage;

  void setSensorSource(SensorType sensor, DataSource source) {
    _sensorSources[sensor] = source;
  }

  void setActuator(ActuatorType type, bool isOn) {
    _actuators[type] = isOn;
  }

  void setActuatorFailure(ActuatorType type, bool hasFailure) {
    _failures[type] = hasFailure;
  }

  void injectSensorValue(SensorType sensor, double value) {
    switch (sensor) {
      case SensorType.temperature:
        _tempBase = value;
      case SensorType.humidity:
        _humidityBase = value;
      case SensorType.ammonia:
        _ammoniaBase = value;
      case SensorType.feedLevel:
        _feedLevel = value;
      case SensorType.waterLevel:
        _waterLevel = value;
      case SensorType.battery:
        _battery = value;
      case SensorType.ambientLight:
        _isDaytime = value > 50;
    }
  }

  TelemetrySnapshot generate({DeviceModel? device, AppSettings? settings}) {
    _tick++;
    _driftValues(settings);

    if (_mode == OperatingMode.automatic || _mode == OperatingMode.hybrid) {
      _applyAutomaticControl(settings);
    }

    final now = DateTime.now();
    final lux = _isDaytime ? 450 + _random.nextDouble() * 200 : 5 + _random.nextDouble() * 10;

    return TelemetrySnapshot(
      timestamp: now,
      temperatureC: _resolveSensor(SensorType.temperature, _tempBase),
      humidityPercent: _resolveSensor(SensorType.humidity, _humidityBase),
      ammoniaPpm: _resolveSensor(SensorType.ammonia, _ammoniaBase),
      isDaytime: _isDaytime,
      ambientLightLux: _resolveSensor(SensorType.ambientLight, lux),
      feedLevelPercent: _resolveSensor(SensorType.feedLevel, _feedLevel),
      waterLevelPercent: _resolveSensor(SensorType.waterLevel, _waterLevel),
      batteryPercent: _resolveSensor(SensorType.battery, _battery),
      operatingMode: _mode,
      poultryStage: _stage,
      actuators: ActuatorType.values
          .map(
            (type) => ActuatorState(
              type: type,
              isOn: _actuators[type] ?? false,
              hasFailure: _failures[type] ?? false,
            ),
          )
          .toList(),
      sensorSources: {
        for (final entry in _sensorSources.entries)
          entry.key.name: entry.value.name,
      },
      uptimeSeconds: _tick * 5,
      wifiRssi: -45 - _random.nextInt(20),
      deviceId: device?.id ?? 'simulated',
    );
  }

  double _resolveSensor(SensorType sensor, double liveValue) {
    if (_sensorSources[sensor] == DataSource.simulated) {
      return _simulatedValue(sensor);
    }
    return liveValue + (_random.nextDouble() - 0.5) * _noise(sensor);
  }

  double _noise(SensorType sensor) {
    switch (sensor) {
      case SensorType.temperature:
        return 0.4;
      case SensorType.humidity:
        return 1.2;
      case SensorType.ammonia:
        return 0.8;
      case SensorType.ambientLight:
        return 20;
      default:
        return 0.5;
    }
  }

  double _simulatedValue(SensorType sensor) {
    switch (sensor) {
      case SensorType.temperature:
        return 30 + _random.nextDouble() * 4;
      case SensorType.humidity:
        return 55 + _random.nextDouble() * 10;
      case SensorType.ammonia:
        return 8 + _random.nextDouble() * 8;
      case SensorType.ambientLight:
        return _isDaytime ? 500 : 8;
      case SensorType.feedLevel:
        return 60 + _random.nextDouble() * 30;
      case SensorType.waterLevel:
        return 70 + _random.nextDouble() * 25;
      case SensorType.battery:
        return 80 + _random.nextDouble() * 15;
    }
  }

  void _driftValues(AppSettings? settings) {
    _tempBase += (_random.nextDouble() - 0.5) * 0.3;
    _humidityBase += (_random.nextDouble() - 0.5) * 0.8;
    _ammoniaBase += (_random.nextDouble() - 0.5) * 0.5;
    _feedLevel = (_feedLevel - 0.05).clamp(0, 100);
    _waterLevel = (_waterLevel - 0.03).clamp(0, 100);
    _battery = (_battery - 0.01).clamp(0, 100);

    final hour = DateTime.now().hour;
    _isDaytime = hour >= 6 && hour < 20;

    if (_tick % 60 == 0 && _random.nextBool()) {
      _tempBase += _random.nextBool() ? 3 : -3;
    }
  }

  void _applyAutomaticControl(AppSettings? settings) {
    final thresholds = settings?.thresholdsFor(_stage) ?? StageThresholds(stage: _stage);

    _actuators[ActuatorType.ventilationFan] =
        _tempBase > thresholds.tempMax || _ammoniaBase > thresholds.ammoniaMax;
    _actuators[ActuatorType.heatLamp] = _tempBase < thresholds.tempMin;
    _actuators[ActuatorType.lighting] = !_isDaytime;
  }
}
