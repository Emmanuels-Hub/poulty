import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/services/alert_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/esp32_ble_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/simulation_service.dart';
import '../../data/models/device_model.dart';
import '../../data/models/event_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/telemetry_model.dart';

class TelemetryController extends GetxController {
  TelemetryController(
    this._storage,
    this._ble,
    this._simulation,
    this._alerts,
    this._auth,
  );

  final LocalStorageService _storage;
  final Esp32BleService _ble;
  final SimulationService _simulation;
  final AlertService _alerts;
  final AuthService _auth;
  final _uuid = const Uuid();

  final Rxn<TelemetrySnapshot> current = Rxn<TelemetrySnapshot>();
  final RxList<TelemetryHistoryPoint> temperatureHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<TelemetryHistoryPoint> humidityHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<TelemetryHistoryPoint> airPurityHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<TelemetryHistoryPoint> feedHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<TelemetryHistoryPoint> waterHistory =
      <TelemetryHistoryPoint>[].obs;
  final RxList<SystemEvent> events = <SystemEvent>[].obs;
  final RxList<AppNotification> notifications = <AppNotification>[].obs;
  final RxList<DeviceModel> devices = <DeviceModel>[].obs;
  final RxList<DiscoveredDevice> discoveredDevices = <DiscoveredDevice>[].obs;
  final Rxn<DeviceModel> activeDevice = Rxn<DeviceModel>();
  final Rx<AppSettings> settings = AppSettings.defaults().obs;
  final Rx<DeviceConnectionStatus> connectionStatus =
      DeviceConnectionStatus.disconnected.obs;
  final RxBool isScanning = false.obs;
  final RxBool isMonitoring = false.obs;

  StreamSubscription<TelemetrySnapshot>? _telemetrySub;
  StreamSubscription<DeviceConnectionStatus>? _statusSub;
  StreamSubscription<List<DiscoveredDevice>>? _scanSub;
  Timer? _demoTimer;

  bool get canControl => _auth.isAdmin;

  bool get isConnected =>
      connectionStatus.value == DeviceConnectionStatus.connected;

  /// Manual actuator switches only go live once Manual mode has been activated
  /// in Settings — otherwise the controller owns the actuators.
  bool get isManualModeActive =>
      current.value?.operatingMode == OperatingMode.manual;

  bool get canControlActuators => canControl && isManualModeActive;

  ThemeMode get themeMode => settings.value.themeMode;

  @override
  void onInit() {
    super.onInit();
    _loadCachedData();
    _bindBleStreams();
  }

  @override
  void onClose() {
    _telemetrySub?.cancel();
    _statusSub?.cancel();
    _scanSub?.cancel();
    _demoTimer?.cancel();
    super.onClose();
  }

  void _bindBleStreams() {
    _telemetrySub = _ble.telemetry.listen(_ingest);

    _statusSub = _ble.connectionStatusStream.listen((status) async {
      final wasDisconnected =
          connectionStatus.value != DeviceConnectionStatus.connected;
      connectionStatus.value = status;

      if (status == DeviceConnectionStatus.connected) {
        _demoTimer?.cancel();
        if (wasDisconnected) {
          await _alerts.notifyReconnected();
          notifications.assignAll(_storage.getNotifications());
          await _logEvent(EventCategory.connection, 'Controller connected');
        }
      } else if (status == DeviceConnectionStatus.disconnected) {
        await _logEvent(EventCategory.connection, 'Controller disconnected');
        _startDemoFeedIfEnabled();
      }
    });

    _scanSub = _ble.scanResults.listen(discoveredDevices.assignAll);
  }

  Future<void> startMonitoring() async {
    devices.assignAll(_storage.getDevices());
    if (devices.isEmpty) {
      await _storage.seedDefaultDeviceIfEmpty();
      devices.assignAll(_storage.getDevices());
    }

    activeDevice.value = devices.isNotEmpty ? devices.first : null;
    settings.value = _storage.getSettings();
    events.assignAll(_storage.getEvents());
    notifications.assignAll(_storage.getNotifications());
    _loadHistoryFromCache();
    isMonitoring.value = true;

    final device = activeDevice.value;
    if (device != null && device.isPaired) {
      await connectToDevice(device);
    } else {
      _startDemoFeedIfEnabled();
    }
  }

  void stopMonitoring() {
    isMonitoring.value = false;
    _demoTimer?.cancel();
    _ble.disconnect();
  }

  Future<void> refreshNow() async {
    if (!isConnected) _emitDemoSnapshot();
  }

  // --- BLE pairing ---------------------------------------------------------

  Future<void> startScan() async {
    if (!canControl) return;
    discoveredDevices.clear();
    isScanning.value = true;
    await _ble.startScan();
    Future.delayed(AppConstants.bleScanTimeout, () => isScanning.value = false);
  }

  Future<void> stopScan() async {
    await _ble.stopScan();
    isScanning.value = false;
  }

