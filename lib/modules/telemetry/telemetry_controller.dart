import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/services/alert_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/esp32_ble_service.dart';
import '../../core/services/history_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/notification_service.dart';
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
    this._history,
    this._notifications,
  );

  final LocalStorageService _storage;
  final Esp32BleService _ble;
  final SimulationService _simulation;
  final AlertService _alerts;
  final AuthService _auth;
  final HistoryService _history;
  final NotificationService _notifications;
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

  /// False when nothing is being received. The dashboard then shows zeros,
  /// and nothing is logged or alerted on, because zero means "no reading"
  /// rather than "a reading of zero".
  final RxBool hasLiveData = false.obs;

  /// Bumped whenever a new history point is logged, so charts rebuild without
  /// the controller having to mirror every series into an RxList.
  final RxInt historyRevision = 0.obs;

  /// Locally requested simulation values, mirrored into the UI sliders. The
  /// controller's own `simulatedSensors` is the source of truth for what is
  /// actually active.
  final RxMap<SensorType, double> simulationValues =
      <SensorType, double>{}.obs;

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

  /// True while the controller is acting on injected sensor values.
  bool get isSimulating => current.value?.simulationMode ?? false;

  Set<SensorType> get simulatedSensors =>
      current.value?.simulatedSensors ?? const {};

  HistoryService get history => _history;

  String get lastConnectionError => _ble.lastError;

  ThemeMode get themeMode => settings.value.themeMode;

  @override
  void onInit() {
    super.onInit();
    // Start at zeros rather than the last cached snapshot, so stale readings
    // are never presented as current.
    current.value = TelemetrySnapshot.noData();
    _loadCachedData();
    _bindBleStreams();
  }

  @override
  void onClose() {
    _telemetrySub?.cancel();
    _statusSub?.cancel();
    _scanSub?.cancel();
    _demoTimer?.cancel();
    _history.flush();
    _history.dispose();
    super.onClose();
  }

  void _bindBleStreams() {
    _telemetrySub =
        _ble.telemetry.listen((s) => _ingest(s, fromDevice: true));

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
        _resumeOfflineFeed();
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
      _resumeOfflineFeed();
    }
  }

  void stopMonitoring() {
    isMonitoring.value = false;
    _demoTimer?.cancel();
    _history.flush();
    _ble.disconnect();
  }

  Future<void> refreshNow() async {
    // While connected the notify stream drives updates; there is nothing to
    // pull. Offline, re-evaluate what should be on screen.
    if (!isConnected) _resumeOfflineFeed();
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
      _resumeOfflineFeed();
    }
    return connected;
  }

  Future<void> disconnectDevice() => _ble.disconnect();

  // --- Telemetry -----------------------------------------------------------

  /// Takes in a snapshot.
  ///
  /// [fromDevice] separates a real frame from one this phone generated. Only
  /// real frames are logged or alerted on: a demo or offline-simulation
  /// reading is shown on screen but must never end up in the dataset the farm
  /// relies on, or raise an alert about a coop nobody is measuring.
  void _ingest(TelemetrySnapshot snapshot, {required bool fromDevice}) {
    hasLiveData.value = fromDevice;
    current.value = snapshot;

    if (!fromDevice) return;

    _storage.saveLatestTelemetry(snapshot);

    if (_history.record(snapshot)) {
      _syncHistoryLists();
      historyRevision.value++;
    }

    notifications.assignAll(_alerts.evaluate(snapshot, settings.value));
    _pushOsNotifications();
  }

  /// Mirrors freshly raised alerts out to the OS notification shade, and
  /// withdraws the ones whose condition has cleared.
  void _pushOsNotifications() {
    for (final alert in _alerts.takePendingNotifications()) {
      _notifications.show(alert);
    }
    for (final cleared in _alerts.takePendingClears()) {
      _notifications.cancel(cleared);
    }
  }

  /// Decides what to show while no controller is connected.
  ///
  /// An explicitly started simulation keeps running without hardware. The
  /// passive demo feed only runs if it has been switched on in Settings.
  /// Otherwise the dashboard shows zeros.
  void _resumeOfflineFeed() {
    _demoTimer?.cancel();
    if (!isMonitoring.value) return;

    final wantsFeed = _simulation.isSimulationActive ||
        settings.value.useDemoDataWhenDisconnected;

    if (!wantsFeed) {
      _showNoData();
      return;
    }

    _emitDemoSnapshot();
    _demoTimer = Timer.periodic(AppConstants.telemetryPollInterval, (_) {
      if (isConnected) {
        _demoTimer?.cancel();
        return;
      }
      if (!_simulation.isSimulationActive &&
          !settings.value.useDemoDataWhenDisconnected) {
        _demoTimer?.cancel();
        _showNoData();
        return;
      }
      _emitDemoSnapshot();
    });
  }

  /// Shows zeros and stands down the alerting.
  ///
  /// A condition that can no longer be observed must not keep alerting, and
  /// zeros must never be logged or evaluated as if they were measurements.
  Future<void> _showNoData() async {
    hasLiveData.value = false;
    current.value = TelemetrySnapshot.noData();

    await _alerts.deactivateAll();
    notifications.assignAll(_storage.getNotifications());
    _pushOsNotifications();
  }

  void _emitDemoSnapshot() {
    if (!_simulation.isSimulationActive &&
        !settings.value.useDemoDataWhenDisconnected) {
      return;
    }
    _ingest(
      _simulation.generate(device: activeDevice.value, settings: settings.value),
      fromDevice: false,
    );
  }

  void _loadCachedData() {
    settings.value = _storage.getSettings();
    events.assignAll(_storage.getEvents());
    notifications.assignAll(_storage.getNotifications());
    _loadHistoryFromCache();
  }

  void _loadHistoryFromCache() {
    _history.load();
    _syncHistoryLists();
  }

  void _syncHistoryLists() {
    temperatureHistory.assignAll(_history.series('temperature'));
    humidityHistory.assignAll(_history.series('humidity'));
    airPurityHistory.assignAll(_history.series('airPurity'));
    feedHistory.assignAll(_history.series('feed'));
    waterHistory.assignAll(_history.series('water'));
  }

  Future<void> clearHistory() async {
    if (!canControl) return;
    await _history.clear();
    _syncHistoryLists();
    historyRevision.value++;
    await _logEvent(EventCategory.system, 'Sensor history cleared');
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

  // --- Simulation ----------------------------------------------------------
  //
  // Two paths, one set of controls:
  //
  //   * Connected    - values are pushed to the ESP32, which runs its own
  //                    control logic on them and drives the real relays.
  //   * Disconnected - values drive the local demo generator instead, so the
  //                    UI can still be exercised without hardware.
  //
  // The firmware owns every safety rule (see applyCriticalSafety there): a
  // real over-temperature cancels simulation, the session expires on its own,
  // and losing the BLE link ends it immediately.

  Future<bool> startSimulation({Duration? duration}) async {
    if (!canControl) return false;

    final window = duration ?? AppConstants.simulationDefaultDuration;

    if (isConnected) {
      final sent = await _ble.setSimulation(true, duration: window);
      if (!sent) return false;
    } else {
      _simulation.setSimulationActive(true);
      _resumeOfflineFeed();
    }

    await _logEvent(
      EventCategory.system,
      'Simulation started for ${window.inMinutes} minute(s)',
    );
    return true;
  }

  Future<void> stopSimulation() async {
    if (!canControl) return;

    if (isConnected) {
      await _ble.setSimulation(false);
    }
    _simulation.setSimulationActive(false);
    simulationValues.clear();

    await _logEvent(EventCategory.system, 'Simulation stopped');
    if (!isConnected) _resumeOfflineFeed();
  }

  /// Injects [value] for [sensor] so the actuators respond to it.
  Future<void> setSimulatedSensor(SensorType sensor, double value) async {
    if (!canControl) return;
    simulationValues[sensor] = value;

    if (isConnected) {
      await _ble.setSimulatedSensor(sensor, value);
    } else {
      _simulation.injectSensorValue(sensor, value);
      _emitDemoSnapshot();
    }
  }

  /// Hands one sensor back to its real reading.
  Future<void> clearSimulatedSensor(SensorType sensor) async {
    if (!canControl) return;
    simulationValues.remove(sensor);

    if (isConnected) {
      await _ble.clearSimulatedSensor(sensor);
    } else {
      _simulation.clearSensorValue(sensor);
      _emitDemoSnapshot();
    }
  }

  /// Zeroes one load cell. Must be done with the container empty.
  Future<bool> tareScale(String scale) async {
    if (!canControl || !isConnected) return false;
    final sent = await _ble.tareScale(scale);
    if (sent) {
      await _logEvent(EventCategory.system, 'Tared the $scale load cell');
    }
    return sent;
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    final previous = settings.value;
    settings.value = newSettings;
    await _storage.saveSettings(newSettings);

    if (previous.useDemoDataWhenDisconnected !=
            newSettings.useDemoDataWhenDisconnected &&
        !isConnected) {
      _resumeOfflineFeed();
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
