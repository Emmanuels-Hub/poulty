import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:poulty/core/constants/app_constants.dart';
import 'package:poulty/core/constants/enums.dart';
import 'package:poulty/core/services/auth_service.dart';
import 'package:poulty/core/services/local_storage_service.dart';
import 'package:poulty/data/models/event_model.dart';
import 'package:poulty/data/models/telemetry_model.dart';
import 'package:poulty/data/models/user_model.dart';
import 'package:poulty/modules/auth/auth_controller.dart';

/// Test files run in parallel processes against the same filesystem, so each
/// gets its own directory: sharing one makes them fight over Hive's lock.
final Directory _testDir = Directory.systemTemp.createTempSync('poulty_test_');

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return _testDir.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return _testDir.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return _testDir.path;
  }

  @override
  Future<String?> getLibraryPath() async {
    return _testDir.path;
  }
}

void main() {
  test('AppConstants defines app name', () {
    expect(AppConstants.appName, 'Smart Poultry');
  });

  test('Password hashing is deterministic', () {
    String hash(String input) {
      return sha256.convert(utf8.encode(input)).toString();
    }

    expect(hash('test123'), hash('test123'));
    expect(hash('test123'), isNot(equals('test123')));
  });

  test('AuthController exposes the stored user list for the users page', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _FakePathProviderPlatform();

    final storage = LocalStorageService.instance;
    await storage.init();
    await storage.seedDefaultUsersIfEmpty();

    // onInit() is skipped on purpose: session restore reaches for
    // flutter_secure_storage, which has no implementation under `flutter test`.
    final controller = AuthController(AuthService(storage), storage);

    expect(controller.users, isA<List<UserModel>>());
    expect(controller.users.length, greaterThan(0));
  });

  group('Records written by an older schema decode instead of throwing', () {
    test('SystemEvent falls back for a dropped EventCategory', () {
      final event = SystemEvent.fromJson({
        'id': 'e1',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        // 'network' was renamed to 'connection'.
        'category': 'network',
        'message': 'Connection restored',
      });

      expect(event.category, EventCategory.system);
      expect(event.message, 'Connection restored');
    });

    test('AppNotification falls back for a dropped AlertType', () {
      final notification = AppNotification.fromJson({
        'id': 'n1',
        // 'abnormalAmmonia' was replaced by 'poorAirPurity'.
        'type': 'abnormalAmmonia',
        'severity': 'critical',
        'title': 'High Ammonia Level',
        'message': 'Ammonia is 30 ppm',
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
      });

      expect(notification.type, AlertType.custom);
      expect(notification.severity, AlertSeverity.critical);
    });

    test('TelemetrySnapshot falls back for dropped modes and actuators', () {
      final snapshot = TelemetrySnapshot.fromJson({
        'timestamp': DateTime(2026, 1, 1).toIso8601String(),
        'temperatureC': 33.2,
        // 'simulation'/'grower' are gone; 'lighting' actuator was removed.
        'operatingMode': 'simulation',
        'poultryStage': 'grower',
        'actuators': [
          {'type': 'lighting', 'isOn': true},
        ],
      });

      expect(snapshot.operatingMode, OperatingMode.automatic);
      expect(snapshot.poultryStage, PoultryStage.starter);
      expect(snapshot.temperatureC, 33.2);
      expect(snapshot.actuators.single.type, ActuatorType.ventilationFan);
    });
  });
}