  /// Remembers [discovered] as the active controller, then connects to it.
  Future<bool> pairAndConnect(DiscoveredDevice discovered) async {
    if (!canControl) return false;
    await stopScan();

    final existing = activeDevice.value;
    final device =
        (existing ?? DeviceModel(id: _uuid.v4(), name: discovered.name))
            .copyWith(
      name: discovered.name.isNotEmpty ? discovered.name : 'Coop Controller',
      bleId: discovered.id,
      lastSeen: DateTime.now(),
    );

    await saveDevice(device);
    activeDevice.value = device;
    await _logEvent(EventCategory.connection, 'Paired with ${device.name}');
    return connectToDevice(device);
  }

  Future<bool> connectToDevice(DeviceModel device) async {
    if (!device.isPaired) return false;
    connectionStatus.value = DeviceConnectionStatus.connecting;
    final connected = await _ble.connect(device);
    if (!connected) {
      connectionStatus.value = DeviceConnectionStatus.disconnected;
      _startDemoFeedIfEnabled();
    }
    return connected;
  }

  Future<void> disconnectDevice() => _ble.disconnect();

  // --- Telemetry -----------------------------------------------------------

  void _ingest(TelemetrySnapshot snapshot) {
    current.value = snapshot;
    _storage.saveLatestTelemetry(snapshot);
    _updateHistory(snapshot);
    notifications.assignAll(_alerts.evaluate(snapshot, settings.value));
  }

  void _startDemoFeedIfEnabled() {
    _demoTimer?.cancel();
    if (!isMonitoring.value) return;
    if (!settings.value.useDemoDataWhenDisconnected) return;

    _emitDemoSnapshot();
    _demoTimer = Timer.periodic(AppConstants.telemetryPollInterval, (_) {
      if (isConnected || !settings.value.useDemoDataWhenDisconnected) {
        _demoTimer?.cancel();
        return;
      }
      _emitDemoSnapshot();
    });
  }

  void _emitDemoSnapshot() {
    if (!settings.value.useDemoDataWhenDisconnected) return;
    _ingest(
      _simulation.generate(device: activeDevice.value, settings: settings.value),
    );
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
    airPurityHistory.assignAll(_storage.getHistory('airPurity'));
    feedHistory.assignAll(_storage.getHistory('feed'));
    waterHistory.assignAll(_storage.getHistory('water'));
  }

  void _updateHistory(TelemetrySnapshot snapshot) {
    _appendPoint('temperature', snapshot.temperatureC, temperatureHistory);
    _appendPoint('humidity', snapshot.humidityPercent, humidityHistory);
    _appendPoint('airPurity', snapshot.airPurityPercent, airPurityHistory);
    _appendPoint('feed', snapshot.feedLevelPercent, feedHistory);
    _appendPoint('water', snapshot.waterLevelPercent, waterHistory);
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

  // --- Commands ------------------------------------------------------------

  Future<void> setOperatingMode(OperatingMode mode) async {
    if (!canControl) return;
    _simulation.setMode(mode);
    await _ble.setOperatingMode(mode);
    current.value = current.value?.copyWith(operatingMode: mode);
    await _logEvent(EventCategory.system, 'Operating mode set to ${mode.name}');
    await refreshNow();
  }

  Future<void> setPoultryStage(PoultryStage stage) async {
    if (!canControl) return;
    await _ble.setPoultryStage(stage);
    await _logEvent(
      EventCategory.system,
      'Production stage set to ${stage.name}',
    );
    await refreshNow();
  }

  Future<void> toggleActuator(ActuatorType type, bool isOn) async {
    if (!canControlActuators) return;
    _simulation.setActuator(type, isOn);
    await _ble.controlActuator(
      type,
      isOn,
      timeout: AppConstants.manualActuatorTimeout,
    );
    await _logEvent(
      EventCategory.actuator,
      '${type.name} manually set to ${isOn ? 'ON' : 'OFF'}',
    );
    await refreshNow();
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    final previous = settings.value;
    settings.value = newSettings;
    await _storage.saveSettings(newSettings);

    if (previous.useDemoDataWhenDisconnected !=
            newSettings.useDemoDataWhenDisconnected &&
        !isConnected) {
      if (newSettings.useDemoDataWhenDisconnected) {
        _startDemoFeedIfEnabled();
      } else {
        _demoTimer?.cancel();
      }
    }
  }

  /// Theme is a per-app preference, so viewers can change it too.
  Future<void> setThemeMode(ThemeMode mode) async {
    await saveSettings(settings.value.copyWith(themeMode: mode));
    Get.changeThemeMode(mode);
  }

  Future<void> saveDevice(DeviceModel device) async {
    if (!canControl) return;
    await _storage.saveDevice(device);
    devices.assignAll(_storage.getDevices());
    if (activeDevice.value?.id == device.id) activeDevice.value = device;
  }

  Future<void> deleteDevice(String id) async {
    if (!canControl) return;
    await _storage.deleteDevice(id);
    devices.assignAll(_storage.getDevices());
    if (activeDevice.value?.id == id) {
      activeDevice.value = devices.isNotEmpty ? devices.first : null;
      await disconnectDevice();
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
