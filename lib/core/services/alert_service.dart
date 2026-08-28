import 'package:uuid/uuid.dart';

import '../../core/constants/enums.dart';
import '../../data/models/event_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/telemetry_model.dart';
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
    final thresholds = settings.thresholdsFor(snapshot.poultryStage);
    final notifications = _storage.getNotifications();
    final interval = Duration(minutes: settings.notificationIntervalMinutes);

    _checkRangeAlert(
      notifications: notifications,
      type: AlertType.abnormalTemperature,
      isAbnormal: snapshot.temperatureC < thresholds.tempMin ||
          snapshot.temperatureC > thresholds.tempMax,
      severity: AlertSeverity.critical,
      title: 'Abnormal Temperature',
      message:
          'Temperature is ${snapshot.temperatureC.toStringAsFixed(1)}°C (range ${thresholds.tempMin}-${thresholds.tempMax}°C)',
      interval: interval,
    );

    _checkRangeAlert(
      notifications: notifications,
      type: AlertType.abnormalHumidity,
      isAbnormal: snapshot.humidityPercent < thresholds.humidityMin ||
          snapshot.humidityPercent > thresholds.humidityMax,
      severity: AlertSeverity.warning,
      title: 'Abnormal Humidity',
      message:
          'Humidity is ${snapshot.humidityPercent.toStringAsFixed(0)}% (range ${thresholds.humidityMin}-${thresholds.humidityMax}%)',
      interval: interval,
    );

    _checkRangeAlert(
      notifications: notifications,
      type: AlertType.abnormalAmmonia,
      isAbnormal: snapshot.ammoniaPpm > thresholds.ammoniaMax,
      severity: AlertSeverity.critical,
      title: 'High Ammonia Level',
      message:
          'Ammonia is ${snapshot.ammoniaPpm.toStringAsFixed(1)} ppm (max ${thresholds.ammoniaMax} ppm)',
      interval: interval,
    );

    _checkThresholdAlert(
      notifications: notifications,
      type: AlertType.lowFeed,
      isLow: snapshot.feedLevelPercent <= thresholds.feedLowThreshold,
      severity: AlertSeverity.warning,
      title: 'Low Feed Level',
      message: 'Feed level at ${snapshot.feedLevelPercent.toStringAsFixed(0)}%',
      interval: interval,
    );

    _checkThresholdAlert(
      notifications: notifications,
      type: AlertType.lowWater,
      isLow: snapshot.waterLevelPercent <= thresholds.waterLowThreshold,
      severity: AlertSeverity.warning,
      title: 'Low Water Level',
      message: 'Water level at ${snapshot.waterLevelPercent.toStringAsFixed(0)}%',
      interval: interval,
    );

    _checkThresholdAlert(
      notifications: notifications,
      type: AlertType.lowBattery,
      isLow: snapshot.batteryPercent <= settings.batteryLowThreshold,
      severity: AlertSeverity.critical,
      title: 'Low Battery',
      message: 'Battery at ${snapshot.batteryPercent.toStringAsFixed(0)}%',
      interval: interval,
    );

    for (final actuator in snapshot.actuators) {
      if (actuator.hasFailure) {
        _raiseAlert(
          notifications: notifications,
          type: AlertType.actuatorFailure,
          severity: AlertSeverity.critical,
          title: 'Actuator Failure',
          message: '${actuator.type.name} reported a failure',
          interval: interval,
        );
      }
    }

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
      type: AlertType.internetReconnected,
      severity: AlertSeverity.info,
      title: 'Connection Restored',
      message: 'Internet connection re-established. Syncing buffered data.',
    );
  }

  void _checkRangeAlert({
    required List<AppNotification> notifications,
    required AlertType type,
    required bool isAbnormal,
    required AlertSeverity severity,
    required String title,
    required String message,
    required Duration interval,
  }) {
    if (isAbnormal) {
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

  void _checkThresholdAlert({
    required List<AppNotification> notifications,
    required AlertType type,
    required bool isLow,
    required AlertSeverity severity,
    required String title,
    required String message,
    required Duration interval,
  }) {
    if (isLow) {
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
