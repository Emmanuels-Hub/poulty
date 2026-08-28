import '../../core/constants/enums.dart';
import '../../core/utils/json_utils.dart';

class ActuatorState {
  const ActuatorState({
    required this.type,
    required this.isOn,
    this.isManualOverride = false,
    this.manualExpiresAt,
    this.hasFailure = false,
  });

  final ActuatorType type;
  final bool isOn;
  final bool isManualOverride;
  final DateTime? manualExpiresAt;
  final bool hasFailure;

  ActuatorState copyWith({
    ActuatorType? type,
    bool? isOn,
    bool? isManualOverride,
    DateTime? manualExpiresAt,
    bool? hasFailure,
  }) {
    return ActuatorState(
      type: type ?? this.type,
      isOn: isOn ?? this.isOn,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      manualExpiresAt: manualExpiresAt ?? this.manualExpiresAt,
      hasFailure: hasFailure ?? this.hasFailure,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'isOn': isOn,
        'isManualOverride': isManualOverride,
        'manualExpiresAt': manualExpiresAt?.toIso8601String(),
        'hasFailure': hasFailure,
      };

  factory ActuatorState.fromJson(Map<String, dynamic> json) => ActuatorState(
        type: ActuatorType.values.byName(json['type'] as String),
        isOn: json['isOn'] as bool? ?? false,
        isManualOverride: json['isManualOverride'] as bool? ?? false,
        manualExpiresAt: json['manualExpiresAt'] != null
            ? DateTime.parse(json['manualExpiresAt'] as String)
            : null,
        hasFailure: json['hasFailure'] as bool? ?? false,
      );
}

class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.timestamp,
    this.temperatureC = 0,
    this.humidityPercent = 0,
    this.ammoniaPpm = 0,
    this.isDaytime = true,
    this.ambientLightLux = 0,
    this.feedLevelPercent = 100,
    this.waterLevelPercent = 100,
    this.batteryPercent = 100,
    this.operatingMode = OperatingMode.automatic,
    this.poultryStage = PoultryStage.starter,
    this.actuators = const [],
    this.sensorSources = const {},
    this.uptimeSeconds = 0,
    this.wifiRssi = 0,
    this.deviceId = 'esp32-main',
  });

  final DateTime timestamp;
  final double temperatureC;
  final double humidityPercent;
  final double ammoniaPpm;
  final bool isDaytime;
  final double ambientLightLux;
  final double feedLevelPercent;
  final double waterLevelPercent;
  final double batteryPercent;
  final OperatingMode operatingMode;
  final PoultryStage poultryStage;
  final List<ActuatorState> actuators;
  final Map<String, String> sensorSources;
  final int uptimeSeconds;
  final int wifiRssi;
  final String deviceId;

  ActuatorState actuator(ActuatorType type) {
    return actuators.firstWhere(
      (a) => a.type == type,
      orElse: () => ActuatorState(type: type, isOn: false),
    );
  }

  DataSource sourceFor(SensorType sensor) {
    final value = sensorSources[sensor.name];
    if (value == DataSource.simulated.name) return DataSource.simulated;
    return DataSource.live;
  }

  TelemetrySnapshot copyWith({
    DateTime? timestamp,
    double? temperatureC,
    double? humidityPercent,
    double? ammoniaPpm,
    bool? isDaytime,
    double? ambientLightLux,
    double? feedLevelPercent,
    double? waterLevelPercent,
    double? batteryPercent,
    OperatingMode? operatingMode,
    PoultryStage? poultryStage,
    List<ActuatorState>? actuators,
    Map<String, String>? sensorSources,
    int? uptimeSeconds,
    int? wifiRssi,
    String? deviceId,
  }) {
    return TelemetrySnapshot(
      timestamp: timestamp ?? this.timestamp,
      temperatureC: temperatureC ?? this.temperatureC,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      ammoniaPpm: ammoniaPpm ?? this.ammoniaPpm,
      isDaytime: isDaytime ?? this.isDaytime,
      ambientLightLux: ambientLightLux ?? this.ambientLightLux,
      feedLevelPercent: feedLevelPercent ?? this.feedLevelPercent,
      waterLevelPercent: waterLevelPercent ?? this.waterLevelPercent,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      operatingMode: operatingMode ?? this.operatingMode,
      poultryStage: poultryStage ?? this.poultryStage,
      actuators: actuators ?? this.actuators,
      sensorSources: sensorSources ?? this.sensorSources,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      wifiRssi: wifiRssi ?? this.wifiRssi,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'temperatureC': temperatureC,
        'humidityPercent': humidityPercent,
        'ammoniaPpm': ammoniaPpm,
        'isDaytime': isDaytime,
        'ambientLightLux': ambientLightLux,
        'feedLevelPercent': feedLevelPercent,
        'waterLevelPercent': waterLevelPercent,
        'batteryPercent': batteryPercent,
        'operatingMode': operatingMode.name,
        'poultryStage': poultryStage.name,
        'actuators': actuators.map((a) => a.toJson()).toList(),
        'sensorSources': sensorSources,
        'uptimeSeconds': uptimeSeconds,
        'wifiRssi': wifiRssi,
        'deviceId': deviceId,
      };

  factory TelemetrySnapshot.fromJson(Map<String, dynamic> json) =>
      TelemetrySnapshot(
        timestamp: DateTime.parse(json['timestamp'] as String),
        temperatureC: (json['temperatureC'] as num?)?.toDouble() ?? 0,
        humidityPercent: (json['humidityPercent'] as num?)?.toDouble() ?? 0,
        ammoniaPpm: (json['ammoniaPpm'] as num?)?.toDouble() ?? 0,
        isDaytime: json['isDaytime'] as bool? ?? true,
        ambientLightLux: (json['ambientLightLux'] as num?)?.toDouble() ?? 0,
        feedLevelPercent: (json['feedLevelPercent'] as num?)?.toDouble() ?? 100,
        waterLevelPercent:
            (json['waterLevelPercent'] as num?)?.toDouble() ?? 100,
        batteryPercent: (json['batteryPercent'] as num?)?.toDouble() ?? 100,
        operatingMode: OperatingMode.values
            .byName(json['operatingMode'] as String? ?? 'automatic'),
        poultryStage: PoultryStage.values
            .byName(json['poultryStage'] as String? ?? 'starter'),
        actuators: asJsonMapList(json['actuators'])
            .map(ActuatorState.fromJson)
            .toList(),
        sensorSources: asStringMap(json['sensorSources']),
        uptimeSeconds: json['uptimeSeconds'] as int? ?? 0,
        wifiRssi: json['wifiRssi'] as int? ?? 0,
        deviceId: json['deviceId'] as String? ?? 'esp32-main',
      );
}

class TelemetryHistoryPoint {
  const TelemetryHistoryPoint({
    required this.timestamp,
    required this.value,
    required this.parameter,
  });

  final DateTime timestamp;
  final double value;
  final String parameter;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'value': value,
        'parameter': parameter,
      };

  factory TelemetryHistoryPoint.fromJson(Map<String, dynamic> json) =>
      TelemetryHistoryPoint(
        timestamp: DateTime.parse(json['timestamp'] as String),
        value: (json['value'] as num).toDouble(),
        parameter: json['parameter'] as String,
      );
}
