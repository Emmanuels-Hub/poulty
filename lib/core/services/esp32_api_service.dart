import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import '../../core/constants/enums.dart';
import '../../data/models/device_model.dart';
import '../../data/models/event_model.dart';
import '../../data/models/settings_model.dart';
import '../../data/models/telemetry_model.dart';
import '../../core/utils/json_utils.dart';
import 'local_storage_service.dart';
import 'simulation_service.dart';

class Esp32ApiService {
  Esp32ApiService(this._storage, this._simulation);

  final LocalStorageService _storage;
  final SimulationService _simulation;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  bool _useSimulation = true;
  DeviceModel? _activeDevice;
  DeviceConnectionStatus _connectionStatus = DeviceConnectionStatus.offline;

  DeviceConnectionStatus get connectionStatus => _connectionStatus;
  bool get useSimulation => _useSimulation;
  DeviceModel? get activeDevice => _activeDevice;

  void setActiveDevice(DeviceModel device) {
    _activeDevice = device;
  }

  void setUseSimulation(bool value) {
    _useSimulation = value;
  }

  Future<bool> checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  Future<DeviceConnectionStatus> probeConnection(DeviceModel device) async {
    if (_useSimulation) {
      _connectionStatus = DeviceConnectionStatus.online;
      return _connectionStatus;
    }

    if (device.localIp.isNotEmpty) {
      try {
        await _dio.get('http://${device.localIp}/api/status');
        _connectionStatus = DeviceConnectionStatus.local;
        return _connectionStatus;
      } catch (_) {}
    }

    if (device.remoteUrl.isNotEmpty) {
      try {
        await _dio.get('${device.remoteUrl}/api/status');
        _connectionStatus = DeviceConnectionStatus.online;
        return _connectionStatus;
      } catch (_) {}
    }

    _connectionStatus = DeviceConnectionStatus.offline;
    return _connectionStatus;
  }

  Future<TelemetrySnapshot> fetchTelemetry({
    DeviceModel? device,
    AppSettings? settings,
    OperatingMode? mode,
  }) async {
    final target = device ?? _activeDevice;
    final settingsData = settings ?? _storage.getSettings();

    if (_useSimulation ||
        mode == OperatingMode.simulation ||
        _connectionStatus == DeviceConnectionStatus.offline) {
      if (mode != null) _simulation.setMode(mode);
      return _simulation.generate(device: target, settings: settingsData);
    }

    try {
      final url = '${target!.baseUrl}/api/telemetry';
      final response = await _dio.get<Map<String, dynamic>>(url);
      return TelemetrySnapshot.fromJson(asJsonMap(response.data));
    } catch (_) {
      _connectionStatus = DeviceConnectionStatus.offline;
      if (settingsData.useSimulationWhenOffline) {
        return _simulation.generate(device: target, settings: settingsData);
      }
      rethrow;
    }
  }

  Future<void> setOperatingMode(OperatingMode mode) async {
    _simulation.setMode(mode);
    await _sendCommand('/api/mode', {'mode': mode.name});
  }

  Future<void> setPoultryStage(PoultryStage stage) async {
    _simulation.setStage(stage);
    await _sendCommand('/api/stage', {'stage': stage.name});
  }

  Future<void> setSensorSource(SensorType sensor, DataSource source) async {
    _simulation.setSensorSource(sensor, source);
    await _sendCommand('/api/sensors/source', {
      'sensor': sensor.name,
      'source': source.name,
    });
  }

  Future<void> controlActuator(
    ActuatorType type,
    bool isOn, {
    bool manualOverride = false,
    Duration? timeout,
  }) async {
    _simulation.setActuator(type, isOn);
    await _sendCommand('/api/actuators/${type.name}', {
      'state': isOn,
      'manualOverride': manualOverride,
      'timeoutMinutes': timeout?.inMinutes ??
          _storage.getSettings().manualActuatorTimeoutMinutes,
    });
  }

  Future<void> testActuator(ActuatorType type) async {
    await controlActuator(type, true, manualOverride: true);
    await Future<void>.delayed(const Duration(seconds: 3));
    await controlActuator(type, false, manualOverride: false);
  }

  Future<void> pushSettings(AppSettings settings) async {
    await _saveOrQueue('/api/settings', 'PUT', settings.toJson(), 'Update settings');
  }



  Future<void> _sendCommand(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    await _saveOrQueue(endpoint, 'POST', payload, 'Device command');
  }

  Future<void> _saveOrQueue(
    String endpoint,
    String method,
    Map<String, dynamic> payload,
    String description,
  ) async {
    if (_useSimulation || _connectionStatus == DeviceConnectionStatus.offline) {
      final queue = _storage.getQueuedCommands();
      queue.add(
        QueuedCommand(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          endpoint: endpoint,
          method: method,
          payload: payload,
          createdAt: DateTime.now(),
          description: description,
        ),
      );
      await _storage.saveQueuedCommands(queue);
      return;
    }

    final base = _activeDevice?.baseUrl ?? '';
    final url = '$base$endpoint';
    if (method == 'POST') {
      await _dio.post(url, data: payload);
    } else {
      await _dio.put(url, data: payload);
    }
  }

  Future<int> flushCommandQueue() async {
    if (_connectionStatus == DeviceConnectionStatus.offline) return 0;

    final queue = _storage.getQueuedCommands();
    if (queue.isEmpty) return 0;

    final remaining = <QueuedCommand>[];
    var sent = 0;

    for (final command in queue) {
      try {
        final base = _activeDevice?.baseUrl ?? '';
        final url = '$base${command.endpoint}';
        if (command.method == 'POST') {
          await _dio.post(url, data: command.payload);
        } else {
          await _dio.put(url, data: command.payload);
        }
        sent++;
      } catch (_) {
        remaining.add(command);
      }
    }

    await _storage.saveQueuedCommands(remaining);
    return sent;
  }
}
