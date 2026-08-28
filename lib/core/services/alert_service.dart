import 'package:uuid/uuid.dart';

import '../../data/models/event_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/telemetry_model.dart';
import '../constants/app_constants.dart';
import '../constants/enums.dart';
import '../utils/enum_labels.dart';
import 'local_storage_service.dart';

class AlertService {
  AlertService(this._storage);

  final LocalStorageService _storage;
  final _uuid = const Uuid();
  final Map<AlertType, DateTime> _lastAlertAt = {};
  final Set<AlertType> _activeAlerts = {};

  List<AppNotification> evaluate(
    TelemetrySnapshot snapshot,
    AppSettings settings,
  ) {
    final thresholds = settings.thresholds;
    final notifications = _storage.getNotifications();
    const interval = AppConstants.notificationInterval;

    _check(
      notifications: notifications,
      type: AlertType.abnormalTemperature,
      isTriggered: snapshot.temperatureC < thresholds.tempMin ||
          snapshot.temperatureC > thresholds.tempMax,
      severity: AlertSeverity.critical,
      title: 'Abnormal Temperature',
      message: 'Temperature is ${snapshot.temperatureC.toStringAsFixed(1)}°C '
          '(target ${thresholds.tempMin.toStringAsFixed(0)}–'
          '${thresholds.tempMax.toStringAsFixed(0)}°C)',
      interval: interval,
    );

    _check(
      notifications: notifications,
      type: AlertType.abnormalHumidity,
      isTriggered: snapshot.humidityPercent < thresholds.humidityMin ||
          snapshot.humidityPercent > thresholds.humidityMax,
      severity: AlertSeverity.warning,
      title: 'Abnormal Humidity',
      message: 'Humidity is ${snapshot.humidityPercent.toStringAsFixed(0)}% '
          '(target ${thresholds.humidityMin.toStringAsFixed(0)}–'
          '${thresholds.humidityMax.toStringAsFixed(0)}%)',
      interval: interval,
    );

    _check(
      notifications: notifications,
      type: AlertType.poorAirPurity,
      isTriggered: snapshot.airPurityPercent < thresholds.airPurityMin,
      severity: AlertSeverity.critical,
      title: 'Poor Air Purity',
      message: 'Air purity is ${snapshot.airPurityPercent.toStringAsFixed(0)}% '
          '(minimum ${thresholds.airPurityMin.toStringAsFixed(0)}%)',
      interval: interval,
    );

    _check(
      notifications: notifications,
      type: AlertType.lowFeed,
      isTriggered: snapshot.feedLevelPercent <= thresholds.feedLowThreshold,
      severity: AlertSeverity.warning,
      title: 'Low Feed Level',
      message: 'Feed level at ${snapshot.feedLevelPercent.toStringAsFixed(0)}%',
      interval: interval,
    );

    _check(
      notifications: notifications,
      type: AlertType.lowWater,
      isTriggered: snapshot.waterLevelPercent <= thresholds.waterLowThreshold,
      severity: AlertSeverity.warning,
      title: 'Low Water Level',
      message:
          'Water level at ${snapshot.waterLevelPercent.toStringAsFixed(0)}%',
      interval: interval,
    );

    final failed = snapshot.actuators
        .where((a) => a.hasFailure)
        .map((a) => EnumLabels.actuator(a.type))
        .join(', ');

    _check(
      notifications: notifications,
      type: AlertType.actuatorFailure,
      isTriggered: failed.isNotEmpty,
      severity: AlertSeverity.critical,
      title: 'Actuator Failure',
      message: '$failed reported a failure',
      interval: interval,
    );

    _storage.saveNotifications(notifications);
    return notifications;
  }

  Future<void> notifySystemRestart() async {
    await _addNotification(
      type: AlertType.systemRestart,
      severity: AlertSeverity.info,
      title: 'System Restart',
      message: 'ESP32 controller restarted successfully',
    );
  }

  Future<void> notifyReconnected() async {
    await _addNotification(
      type: AlertType.deviceReconnected,
      severity: AlertSeverity.info,
      title: 'Controller Connected',
      message: 'Bluetooth link to the ESP32 controller re-established.',
    );
  }

  void _check({
    required List<AppNotification> notifications,
    required AlertType type,
    required bool isTriggered,
    required AlertSeverity severity,
    required String title,
    required String message,
    required Duration interval,
  }) {
    if (isTriggered) {
      _raiseAlert(
        notifications: notifications,
        type: type,
        severity: severity,
        title: title,
        message: message,
        interval: interval,
      );
    } else {
      _clearAlert(notifications, type);
    }
  }

  void _raiseAlert({
    required List<AppNotification> notifications,
    required AlertType type,
    required AlertSeverity severity,
    required String title,
    required String message,
    required Duration interval,
  }) {
    final now = DateTime.now();
    final last = _lastAlertAt[type];
    if (last != null && now.difference(last) < interval) return;

    _lastAlertAt[type] = now;
    if (_activeAlerts.contains(type)) {
      final index = notifications.indexWhere(
        (n) => n.type == type && n.isActive,
      );
      if (index >= 0) {
        notifications[index] = notifications[index].copyWith(
          message: message,
          timestamp: now,
          isRead: false,
        );
      }
      return;
    }

    _activeAlerts.add(type);
    notifications.insert(
      0,
      AppNotification(
        id: _uuid.v4(),
        type: type,
        severity: severity,
        title: title,
        message: message,
        timestamp: now,
      ),
    );
  }

  void _clearAlert(List<AppNotification> notifications, AlertType type) {
    if (!_activeAlerts.contains(type)) return;
    _activeAlerts.remove(type);

    for (var i = 0; i < notifications.length; i++) {
      if (notifications[i].type == type && notifications[i].isActive) {
        notifications[i] = notifications[i].copyWith(
          isActive: false,
          clearedAt: DateTime.now(),
        );
      }
    }
  }

  Future<void> _addNotification({
    required AlertType type,
    required AlertSeverity severity,
    required String title,
    required String message,
  }) async {
    final notifications = _storage.getNotifications();
    notifications.insert(
      0,
      AppNotification(
        id: _uuid.v4(),
        type: type,
        severity: severity,
        title: title,
        message: message,
        timestamp: DateTime.now(),
      ),
    );
    await _storage.saveNotifications(notifications);
  }

  Future<void> markRead(String id) async {
    final notifications = _storage.getNotifications();
    for (var i = 0; i < notifications.length; i++) {
      if (notifications[i].id == id) {
        notifications[i] = notifications[i].copyWith(isRead: true);
      }
    }
    await _storage.saveNotifications(notifications);
  }

  Future<void> markAllRead() async {
    final notifications = _storage.getNotifications();
    final updated = notifications.map((n) => n.copyWith(isRead: true)).toList();
    await _storage.saveNotifications(updated);
  }
}
