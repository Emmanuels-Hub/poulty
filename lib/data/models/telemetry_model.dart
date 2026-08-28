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
        type: enumByName(
          ActuatorType.values,
          json['type'],
          ActuatorType.ventilationFan,
        ),
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
    this.airPurityPercent = 100,
    this.isDaytime = true,
    this.feedLevelPercent = 100,
    this.waterLevelPercent = 100,
    this.operatingMode = OperatingMode.automatic,
    this.poultryStage = PoultryStage.starter,
    this.actuators = const [],
    this.deviceId = 'esp32-main',
  });

  final DateTime timestamp;
  final double temperatureC;
  final double humidityPercent;

  /// Air purity as a percentage from the gas sensor: 100% is clean air.
  final double airPurityPercent;
  final bool isDaytime;
  final double feedLevelPercent;
  final double waterLevelPercent;
  final OperatingMode operatingMode;
  final PoultryStage poultryStage;
  final List<ActuatorState> actuators;
  final String deviceId;

  ActuatorState actuator(ActuatorType type) {
    return actuators.firstWhere(
      (a) => a.type == type,
      orElse: () => ActuatorState(type: type, isOn: false),
    );
  }

  TelemetrySnapshot copyWith({
    DateTime? timestamp,
    double? temperatureC,
    double? humidityPercent,
    double? airPurityPercent,
    bool? isDaytime,
    double? feedLevelPercent,
    double? waterLevelPercent,
    OperatingMode? operatingMode,
    PoultryStage? poultryStage,
    List<ActuatorState>? actuators,
    String? deviceId,
  }) {
    return TelemetrySnapshot(
      timestamp: timestamp ?? this.timestamp,
      temperatureC: temperatureC ?? this.temperatureC,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      airPurityPercent: airPurityPercent ?? this.airPurityPercent,
      isDaytime: isDaytime ?? this.isDaytime,
      feedLevelPercent: feedLevelPercent ?? this.feedLevelPercent,
      waterLevelPercent: waterLevelPercent ?? this.waterLevelPercent,
      operatingMode: operatingMode ?? this.operatingMode,
      poultryStage: poultryStage ?? this.poultryStage,
      actuators: actuators ?? this.actuators,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'temperatureC': temperatureC,
        'humidityPercent': humidityPercent,
        'airPurityPercent': airPurityPercent,
        'isDaytime': isDaytime,
        'feedLevelPercent': feedLevelPercent,
        'waterLevelPercent': waterLevelPercent,
        'operatingMode': operatingMode.name,
        'poultryStage': poultryStage.name,
        'actuators': actuators.map((a) => a.toJson()).toList(),
        'deviceId': deviceId,
      };

  factory TelemetrySnapshot.fromJson(Map<String, dynamic> json) =>
      TelemetrySnapshot(
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        temperatureC: (json['temperatureC'] as num?)?.toDouble() ?? 0,
        humidityPercent: (json['humidityPercent'] as num?)?.toDouble() ?? 0,
        airPurityPercent:
            (json['airPurityPercent'] as num?)?.toDouble() ?? 100,
        isDaytime: json['isDaytime'] as bool? ?? true,
        feedLevelPercent: (json['feedLevelPercent'] as num?)?.toDouble() ?? 100,
        waterLevelPercent:
            (json['waterLevelPercent'] as num?)?.toDouble() ?? 100,
        operatingMode: enumByName(
          OperatingMode.values,
          json['operatingMode'],
          OperatingMode.automatic,
        ),
        poultryStage: enumByName(
          PoultryStage.values,
          json['poultryStage'],
          PoultryStage.starter,
        ),
        actuators: asJsonMapList(json['actuators'])
            .map(ActuatorState.fromJson)
            .toList(),
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
