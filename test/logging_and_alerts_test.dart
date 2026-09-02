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

TelemetrySnapshot _snap({
  double temperature = 33,
  double humidity = 60,
  double airPurity = 90,
  double feed = 70,
  double water = 80,
}) {
  return TelemetrySnapshot(
    timestamp: DateTime.now(),
    temperatureC: temperature,
    humidityPercent: humidity,
    airPurityPercent: airPurity,
    feedLevelPercent: feed,
    waterLevelPercent: water,
  );
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

  group('History logging', () {
    test('logs the first reading immediately, then buffers', () {
      final history = HistoryService(storage)..load();

      // Charts would otherwise sit blank for a whole interval after launch.
      expect(history.record(_snap(temperature: 30)), isTrue);

      // Telemetry arrives every ~3s; those readings accumulate rather than
      // writing a point (and rewriting the series) each time.
      expect(history.record(_snap(temperature: 40)), isFalse);
      expect(history.record(_snap(temperature: 50)), isFalse);

      expect(history.series('temperature'), hasLength(1));
      expect(history.series('temperature').single.value, 30);
    });

    test('logs every parameter on one shared timestamp', () {
      final history = HistoryService(storage)..load();
      history.record(_snap());

      final stamps = historyParameters
          .map((p) => history.series(p.key).single.timestamp)
          .toSet();

      // One timestamp across all series is what lets the CSV be one row per
      // reading rather than a sparse table.
      expect(stamps, hasLength(1));
    });

    test('summarises a series', () {
      final history = HistoryService(storage)..load();
      history.record(_snap(temperature: 33));

      final stats = history.stats('temperature');
      expect(stats.count, 1);
      expect(stats.min, 33);
      expect(stats.max, 33);
      expect(stats.average, 33);
    });

    test('an empty series summarises to zero rather than throwing', () {
      final history = HistoryService(storage)..load();
      expect(history.stats('temperature').count, 0);
      expect(history.isEmpty, isTrue);
    });

    test('CSV is one header plus one row per reading', () {
      final history = HistoryService(storage)..load();
      history.record(_snap(temperature: 33));

      final lines = history.toCsv().trim().split('\n');
      final expectedHeader =
          'timestamp,${historyParameters.map((p) => p.csvColumn).join(',')}'
          ',simulated';

      expect(lines.first, expectedHeader);
      expect(lines, hasLength(2));

      // timestamp + one column per parameter + the simulated flag
      expect(lines[1].split(',').length, historyParameters.length + 2);
      expect(lines[1], contains('33.0'));
    });

    test('survives a round trip through storage', () async {
      final writer = HistoryService(storage)..load();
      writer.record(_snap(temperature: 31));
      await writer.flush();

      final reader = HistoryService(storage)..load();
      expect(reader.series('temperature'), hasLength(1));
      expect(reader.series('temperature').single.value, 31);
    });
  });

  group('Alert severity', () {
    test('a comfortable reading raises nothing', () {
      final alerts = AlertService(storage);
      alerts.evaluate(_snap(), AppSettings.defaults());
      expect(alerts.takePendingNotifications(), isEmpty);
    });

    test('escalates from warning to critical past the second limit', () {
      // 36C: outside the 32-35 comfort band, inside the 30-37 critical band.
      final warning = AlertService(storage);
      warning.evaluate(_snap(temperature: 36), AppSettings.defaults());
      final warned = warning.takePendingNotifications();
      expect(warned, hasLength(1));
      expect(warned.single.type, AlertType.abnormalTemperature);
      expect(warned.single.severity, AlertSeverity.warning);

      // 40C: past the critical limit.
      final critical = AlertService(storage);
      critical.evaluate(_snap(temperature: 40), AppSettings.defaults());
      expect(
        critical.takePendingNotifications().single.severity,
        AlertSeverity.critical,
      );
    });

    test('poor air purity is judged against the shared threshold', () {
      final alerts = AlertService(storage);
      alerts.evaluate(_snap(airPurity: 30), AppSettings.defaults());

      final raised = alerts.takePendingNotifications();
      expect(raised.single.type, AlertType.poorAirPurity);
      expect(raised.single.severity, AlertSeverity.critical);
    });

    test('reports a recovery once, so the notification is withdrawn once', () {
      final alerts = AlertService(storage);

      alerts.evaluate(_snap(temperature: 40), AppSettings.defaults());
      alerts.takePendingNotifications();

      alerts.evaluate(_snap(temperature: 33), AppSettings.defaults());
      expect(
        alerts.takePendingClears(),
        contains(AlertType.abnormalTemperature),
      );

      alerts.evaluate(_snap(temperature: 33), AppSettings.defaults());
      expect(alerts.takePendingClears(), isEmpty);
    });

    test('does not re-raise a standing alert on every frame', () {
      final alerts = AlertService(storage);

      alerts.evaluate(_snap(temperature: 40), AppSettings.defaults());
      expect(alerts.takePendingNotifications(), hasLength(1));

      // The condition persists, but the notification interval has not elapsed,
      // so the phone is not buzzed again three seconds later.
      alerts.evaluate(_snap(temperature: 40), AppSettings.defaults());
      expect(alerts.takePendingNotifications(), isEmpty);
    });
  });
}
