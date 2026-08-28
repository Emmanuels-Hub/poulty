import '../../core/constants/enums.dart';
import '../../core/utils/json_utils.dart';

class StageThresholds {
  const StageThresholds({
    required this.stage,
    this.tempMin = 28,
    this.tempMax = 35,
    this.humidityMin = 50,
    this.humidityMax = 70,
    this.ammoniaMax = 25,
    this.feedLowThreshold = 20,
    this.waterLowThreshold = 15,
    this.targetLightHours = 16,
  });

  final PoultryStage stage;
  final double tempMin;
  final double tempMax;
  final double humidityMin;
  final double humidityMax;
  final double ammoniaMax;
  final double feedLowThreshold;
  final double waterLowThreshold;
  final double targetLightHours;

  StageThresholds copyWith({
    PoultryStage? stage,
    double? tempMin,
    double? tempMax,
    double? humidityMin,
    double? humidityMax,
    double? ammoniaMax,
    double? feedLowThreshold,
    double? waterLowThreshold,
    double? targetLightHours,
  }) {
    return StageThresholds(
      stage: stage ?? this.stage,
      tempMin: tempMin ?? this.tempMin,
      tempMax: tempMax ?? this.tempMax,
      humidityMin: humidityMin ?? this.humidityMin,
      humidityMax: humidityMax ?? this.humidityMax,
      ammoniaMax: ammoniaMax ?? this.ammoniaMax,
      feedLowThreshold: feedLowThreshold ?? this.feedLowThreshold,
      waterLowThreshold: waterLowThreshold ?? this.waterLowThreshold,
      targetLightHours: targetLightHours ?? this.targetLightHours,
    );
  }

  Map<String, dynamic> toJson() => {
        'stage': stage.name,
        'tempMin': tempMin,
        'tempMax': tempMax,
        'humidityMin': humidityMin,
        'humidityMax': humidityMax,
        'ammoniaMax': ammoniaMax,
        'feedLowThreshold': feedLowThreshold,
        'waterLowThreshold': waterLowThreshold,
        'targetLightHours': targetLightHours,
      };

  factory StageThresholds.fromJson(Map<String, dynamic> json) => StageThresholds(
        stage: PoultryStage.values.byName(json['stage'] as String),
        tempMin: (json['tempMin'] as num?)?.toDouble() ?? 28,
        tempMax: (json['tempMax'] as num?)?.toDouble() ?? 35,
        humidityMin: (json['humidityMin'] as num?)?.toDouble() ?? 50,
        humidityMax: (json['humidityMax'] as num?)?.toDouble() ?? 70,
        ammoniaMax: (json['ammoniaMax'] as num?)?.toDouble() ?? 25,
        feedLowThreshold: (json['feedLowThreshold'] as num?)?.toDouble() ?? 20,
        waterLowThreshold: (json['waterLowThreshold'] as num?)?.toDouble() ?? 15,
        targetLightHours: (json['targetLightHours'] as num?)?.toDouble() ?? 16,
      );
}

class LightingSchedule {
  const LightingSchedule({
    this.onTime = '06:00',
    this.offTime = '22:00',
    this.useSchedule = true,
    this.supplementalMinutes = 0,
  });

  final String onTime;
  final String offTime;
  final bool useSchedule;
  final int supplementalMinutes;

  LightingSchedule copyWith({
    String? onTime,
    String? offTime,
    bool? useSchedule,
    int? supplementalMinutes,
  }) {
    return LightingSchedule(
      onTime: onTime ?? this.onTime,
      offTime: offTime ?? this.offTime,
      useSchedule: useSchedule ?? this.useSchedule,
      supplementalMinutes: supplementalMinutes ?? this.supplementalMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'onTime': onTime,
        'offTime': offTime,
        'useSchedule': useSchedule,
        'supplementalMinutes': supplementalMinutes,
      };

  factory LightingSchedule.fromJson(Map<String, dynamic> json) =>
      LightingSchedule(
        onTime: json['onTime'] as String? ?? '06:00',
        offTime: json['offTime'] as String? ?? '22:00',
        useSchedule: json['useSchedule'] as bool? ?? true,
        supplementalMinutes: json['supplementalMinutes'] as int? ?? 0,
      );
}

class AppSettings {
  const AppSettings({
    this.notificationIntervalMinutes = 5,
    this.batteryLowThreshold = 20,
    this.manualActuatorTimeoutMinutes = 15,
    this.stageThresholds = const [],
    this.lightingSchedule = const LightingSchedule(),
    this.sensorDataSources = const {},
    this.useSimulationWhenOffline = true,
  });

  final int notificationIntervalMinutes;
  final double batteryLowThreshold;
  final int manualActuatorTimeoutMinutes;
  final List<StageThresholds> stageThresholds;
  final LightingSchedule lightingSchedule;
  final Map<String, String> sensorDataSources;
  final bool useSimulationWhenOffline;

  StageThresholds thresholdsFor(PoultryStage stage) {
    return stageThresholds.firstWhere(
      (t) => t.stage == stage,
      orElse: () => StageThresholds(stage: stage),
    );
  }

  AppSettings copyWith({
    int? notificationIntervalMinutes,
    double? batteryLowThreshold,
    int? manualActuatorTimeoutMinutes,
    List<StageThresholds>? stageThresholds,
    LightingSchedule? lightingSchedule,
    Map<String, String>? sensorDataSources,
    bool? useSimulationWhenOffline,
  }) {
    return AppSettings(
      notificationIntervalMinutes:
          notificationIntervalMinutes ?? this.notificationIntervalMinutes,
      batteryLowThreshold: batteryLowThreshold ?? this.batteryLowThreshold,
      manualActuatorTimeoutMinutes:
          manualActuatorTimeoutMinutes ?? this.manualActuatorTimeoutMinutes,
      stageThresholds: stageThresholds ?? this.stageThresholds,
      lightingSchedule: lightingSchedule ?? this.lightingSchedule,
      sensorDataSources: sensorDataSources ?? this.sensorDataSources,
      useSimulationWhenOffline:
          useSimulationWhenOffline ?? this.useSimulationWhenOffline,
    );
  }

  Map<String, dynamic> toJson() => {
        'notificationIntervalMinutes': notificationIntervalMinutes,
        'batteryLowThreshold': batteryLowThreshold,
        'manualActuatorTimeoutMinutes': manualActuatorTimeoutMinutes,
        'stageThresholds': stageThresholds.map((e) => e.toJson()).toList(),
        'lightingSchedule': lightingSchedule.toJson(),
        'sensorDataSources': sensorDataSources,
        'useSimulationWhenOffline': useSimulationWhenOffline,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        notificationIntervalMinutes:
            json['notificationIntervalMinutes'] as int? ?? 5,
        batteryLowThreshold:
            (json['batteryLowThreshold'] as num?)?.toDouble() ?? 20,
        manualActuatorTimeoutMinutes:
            json['manualActuatorTimeoutMinutes'] as int? ?? 15,
        stageThresholds: asJsonMapList(json['stageThresholds'])
            .map(StageThresholds.fromJson)
            .toList(),
        lightingSchedule: json['lightingSchedule'] != null
            ? LightingSchedule.fromJson(asJsonMap(json['lightingSchedule']))
            : const LightingSchedule(),
        sensorDataSources: asStringMap(json['sensorDataSources']),
        useSimulationWhenOffline:
            json['useSimulationWhenOffline'] as bool? ?? true,
      );

  static AppSettings defaults() {
    return AppSettings(
      stageThresholds: PoultryStage.values
          .map((stage) => StageThresholds(stage: stage))
          .toList(),
    );
  }
}
