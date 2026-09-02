import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../data/models/device_model.dart';
import '../../data/models/telemetry_model.dart';
import '../constants/app_constants.dart';
import '../constants/enums.dart';
import '../utils/json_utils.dart';

/// A device seen during a BLE scan.
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });

  final String id;
  final String name;
  final int rssi;
}

/// Talks to the ESP32 coop controller over Bluetooth Low Energy.
///
/// The firmware exposes a Nordic-UART style service: telemetry arrives as JSON
/// frames on a notify characteristic, and commands are written as JSON frames
/// to a write characteristic.
class Esp32BleService {
  Esp32BleService();

  final _telemetryController =
      StreamController<TelemetrySnapshot>.broadcast();
  final _statusController =
      StreamController<DeviceConnectionStatus>.broadcast();
  final _scanResults = StreamController<List<DiscoveredDevice>>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandChar;
  StreamSubscription<List<int>>? _telemetrySub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<ScanResult>>? _scanSub;

  DeviceConnectionStatus _status = DeviceConnectionStatus.disconnected;
  String _buffer = '';
  String _lastError = '';

  /// Why the last connection attempt failed, for the pairing UI. Connecting
  /// but finding no telemetry characteristic looks identical to a flat refusal
  /// from the user's side, so the reason has to be surfaced.
  String get lastError => _lastError;

  Stream<TelemetrySnapshot> get telemetry => _telemetryController.stream;
  Stream<DeviceConnectionStatus> get connectionStatusStream =>
      _statusController.stream;
  Stream<List<DiscoveredDevice>> get scanResults => _scanResults.stream;

  DeviceConnectionStatus get connectionStatus => _status;
  bool get isConnected => _status == DeviceConnectionStatus.connected;

  Future<bool> get isSupported => FlutterBluePlus.isSupported;

  Future<bool> isBluetoothOn() async {
    if (!await FlutterBluePlus.isSupported) return false;
    return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
  }

