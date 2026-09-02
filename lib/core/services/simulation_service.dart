import 'dart:math';

import '../../data/models/device_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/telemetry_model.dart';
import '../constants/enums.dart';

/// Generates plausible readings so the app stays usable while no ESP32 is
/// connected over BLE.
class SimulationService {
  SimulationService();

  final _random = Random();
  double _tempBase = 33.5;
  double _humidityBase = 62;
  double _airPurityBase = 88;
  double _feedLevel = 78;
  double _waterLevel = 85;
  OperatingMode _mode = OperatingMode.automatic;
  final Map<ActuatorType, bool> _actuators = {
    ActuatorType.ventilationFan: false,
    ActuatorType.heatLamp: true,
  };

  int _tick = 0;

  bool _simulationActive = false;
  final Map<SensorType, double> _injected = {};

  bool get isSimulationActive => _simulationActive;

  Set<SensorType> get simulatedSensors =>
      _simulationActive ? _injected.keys.toSet() : const {};

  void setMode(OperatingMode mode) => _mode = mode;

  void setSimulationActive(bool active) {
    _simulationActive = active;
    if (!active) _injected.clear();
  }

  /// Pins a sensor to [value] so the demo actuators respond to it, mirroring
  /// what the firmware does with a real controller attached.
  void injectSensorValue(SensorType sensor, double value) {
    _injected[sensor] = value;
  }

  void clearSensorValue(SensorType sensor) {
    _injected.remove(sensor);
  }

  double _effective(SensorType sensor, double real) {
    if (!_simulationActive) return real;
    return _injected[sensor] ?? real;
  }

  void setActuator(ActuatorType type, bool isOn) {
    _actuators[type] = isOn;
  }

  TelemetrySnapshot generate({DeviceModel? device, AppSettings? settings}) {
    _tick++;
    _drift();

    // Injected values replace the drifting ones, so the control logic below
    // reacts to them exactly as the firmware would.
    final temperature =
        _effective(SensorType.temperature, _jitter(_tempBase, 0.4));
    final humidity =
        _effective(SensorType.humidity, _jitter(_humidityBase, 1.2));
    final airPurity = _effective(
      SensorType.airPurity,
      _jitter(_airPurityBase, 1.5).clamp(0, 100),
    );
    final feed = _effective(SensorType.feedLevel, _feedLevel);
    final water = _effective(SensorType.waterLevel, _waterLevel);

    if (_mode == OperatingMode.automatic) {
      _applyAutomaticControl(
        settings?.thresholds ?? StageThresholds.starter,
        temperature: temperature,
        humidity: humidity,
        airPurity: airPurity,
      );
    }

    return TelemetrySnapshot(
      timestamp: DateTime.now(),
      temperatureC: temperature,
      humidityPercent: humidity,
      airPurityPercent: airPurity,
      feedLevelPercent: feed,
      waterLevelPercent: water,
      operatingMode: _mode,
      poultryStage: PoultryStage.starter,
      actuators: ActuatorType.values
          .map(
            (type) => ActuatorState(
              type: type,
              isOn: _actuators[type] ?? false,
              isManualOverride: _mode == OperatingMode.manual,
            ),
          )
          .toList(),
      deviceId: device?.id ?? 'demo',
      simulationMode: _simulationActive,
      simulatedSensors: simulatedSensors,
    );
  }

  double _jitter(double base, double amplitude) =>
      base + (_random.nextDouble() - 0.5) * amplitude;

  void _drift() {
    _tempBase += (_random.nextDouble() - 0.5) * 0.3;
    _humidityBase += (_random.nextDouble() - 0.5) * 0.8;
    _airPurityBase =
        (_airPurityBase + (_random.nextDouble() - 0.5) * 1.2).clamp(35, 100);
    _feedLevel = (_feedLevel - 0.05).clamp(0, 100);
    _waterLevel = (_waterLevel - 0.03).clamp(0, 100);

    if (_tick % 60 == 0 && _random.nextBool()) {
      _tempBase += _random.nextBool() ? 2 : -2;
    }
  }

  /// Mirrors applyAutomaticControl() in the firmware, including the humidity
  /// trigger on the fan, so the demo behaves like the real controller.
  void _applyAutomaticControl(
    StageThresholds thresholds, {
    required double temperature,
    required double humidity,
    required double airPurity,
  }) {
    _actuators[ActuatorType.ventilationFan] =
        temperature > thresholds.tempMax ||
            humidity > thresholds.humidityMax ||
            airPurity < thresholds.airPurityMin;

    _actuators[ActuatorType.heatLamp] = temperature < thresholds.tempMin;
  }
}
