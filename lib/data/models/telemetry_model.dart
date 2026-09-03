import '../../core/constants/app_constants.dart';
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

/// Bit position of each sensor in the firmware's `simulatedMask`.
///
/// These indices are part of the BLE contract and must stay in step with the
/// `SIM_*` defines in esp/Smart_Poultry/Smart_Poultry.ino.
const Map<SensorType, int> simulationBits = {
  SensorType.temperature: 0,
  SensorType.humidity: 1,
  SensorType.airPurity: 2,
  SensorType.feedLevel: 3,
  SensorType.waterLevel: 4,
};

Set<SensorType> decodeSimulatedMask(int mask) {
  return {
    for (final entry in simulationBits.entries)
      if (mask & (1 << entry.value) != 0) entry.key,
  };
}

int encodeSimulatedMask(Set<SensorType> sensors) {
  var mask = 0;
  for (final sensor in sensors) {
    mask |= 1 << (simulationBits[sensor] ?? 0);
  }
  return mask;
}

class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.timestamp,
    this.temperatureC = 0,
    this.humidityPercent = 0,
    this.airPurityPercent = 100,
    this.feedLevelPercent = 100,
    this.waterLevelPercent = 100,
    this.operatingMode = OperatingMode.automatic,
    this.poultryStage = PoultryStage.starter,
    this.actuators = const [],
    this.deviceId = 'esp32-main',
    this.simulationMode = false,
    this.simulatedSensors = const {},
    this.feedScaleTared = true,
    this.waterScaleTared = true,
    this.airPuritySensorOk = true,
  });

  final DateTime timestamp;
  final double temperatureC;
  final double humidityPercent;

  /// Air purity as a percentage from the gas sensor: 100% is clean air.
  final double airPurityPercent;
  final double feedLevelPercent;
  final double waterLevelPercent;
  final OperatingMode operatingMode;
  final PoultryStage poultryStage;
  final List<ActuatorState> actuators;
  final String deviceId;

  /// True while the controller is running on injected sensor values.
  final bool simulationMode;

  /// Which sensors are currently being simulated, decoded from the frame's
  /// bitmask so the app can label individual readings as fake.
  final Set<SensorType> simulatedSensors;

  /// Whether each load cell has a saved zero point. Until it does, the level
  /// percentages are meaningless. Defaults to true so a frame from firmware
  /// that does not report this is not treated as uncalibrated.
  final bool feedScaleTared;
  final bool waterScaleTared;

  /// False when the gas sensor is not responding. A dead MQ-135 reads as
  /// clean air, so the fault has to be reported rather than inferred from
  /// a suspiciously perfect number.
  final bool airPuritySensorOk;

  /// Every reading at zero, used when nothing is being received.
  ///
  /// Zero here means "no reading", not "a reading of zero" — the controller
  /// gates history logging and alert evaluation on that distinction, so these
  /// values are displayed but never logged or alerted on.
  factory TelemetrySnapshot.noData() {
    return TelemetrySnapshot(
      timestamp: DateTime.now(),
      temperatureC: 0,
      humidityPercent: 0,
      airPurityPercent: 0,
      feedLevelPercent: 0,
      waterLevelPercent: 0,
      actuators: ActuatorType.values
          .map((type) => ActuatorState(type: type, isOn: false))
          .toList(),
    );
  }

  /// Derived from the phone's clock: the controller has neither a light
  /// sensor nor a real-time clock, so it cannot report this itself.
  bool get isDaytime =>
      timestamp.hour >= AppConstants.daytimeStartHour &&
      timestamp.hour < AppConstants.daytimeEndHour;

  bool isSimulated(SensorType sensor) => simulatedSensors.contains(sensor);

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
    double? feedLevelPercent,
    double? waterLevelPercent,
    OperatingMode? operatingMode,
    PoultryStage? poultryStage,
    List<ActuatorState>? actuators,
    String? deviceId,
    bool? simulationMode,
    Set<SensorType>? simulatedSensors,
    bool? feedScaleTared,
    bool? waterScaleTared,
    bool? airPuritySensorOk,
  }) {
    return TelemetrySnapshot(
      timestamp: timestamp ?? this.timestamp,
      temperatureC: temperatureC ?? this.temperatureC,
      humidityPercent: humidityPercent ?? this.humidityPercent,
      airPurityPercent: airPurityPercent ?? this.airPurityPercent,
      feedLevelPercent: feedLevelPercent ?? this.feedLevelPercent,
      waterLevelPercent: waterLevelPercent ?? this.waterLevelPercent,
      operatingMode: operatingMode ?? this.operatingMode,
      poultryStage: poultryStage ?? this.poultryStage,
      actuators: actuators ?? this.actuators,
      deviceId: deviceId ?? this.deviceId,
      simulationMode: simulationMode ?? this.simulationMode,
      simulatedSensors: simulatedSensors ?? this.simulatedSensors,
      feedScaleTared: feedScaleTared ?? this.feedScaleTared,
      waterScaleTared: waterScaleTared ?? this.waterScaleTared,
      airPuritySensorOk: airPuritySensorOk ?? this.airPuritySensorOk,
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'temperatureC': temperatureC,
        'humidityPercent': humidityPercent,
        'airPurityPercent': airPurityPercent,
        'feedLevelPercent': feedLevelPercent,
        'waterLevelPercent': waterLevelPercent,
        'operatingMode': operatingMode.name,
        'poultryStage': poultryStage.name,
        'actuators': actuators.map((a) => a.toJson()).toList(),
        'deviceId': deviceId,
        'simulationMode': simulationMode,
        'simulatedMask': encodeSimulatedMask(simulatedSensors),
        'feedTared': feedScaleTared,
        'waterTared': waterScaleTared,
        'airPurityOk': airPuritySensorOk,
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
        simulationMode: json['simulationMode'] as bool? ?? false,
        simulatedSensors:
            decodeSimulatedMask((json['simulatedMask'] as num?)?.toInt() ?? 0),
        feedScaleTared: json['feedTared'] as bool? ?? true,
        waterScaleTared: json['waterTared'] as bool? ?? true,
        airPuritySensorOk: json['airPurityOk'] as bool? ?? true,
      );
}

class TelemetryHistoryPoint {
  const TelemetryHistoryPoint({
    required this.timestamp,
    required this.value,
    required this.parameter,
    this.simulated = false,
  });

  final DateTime timestamp;
  final double value;
  final String parameter;

  /// True when this point was recorded during a simulation session, so an
  /// exported dataset can be told apart from genuine measurements.
  final bool simulated;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'value': value,
        'parameter': parameter,
        'simulated': simulated,
      };

  factory TelemetryHistoryPoint.fromJson(Map<String, dynamic> json) =>
      TelemetryHistoryPoint(
        timestamp: DateTime.parse(json['timestamp'] as String),
        value: (json['value'] as num).toDouble(),
        parameter: json['parameter'] as String,
        simulated: json['simulated'] as bool? ?? false,
      );
}
