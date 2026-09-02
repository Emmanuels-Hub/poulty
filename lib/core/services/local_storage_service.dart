import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../constants/enums.dart';
import '../utils/json_utils.dart';
import '../../data/models/device_model.dart';
import '../../data/models/event_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/models/user_model.dart';

class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  final _secureStorage = const FlutterSecureStorage();
  final _uuid = const Uuid();

  Box<dynamic>? _settingsBox;
  Box<dynamic>? _telemetryBox;
  Box<dynamic>? _eventsBox;
  Box<dynamic>? _notificationsBox;
  Box<dynamic>? _usersBox;
  Box<dynamic>? _devicesBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _settingsBox = await Hive.openBox(AppConstants.hiveBoxSettings);
    _telemetryBox = await Hive.openBox(AppConstants.hiveBoxTelemetry);
    _eventsBox = await Hive.openBox(AppConstants.hiveBoxEvents);
    _notificationsBox = await Hive.openBox(AppConstants.hiveBoxNotifications);
    _usersBox = await Hive.openBox(AppConstants.hiveBoxUsers);
    _devicesBox = await Hive.openBox(AppConstants.hiveBoxDevices);
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> seedDefaultUsersIfEmpty() async {
    if (_usersBox!.isNotEmpty) return;

    final defaults = [
      UserModel(
        id: _uuid.v4(),
        username: 'admin',
        displayName: 'Primary Admin',
        passwordHash: hashPassword('admin123'),
        role: UserRole.admin,
        createdAt: DateTime.now(),
      ),
      UserModel(
        id: _uuid.v4(),
        username: 'admin2',
        displayName: 'Secondary Admin',
        passwordHash: hashPassword('admin123'),
        role: UserRole.admin,
        createdAt: DateTime.now(),
      ),
      UserModel(
        id: _uuid.v4(),
        username: 'viewer',
        displayName: 'Farm Viewer',
        passwordHash: hashPassword('viewer123'),
        role: UserRole.viewer,
        createdAt: DateTime.now(),
      ),
    ];

    for (final user in defaults) {
      await _usersBox!.put(user.id, user.toJson());
    }
  }

  Future<void> seedDefaultDeviceIfEmpty() async {
    if (_devicesBox!.isNotEmpty) return;

    final device = DeviceModel(
      id: _uuid.v4(),
      name: 'Coop Controller',
      firmwareVersion: '1.0.0',
    );
    await _devicesBox!.put(device.id, device.toJson());
  }

  AppSettings getSettings() {
    final raw = _settingsBox!.get('app_settings');
    if (raw == null) {
      final defaults = AppSettings.defaults();
      saveSettings(defaults);
      return defaults;
    }
    try {
      return AppSettings.fromJson(asJsonMap(raw));
    } catch (_) {
      final defaults = AppSettings.defaults();
      saveSettings(defaults);
      return defaults;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _settingsBox!.put('app_settings', settings.toJson());
  }

  List<UserModel> getUsers() {
    return parseAll(
      _usersBox!.values.map(asJsonMap).toList(),
      UserModel.fromJson,
    );
  }

  Future<void> saveUser(UserModel user) async {
    await _usersBox!.put(user.id, user.toJson());
  }

  Future<void> deleteUser(String id) async {
    await _usersBox!.delete(id);
  }

  List<DeviceModel> getDevices() {
    return parseAll(
      _devicesBox!.values.map(asJsonMap).toList(),
      DeviceModel.fromJson,
    );
  }

  Future<void> saveDevice(DeviceModel device) async {
    await _devicesBox!.put(device.id, device.toJson());
  }

  Future<void> deleteDevice(String id) async {
    await _devicesBox!.delete(id);
  }

  TelemetrySnapshot? getLatestTelemetry() {
    final raw = _telemetryBox!.get('latest');
    if (raw == null) return null;
    try {
      return TelemetrySnapshot.fromJson(asJsonMap(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLatestTelemetry(TelemetrySnapshot snapshot) async {
    await _telemetryBox!.put('latest', snapshot.toJson());
  }

  List<TelemetryHistoryPoint> getHistory(String parameter) {
    final raw = _telemetryBox!.get('history_$parameter');
    if (raw == null) return [];
    return parseAll(asJsonMapList(raw), TelemetryHistoryPoint.fromJson);
  }

  /// Writes a whole series at once.
  ///
  /// HistoryService batches its commits, replacing the old
  /// append-one-point-at-a-time path that rewrote the entire series on every
  /// telemetry frame.
  Future<void> saveHistory(
    String parameter,
    List<TelemetryHistoryPoint> points,
  ) async {
    final trimmed = points.length > AppConstants.maxHistoryPoints
        ? points.sublist(points.length - AppConstants.maxHistoryPoints)
        : points;

    await _telemetryBox!.put(
      'history_$parameter',
      trimmed.map((e) => e.toJson()).toList(),
    );
  }

  List<SystemEvent> getEvents() {
    final raw = _eventsBox!.get('events');
    if (raw == null) return [];
    return parseAll(asJsonMapList(raw), SystemEvent.fromJson);
  }

  Future<void> addEvent(SystemEvent event) async {
    final events = getEvents();
    events.insert(0, event);
    while (events.length > AppConstants.maxEventLogs) {
      events.removeLast();
    }
    await _eventsBox!.put('events', events.map((e) => e.toJson()).toList());
  }

  List<AppNotification> getNotifications() {
    final raw = _notificationsBox!.get('notifications');
    if (raw == null) return [];
    return parseAll(asJsonMapList(raw), AppNotification.fromJson);
  }

  Future<void> saveNotifications(List<AppNotification> notifications) async {
    final trimmed = notifications.take(AppConstants.maxNotifications).toList();
    await _notificationsBox!.put(
      'notifications',
      trimmed.map((e) => e.toJson()).toList(),
    );
  }

  Future<void> saveSession(String userId, String token) async {
    await _secureStorage.write(key: AppConstants.secureKeySession, value: userId);
    await _secureStorage.write(key: AppConstants.secureKeyToken, value: token);
  }

  Future<String?> getSessionUserId() =>
      _secureStorage.read(key: AppConstants.secureKeySession);

  Future<String?> getSessionToken() =>
      _secureStorage.read(key: AppConstants.secureKeyToken);

  Future<void> clearSession() async {
    await _secureStorage.delete(key: AppConstants.secureKeySession);
    await _secureStorage.delete(key: AppConstants.secureKeyToken);
  }
}