import 'dart:typed_data';

import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/services/esp32_api_service.dart';
import '../../core/services/simulation_service.dart';
import '../../modules/telemetry/telemetry_controller.dart';

class DiagnosticsController extends GetxController {
  DiagnosticsController(this._api, this._telemetry, this._simulation);

  final Esp32ApiService _api;
  final TelemetryController _telemetry;
  final SimulationService _simulation;

  final RxBool isTestingActuator = false.obs;
  final RxString lastTestResult = ''.obs;
  final RxMap<SensorType, double> simulatedValues = <SensorType, double>{}.obs;

  bool get canControl => _telemetry.canControl;

  Future<void> testActuator(ActuatorType type) async {
    if (!canControl) return;
    isTestingActuator.value = true;
    lastTestResult.value = 'Testing ${type.name}...';

    try {
      await _api.testActuator(type);
      lastTestResult.value = '${type.name} test completed successfully';
    } catch (e) {
      lastTestResult.value = '${type.name} test failed: $e';
    } finally {
      isTestingActuator.value = false;
      await _telemetry.refreshNow();
    }
  }

  void setSimulatedValue(SensorType sensor, double value) {
    simulatedValues[sensor] = value;
    _simulation.injectSensorValue(sensor, value);
    _telemetry.refreshNow();
  }

  Future<void> simulateActuatorFailure(ActuatorType type, bool failure) async {
    _simulation.setActuatorFailure(type, failure);
    await _telemetry.refreshNow();
  }

  Future<void> triggerSystemRestartAlert() async {
    await _telemetry.refreshNow();
  }
}

