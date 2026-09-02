import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poulty/core/constants/enums.dart';
import 'package:poulty/data/models/telemetry_model.dart';

/// Guards the wire format shared with esp/Smart_Poultry/Smart_Poultry.ino.
///
/// A mismatch here is invisible at compile time and shows up on the bench as
/// "the phone connects but the app sees nothing", which is exactly the bug
/// that a short UUID caused.
void main() {
  group('Simulated sensor bitmask', () {
    test('bit order matches the SIM_* defines in the firmware', () {
      expect(simulationBits[SensorType.temperature], 0);
      expect(simulationBits[SensorType.humidity], 1);
      expect(simulationBits[SensorType.airPurity], 2);
      expect(simulationBits[SensorType.feedLevel], 3);
      expect(simulationBits[SensorType.waterLevel], 4);
    });

    test('round-trips', () {
      const sensors = {SensorType.temperature, SensorType.airPurity};
      expect(encodeSimulatedMask(sensors), 0x05);
      expect(decodeSimulatedMask(0x05), sensors);
      expect(decodeSimulatedMask(0), isEmpty);
      expect(decodeSimulatedMask(31).length, SensorType.values.length);
    });
  });

  group('Telemetry frame', () {
    // Taken from buildTelemetryJson() in the sketch, including the reporting
    // fields the app does not model.
    const frame = '{"temperatureC":33.4,"humidityPercent":62.0,'
        '"airPurityPercent":88.0,"feedLevelPercent":78.0,'
        '"waterLevelPercent":85.0,"operatingMode":"automatic",'
        '"poultryStage":"starter","simulationMode":true,'
        '"simulatedMask":5,"temperatureCategory":"NORMAL",'
        '"humidityCategory":"NORMAL","airPurityCategory":"NORMAL",'
        '"feedStatus":"FULL","waterStatus":"FULL",'
        '"feedRefillNeeded":false,"waterRefillNeeded":false,'
        '"actuators":[{"type":"ventilationFan","isOn":true,'
        '"isManualOverride":false,"hasFailure":false},'
        '{"type":"heatLamp","isOn":false,"isManualOverride":false,'
        '"hasFailure":false}],"deviceId":"SmartPoultry-Coop"}';

    test('parses, ignoring fields the app does not model', () {
      final snapshot = TelemetrySnapshot.fromJson(
        jsonDecode(frame) as Map<String, dynamic>,
      );

      expect(snapshot.temperatureC, 33.4);
      expect(snapshot.humidityPercent, 62.0);
      expect(snapshot.airPurityPercent, 88.0);
      expect(snapshot.feedLevelPercent, 78.0);
      expect(snapshot.waterLevelPercent, 85.0);
      expect(snapshot.operatingMode, OperatingMode.automatic);
      expect(snapshot.poultryStage, PoultryStage.starter);
      expect(snapshot.actuator(ActuatorType.ventilationFan).isOn, isTrue);
      expect(snapshot.actuator(ActuatorType.heatLamp).isOn, isFalse);
    });

    test('reports which individual sensors are simulated', () {
      final snapshot = TelemetrySnapshot.fromJson(
        jsonDecode(frame) as Map<String, dynamic>,
      );

      expect(snapshot.simulationMode, isTrue);
      expect(snapshot.isSimulated(SensorType.temperature), isTrue);
      expect(snapshot.isSimulated(SensorType.airPurity), isTrue);
      expect(snapshot.isSimulated(SensorType.humidity), isFalse);
    });

    test('is stamped locally, because the controller has no clock', () {
      final snapshot = TelemetrySnapshot.fromJson(
        jsonDecode(frame) as Map<String, dynamic>,
      );

      expect(
        snapshot.timestamp.difference(DateTime.now()).abs().inSeconds,
        lessThan(5),
      );
    });

    test('a frame without simulation fields defaults to not simulating', () {
      final snapshot = TelemetrySnapshot.fromJson(
        jsonDecode('{"temperatureC":30.0}') as Map<String, dynamic>,
      );

      expect(snapshot.simulationMode, isFalse);
      expect(snapshot.simulatedSensors, isEmpty);
    });
  });
}
