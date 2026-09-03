import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks rules that live in the firmware but that the app depends on.
///
/// These parse esp/Smart_Poultry/Smart_Poultry.ino directly. They cannot
/// replace flashing the board, but they do catch a regression that is
/// otherwise only visible as "the hardware ignores me" on the bench.
void main() {
  late String firmware;

  setUpAll(() {
    final file = File('esp/Smart_Poultry/Smart_Poultry.ino');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'firmware sketch not found at ${file.path}',
    );

    // The sketch is CRLF on Windows; every structural match below assumes
    // bare newlines.
    firmware = file.readAsStringSync().replaceAll('\r\n', '\n');
  });

  String functionBody(String signature) {
    final start = firmware.indexOf(signature);
    expect(start, greaterThan(-1), reason: 'missing $signature');
    final end = firmware.indexOf('\n}\n', start);
    expect(end, greaterThan(start), reason: 'unterminated $signature');
    return firmware.substring(start, end);
  }

  group('Critical temperature safety', () {
    test('acts on the real reading, never the simulated one', () {
      final body = functionBody('void applyCriticalSafety()');

      // Must read temperatureC (real), not effTemperatureC (possibly injected).
      expect(body, contains('temperatureC >= TEMP_CRITICAL_HIGH'));
      expect(body, isNot(contains('effTemperatureC')));
    });

    test('forces fan on and lamp off when critically hot', () {
      final body = functionBody('void applyCriticalSafety()');
      expect(body, contains('fanOn = true'));
      expect(body, contains('heatLampOn = false'));
    });

    // The regression this guards: TEMP_CRITICAL_LOW is 30C, below any normal
    // room, so a cold branch here fires on every cycle on a bench. It cleared
    // fanManual and heatLampManual, silently undoing every manual command and
    // making Manual mode look completely dead. The cold response belongs in
    // applyAutomaticControl(), where the operator is not in charge.
    test('does NOT act on cold, which would wipe manual overrides', () {
      final body = functionBody('void applyCriticalSafety()');
      expect(
        body,
        isNot(contains('TEMP_CRITICAL_LOW')),
        reason: 'a cold branch here re-breaks Manual mode at room temperature',
      );
    });

    test('the cold response lives in automatic control instead', () {
      final body = functionBody('void applyAutomaticControl()');
      expect(body, contains('TEMP_CRITICAL_LOW'));

      // And automatic control only runs when the controller owns the relays.
      expect(body, contains('operatingMode !='));
      expect(body, contains('MODE_AUTOMATIC'));
    });
  });

  group('Gas sensor fault handling', () {
    test('a floor is defined, so raw 0 is not read as clean air', () {
      expect(firmware, contains('#define GAS_MIN_VALID_ADC'));
    });

    test('readAirPurity bails out below the floor', () {
      final body = functionBody('void readAirPurity()');
      expect(body, contains('raw <= GAS_MIN_VALID_ADC'));
      expect(body, contains('airPuritySensorOk = false'));
    });

    test('a faulty sensor does not drive the fan', () {
      final body = functionBody('void applyAutomaticControl()');
      expect(body, contains('airPuritySensorOk'));
    });

    test('the fault is reported to the app', () {
      expect(firmware, contains('airPurityOk'));
    });
  });

  group('Manual control', () {
    test('is only accepted while in Manual mode', () {
      final body = functionBody('void handleSetActuator(');
      expect(body, contains('operatingMode !='));
      expect(body, contains('MODE_MANUAL'));
    });

    test('sets an override flag and an expiry for both actuators', () {
      final body = functionBody('void handleSetActuator(');
      expect(body, contains('fanManual'));
      expect(body, contains('fanManualUntil'));
      expect(body, contains('heatLampManual'));
      expect(body, contains('heatLampManualUntil'));
    });
  });

  group('BLE identifiers still match the app', () {
    test('service and characteristic UUIDs are complete', () {
      // A short UUID is invisible until the app fails to find the
      // characteristic on a connection that otherwise succeeded.
      final uuids = RegExp(r'"([0-9a-f]{8}-[0-9a-f-]+)"')
          .allMatches(firmware)
          .map((m) => m.group(1)!)
          .toSet();

      expect(uuids, contains('6e400001-b5a3-f393-e0a9-e50e24dcca9e'));
      expect(uuids, contains('6e400002-b5a3-f393-e0a9-e50e24dcca9e'));
      expect(uuids, contains('6e400003-b5a3-f393-e0a9-e50e24dcca9e'));

      for (final uuid in uuids) {
        expect(uuid.length, 36, reason: 'truncated UUID: $uuid');
      }
    });

    test('the telemetry buffer fits a worst-case frame', () {
      // The longest frame is ~680 bytes with every category string at its
      // maximum. A truncated frame loses its newline and never parses.
      final match = RegExp(r'char buffer\[(\d+)\]').firstMatch(firmware);
      expect(match, isNotNull);
      expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(800));
    });
  });
}
