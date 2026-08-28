import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/services/alert_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/esp32_api_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../data/models/device_model.dart';
import '../../data/models/event_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/telemetry_model.dart';
import 'package:uuid/uuid.dart';

class TelemetryController extends GetxController {
  TelemetryController(
    this._storage,
    this._api,
    this._alerts,
    this._auth,
  );

  final LocalStorageService _storage;
  final Esp32ApiService _api;
  final AlertService _alerts;
  final AuthService _auth;
  final _uuid = const Uuid();

  final Rxn<TelemetrySnapshot> current = Rxn<TelemetrySnapshot>();
  final RxList<TelemetryHistoryPoint> temperatureHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<TelemetryHistoryPoint> humidityHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<TelemetryHistoryPoint> ammoniaHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<TelemetryHistoryPoint> feedHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<TelemetryHistoryPoint> waterHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<TelemetryHistoryPoint> batteryHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<SystemEvent> events = <SystemEvent>[].obs;
  final RxList<AppNotification> notifications = <AppNotification>[].obs;
  final RxList<DeviceModel> devices = <DeviceModel>[].obs;
  final Rxn<DeviceModel> activeDevice = Rxn<DeviceModel>();
  final Rx<AppSettings> settings = AppSettings.defaults().obs;
  final Rx<DeviceConnectionStatus> connectionStatus =
      DeviceConnectionStatus.offline.obs;
  final RxBool isPolling = false.obs;
  final RxBool isOffline = false.obs;
  final RxInt queuedCommands = 0.obs;
  final RxInt uptimeHours = 0.obs;
  final RxDouble systemHealthScore = 100.0.obs;

  bool get canControl => _auth.isAdmin;

  @override
  void onInit() {
    super.onInit();
    _loadCachedData();
  }

  Future<void> startMonitoring() async {
    devices.assignAll(_storage.getDevices());
    if (devices.isEmpty) {
      await _storage.seedDefaultDeviceIfEmpty();
      devices.assignAll(_storage.getDevices());
    }

    activeDevice.value = devices.isNotEmpty ? devices.first : null;
    if (activeDevice.value != null) {
      _api.setActiveDevice(activeDevice.value!);
    }

    settings.value = _storage.getSettings();
    events.assignAll(_storage.getEvents());
    notifications.assignAll(_storage.getNotifications());
    _loadHistoryFromCache();
    isPolling.value = true;
    await _poll();
  }

  void stopMonitoring() {
    isPolling.value = false;
  }

  Future<void> refreshNow() => _poll();

  Future<void> _poll() async {
    if (!isPolling.value) return;

    try {
      final hasNetwork = await _api.checkConnectivity();
      final previousOffline = isOffline.value;
      isOffline.value = !hasNetwork;

      if (activeDevice.value != null) {
        final previousStatus = connectionStatus.value;
        connectionStatus.value =
            await _api.probeConnection(activeDevice.value!);

        if (previousStatus == DeviceConnectionStatus.offline &&
            connectionStatus.value != DeviceConnectionStatus.offline) {
          await _alerts.notifyReconnected();
          await _logEvent(EventCategory.network, 'Connection restored');
        }
      }

      if (previousOffline && hasNetwork) {
        notifications.assignAll(_storage.getNotifications());
      }

      final snapshot = await _api.fetchTelemetry(
        device: activeDevice.value,
        settings: settings.value,
        mode: current.value?.operatingMode,
      );

      current.value = snapshot;
      await _storage.saveLatestTelemetry(snapshot);
      _updateHistory(snapshot);
      notifications.assignAll(_alerts.evaluate(snapshot, settings.value));
      _updateHealthScore(snapshot);
      queuedCommands.value = _storage.getQueuedCommands().length;

      if (hasNetwork && queuedCommands.value > 0) {
        final sent = await _api.flushCommandQueue();
        if (sent > 0) {
          await _logEvent(
            EventCategory.network,
            'Synced $sent queued command(s)',
          );
          queuedCommands.value = _storage.getQueuedCommands().length;
        }
      }
    } catch (e) {
      connectionStatus.value = DeviceConnectionStatus.offline;
    }

    Future.delayed(AppConstants.telemetryPollInterval, _poll);
  }

  void _loadCachedData() {
    final cached = _storage.getLatestTelemetry();
    if (cached != null) current.value = cached;
    settings.value = _storage.getSettings();
    events.assignAll(_storage.getEvents());
    notifications.assignAll(_storage.getNotifications());
    _loadHistoryFromCache();
  }

  void _loadHistoryFromCache() {
    temperatureHistory.assignAll(_storage.getHistory('temperature'));
    humidityHistory.assignAll(_storage.getHistory('humidity'));
    ammoniaHistory.assignAll(_storage.getHistory('ammonia'));
    feedHistory.assignAll(_storage.getHistory('feed'));
    waterHistory.assignAll(_storage.getHistory('water'));
    batteryHistory.assignAll(_storage.getHistory('battery'));
  }

