import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:poulty/core/constants/enums.dart';
import 'package:poulty/core/services/alert_service.dart';
import 'package:poulty/core/services/history_service.dart';
import 'package:poulty/core/services/local_storage_service.dart';
import 'package:poulty/data/models/settings_model.dart';
import 'package:poulty/data/models/telemetry_model.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationSupportPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getLibraryPath() async => Directory.systemTemp.path;
}

void main() {
  late LocalStorageService storage;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    storage = LocalStorageService.instance;
    await storage.init();
    await storage.saveNotifications(const []);
    await HistoryService(storage).clear();
  });

  group('No-data snapshot', () {
    test('reads zero across every sensor, with actuators off', () {
      final snapshot = TelemetrySnapshot.noData();

      expect(snapshot.temperatureC, 0);
      expect(snapshot.humidityPercent, 0);
      expect(snapshot.airPurityPercent, 0);
      expect(snapshot.feedLevelPercent, 0);
      expect(snapshot.waterLevelPercent, 0);

      for (final type in ActuatorType.values) {
        expect(snapshot.actuator(type).isOn, isFalse);
      }
    });

    test('is not marked as simulated', () {
      // Zeros are the absence of a reading, not injected values.
      expect(TelemetrySnapshot.noData().simulationMode, isFalse);
      expect(TelemetrySnapshot.noData().simulatedSensors, isEmpty);
    });

    // This is the trap the zeros change creates: every zero sits outside its
    // comfort band, so feeding one to the alert engine would raise four
    // simultaneous alerts about a coop nobody is measuring. The controller
    // must never evaluate a no-data snapshot -- these assertions document
    // exactly why.
    test('would raise a storm of false alerts if it were ever evaluated', () {
      final alerts = AlertService(storage);
      alerts.evaluate(TelemetrySnapshot.noData(), AppSettings.defaults());

      final raised = alerts.takePendingNotifications();
      expect(
        raised.map((n) => n.type),
        containsAll(<AlertType>[
          AlertType.abnormalTemperature,
          AlertType.poorAirPurity,
          AlertType.lowFeed,
          AlertType.lowWater,
        ]),
      );
    });
  });

  group('Standing alerts stand down when telemetry stops', () {
    test('deactivateAll clears active alerts and reports them', () async {
      final alerts = AlertService(storage);

      alerts.evaluate(
        TelemetrySnapshot(timestamp: DateTime.now(), temperatureC: 45),
        AppSettings.defaults(),
      );
      expect(alerts.takePendingNotifications(), isNotEmpty);

      await alerts.deactivateAll();

      // The cleared type is reported so its OS notification is withdrawn.
      expect(
        alerts.takePendingClears(),
        contains(AlertType.abnormalTemperature),
      );

      // Nothing is left active.
      final stored = storage.getNotifications();
      expect(stored.where((n) => n.isActive), isEmpty);
    });

    test('is a no-op when nothing is active', () async {
      final alerts = AlertService(storage);
      await alerts.deactivateAll();
      expect(alerts.takePendingClears(), isEmpty);
    });
  });

  group('Simulated readings are marked in the log', () {
    TelemetrySnapshot snap({bool simulated = false}) => TelemetrySnapshot(
          timestamp: DateTime.now(),
          temperatureC: 33,
          humidityPercent: 60,
          airPurityPercent: 90,
          feedLevelPercent: 70,
          waterLevelPercent: 80,
          simulationMode: simulated,
        );

    test('a point recorded during a session is flagged', () {
      final history = HistoryService(storage)..load();
      history.record(snap(simulated: true));

      expect(history.series('temperature').single.simulated, isTrue);
    });

    test('an ordinary point is not', () {
      final history = HistoryService(storage)..load();
      history.record(snap());

      expect(history.series('temperature').single.simulated, isFalse);
    });

    test('the CSV carries a simulated column', () {
      final history = HistoryService(storage)..load();
      history.record(snap(simulated: true));

      final lines = history.toCsv().trim().split('\n');
      expect(lines.first.split(',').last, 'simulated');
      expect(lines[1].split(',').last, 'true');
    });

    test('the flag survives a round trip through storage', () async {
      final writer = HistoryService(storage)..load();
      writer.record(snap(simulated: true));
      await writer.flush();

      final reader = HistoryService(storage)..load();
      expect(reader.series('temperature').single.simulated, isTrue);
    });
  });

  group('Defaults', () {
    test('generated demo data is off, so zeros are what you get', () {
      expect(AppSettings.defaults().useDemoDataWhenDisconnected, isFalse);
    });

    test('settings written before this change also default it off', () {
      final restored = AppSettings.fromJson(const {'themeMode': 'system'});
      expect(restored.useDemoDataWhenDisconnected, isFalse);
    });
  });
}