  /// Scans for nearby controllers advertising the poultry service.
  Future<void> startScan() async {
    if (!await FlutterBluePlus.isSupported) return;

    await _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      final devices = results
          .where((r) => _looksLikeController(r))
          .map(
            (r) => DiscoveredDevice(
              id: r.device.remoteId.str,
              name: r.device.platformName.isNotEmpty
                  ? r.device.platformName
                  : r.advertisementData.advName,
              rssi: r.rssi,
            ),
          )
          .toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      _scanResults.add(devices);
    });

    await FlutterBluePlus.startScan(timeout: AppConstants.bleScanTimeout);
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
  }

  bool _looksLikeController(ScanResult result) {
    final serviceUuid = Guid(AppConstants.bleServiceUuid);
    if (result.advertisementData.serviceUuids.contains(serviceUuid)) {
      return true;
    }
    final name = result.device.platformName.isNotEmpty
        ? result.device.platformName
        : result.advertisementData.advName;
    return name.isNotEmpty &&
        name.toLowerCase().contains(
              AppConstants.bleDeviceNamePrefix.toLowerCase(),
            );
  }

  /// Connects to [device] and starts streaming telemetry.
  Future<bool> connect(DeviceModel device) async {
    if (device.bleId.isEmpty) return false;
    if (!await FlutterBluePlus.isSupported) return false;

    await disconnect();
    _setStatus(DeviceConnectionStatus.connecting);

    try {
      final target = BluetoothDevice.fromId(device.bleId);
      _device = target;

      _connectionSub = target.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _setStatus(DeviceConnectionStatus.disconnected);
        }
      });

      await target.connect(timeout: const Duration(seconds: 15));

      final services = await target.discoverServices();
      final service = services.where(
        (s) => s.uuid == Guid(AppConstants.bleServiceUuid),
      ).firstOrNull;

      if (service == null) {
        throw StateError(
          'Connected, but the controller is not advertising the poultry '
          'service. Check BLE_SERVICE_UUID in the firmware.',
        );
      }

      _commandChar = service.characteristics.where(
        (c) => c.uuid == Guid(AppConstants.bleCommandCharUuid),
      ).firstOrNull;

      final telemetryChar = service.characteristics.where(
        (c) => c.uuid == Guid(AppConstants.bleTelemetryCharUuid),
      ).firstOrNull;

      if (_commandChar == null || telemetryChar == null) {
        final found = service.characteristics
            .map((c) => c.uuid.str)
            .join(', ');
        throw StateError(
          'Connected, but the expected characteristics are missing. '
          'The controller offers: $found. Check the UUIDs in the firmware '
          'match AppConstants exactly.',
        );
      }

      await telemetryChar.setNotifyValue(true);
      _telemetrySub = telemetryChar.onValueReceived.listen(_onFrame);

      _lastError = '';
      _setStatus(DeviceConnectionStatus.connected);
      return true;
    } catch (e) {
      _lastError = e is StateError ? e.message : e.toString();
      await disconnect();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _telemetrySub?.cancel();
    _telemetrySub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    _commandChar = null;
    _buffer = '';

    final device = _device;
    _device = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {
        // Already gone; nothing to clean up.
      }
    }
    _setStatus(DeviceConnectionStatus.disconnected);
  }

  /// BLE frames are MTU-sized chunks, so reassemble on newline boundaries.
  void _onFrame(List<int> chunk) {
    _buffer += utf8.decode(chunk, allowMalformed: true);

    while (true) {
      final newline = _buffer.indexOf('\n');
      if (newline < 0) break;
      final line = _buffer.substring(0, newline).trim();
      _buffer = _buffer.substring(newline + 1);
      _emit(line);
    }

    // Some firmwares send one complete JSON object per notification with no
    // trailing newline; accept that too.
    if (_buffer.trimLeft().startsWith('{') && _buffer.trimRight().endsWith('}')) {
      final line = _buffer.trim();
      _buffer = '';
      _emit(line);
    }

    if (_buffer.length > 4096) _buffer = '';
  }

  void _emit(String line) {
    if (line.isEmpty) return;
    try {
      final snapshot = TelemetrySnapshot.fromJson(
        asJsonMap(jsonDecode(line)),
      );
      _telemetryController.add(snapshot);
    } catch (_) {
      // Ignore malformed frames rather than dropping the connection.
    }
  }

  Future<bool> sendCommand(String command, Map<String, dynamic> payload) async {
    final characteristic = _commandChar;
    if (characteristic == null || !isConnected) return false;

    try {
      final frame = jsonEncode({'cmd': command, ...payload});
      await characteristic.write(
        utf8.encode('$frame\n'),
        withoutResponse: characteristic.properties.writeWithoutResponse,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setOperatingMode(OperatingMode mode) =>
      sendCommand('setMode', {'mode': mode.name});

  Future<bool> setPoultryStage(PoultryStage stage) =>
      sendCommand('setStage', {'stage': stage.name});

  Future<bool> controlActuator(
    ActuatorType type,
    bool isOn, {
    Duration? timeout,
  }) {
    return sendCommand('setActuator', {
      'actuator': type.name,
      'state': isOn,
      'timeoutMinutes':
          (timeout ?? AppConstants.manualActuatorTimeout).inMinutes,
    });
  }

  /// Starts or stops hardware-in-the-loop simulation on the controller.
  Future<bool> setSimulation(bool enabled, {Duration? duration}) {
    return sendCommand('setSimulation', {
      'enabled': enabled,
      if (enabled)
        'timeoutMinutes':
            (duration ?? AppConstants.simulationDefaultDuration).inMinutes,
    });
  }

  /// Injects a reading for one sensor. Only accepted while simulation is on.
  Future<bool> setSimulatedSensor(SensorType sensor, double value) {
    return sendCommand('setSensor', {
      'sensor': sensor.name,
      'value': double.parse(value.toStringAsFixed(1)),
    });
  }

  /// Hands one sensor back to its real reading.
  Future<bool> clearSimulatedSensor(SensorType sensor) {
    return sendCommand('setSensor', {'sensor': sensor.name, 'clear': true});
  }

  /// Records the current reading as the empty point for one load cell. The
  /// controller stores the offset, so this is done once per container rather
  /// than on every boot.
  Future<bool> tareScale(String scale) =>
      sendCommand('tareScale', {'scale': scale});

  void _setStatus(DeviceConnectionStatus status) {
    if (_status == status) return;
    _status = status;
    _statusController.add(status);
  }

  Future<void> dispose() async {
    await stopScan();
    await disconnect();
    await _telemetryController.close();
    await _statusController.close();
    await _scanResults.close();
  }
}
