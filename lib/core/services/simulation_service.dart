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

  void setMode(OperatingMode mode) => _mode = mode;

  void setActuator(ActuatorType type, bool isOn) {
    _actuators[type] = isOn;
  }

  TelemetrySnapshot generate({DeviceModel? device, AppSettings? settings}) {
    _tick++;
    _drift();

    if (_mode == OperatingMode.automatic) {
      _applyAutomaticControl(settings?.thresholds ?? StageThresholds.starter);
    }

    return TelemetrySnapshot(
      timestamp: DateTime.now(),
      temperatureC: _jitter(_tempBase, 0.4),
      humidityPercent: _jitter(_humidityBase, 1.2),
      airPurityPercent: _jitter(_airPurityBase, 1.5).clamp(0, 100),
      feedLevelPercent: _feedLevel,
      waterLevelPercent: _waterLevel,
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

  void _applyAutomaticControl(StageThresholds thresholds) {
    _actuators[ActuatorType.ventilationFan] =
        _tempBase > thresholds.tempMax ||
            _airPurityBase < thresholds.airPurityMin;
    _actuators[ActuatorType.heatLamp] = _tempBase < thresholds.tempMin;
  }
}