  void _updateHistory(TelemetrySnapshot snapshot) {
    _appendPoint('temperature', snapshot.temperatureC, temperatureHistory);
    _appendPoint('humidity', snapshot.humidityPercent, humidityHistory);
    _appendPoint('ammonia', snapshot.ammoniaPpm, ammoniaHistory);
    _appendPoint('feed', snapshot.feedLevelPercent, feedHistory);
    _appendPoint('water', snapshot.waterLevelPercent, waterHistory);
    _appendPoint('battery', snapshot.batteryPercent, batteryHistory);
    uptimeHours.value = snapshot.uptimeSeconds ~/ 3600;
  }

  void _appendPoint(
    String parameter,
    double value,
    RxList<TelemetryHistoryPoint> list,
  ) {
    final point = TelemetryHistoryPoint(
      timestamp: DateTime.now(),
      value: value,
      parameter: parameter,
    );
    list.add(point);
    while (list.length > AppConstants.maxHistoryPoints) {
      list.removeAt(0);
    }
    _storage.appendHistoryPoint(point);
  }

  void _updateHealthScore(TelemetrySnapshot snapshot) {
    var score = 100.0;
    final t = settings.value.thresholdsFor(snapshot.poultryStage);

    if (snapshot.temperatureC < t.tempMin || snapshot.temperatureC > t.tempMax) {
      score -= 15;
    }
    if (snapshot.humidityPercent < t.humidityMin ||
        snapshot.humidityPercent > t.humidityMax) {
      score -= 10;
    }
    if (snapshot.ammoniaPpm > t.ammoniaMax) score -= 20;
    if (snapshot.feedLevelPercent <= t.feedLowThreshold) score -= 10;
    if (snapshot.waterLevelPercent <= t.waterLowThreshold) score -= 10;
    if (snapshot.batteryPercent <= settings.value.batteryLowThreshold) {
      score -= 15;
    }
    if (connectionStatus.value == DeviceConnectionStatus.offline) score -= 20;
    if (snapshot.actuators.any((a) => a.hasFailure)) score -= 15;

    systemHealthScore.value = score.clamp(0, 100);
  }

  Future<void> setOperatingMode(OperatingMode mode) async {
    if (!canControl) return;
    await _api.setOperatingMode(mode);
    await _logEvent(EventCategory.system, 'Operating mode set to ${mode.name}');
    await refreshNow();
  }

  Future<void> setPoultryStage(PoultryStage stage) async {
    if (!canControl) return;
    await _api.setPoultryStage(stage);
    await _logEvent(EventCategory.system, 'Production stage set to ${stage.name}');
    await refreshNow();
  }

  Future<void> toggleActuator(ActuatorType type, bool isOn) async {
    if (!canControl) return;
    await _api.controlActuator(
      type,
      isOn,
      manualOverride: true,
      timeout: Duration(
        minutes: settings.value.manualActuatorTimeoutMinutes,
      ),
    );
    await _logEvent(
      EventCategory.actuator,
      '${type.name} manually set to ${isOn ? 'ON' : 'OFF'}',
    );
    await refreshNow();
  }

  Future<void> setSensorSource(SensorType sensor, DataSource source) async {
    if (!canControl) return;
    await _api.setSensorSource(sensor, source);
    await _logEvent(
      EventCategory.sensor,
      '${sensor.name} data source set to ${source.name}',
    );
    await refreshNow();
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    if (!canControl) return;
    settings.value = newSettings;
    await _storage.saveSettings(newSettings);
    await _api.pushSettings(newSettings);
    await _logEvent(EventCategory.system, 'System settings updated');
  }

  Future<void> saveDevice(DeviceModel device) async {
    if (!canControl) return;
    await _storage.saveDevice(device);
    devices.assignAll(_storage.getDevices());
    if (activeDevice.value?.id == device.id) {
      activeDevice.value = device;
      _api.setActiveDevice(device);
    }
  }

  Future<void> deleteDevice(String id) async {
    if (!canControl) return;
    await _storage.deleteDevice(id);
    devices.assignAll(_storage.getDevices());
    if (activeDevice.value?.id == id) {
      activeDevice.value = devices.isNotEmpty ? devices.first : null;
    }
  }

  Future<void> markNotificationRead(String id) async {
    await _alerts.markRead(id);
    notifications.assignAll(_storage.getNotifications());
  }

  Future<void> markAllNotificationsRead() async {
    await _alerts.markAllRead();
    notifications.assignAll(_storage.getNotifications());
  }

  Future<void> _logEvent(EventCategory category, String message) async {
    final event = SystemEvent(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      category: category,
      message: message,
    );
    await _storage.addEvent(event);
    events.insert(0, event);
  }

  int get unreadNotificationCount =>
      notifications.where((n) => !n.isRead && n.isActive).length;
}
