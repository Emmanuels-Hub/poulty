import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';

/// Fixed environmental targets. The system runs the starter stage only, so
/// these are not user-editable.
///
/// The comfort band is [tempMin]..[tempMax]; readings outside the critical
/// bounds escalate an alert from warning to critical. These mirror the
/// thresholds compiled into esp/esp.ino.
class StageThresholds {
  const StageThresholds({
    this.stage = PoultryStage.starter,
    this.tempMin = AppConstants.starterTempMin,
    this.tempMax = AppConstants.starterTempMax,
    this.tempCriticalMin = AppConstants.starterTempCriticalMin,
    this.tempCriticalMax = AppConstants.starterTempCriticalMax,
    this.humidityMin = AppConstants.starterHumidityMin,
    this.humidityMax = AppConstants.starterHumidityMax,
    this.humidityCriticalMin = AppConstants.starterHumidityCriticalMin,
    this.humidityCriticalMax = AppConstants.starterHumidityCriticalMax,
    this.airPurityMin = AppConstants.starterAirPurityMin,
    this.airPurityCriticalMin = AppConstants.starterAirPurityCriticalMin,
    this.feedLowThreshold = AppConstants.starterFeedLowThreshold,
    this.waterLowThreshold = AppConstants.starterWaterLowThreshold,
  });

  static const StageThresholds starter = StageThresholds();

  final PoultryStage stage;
  final double tempMin;
  final double tempMax;
  final double tempCriticalMin;
  final double tempCriticalMax;
  final double humidityMin;
  final double humidityMax;
  final double humidityCriticalMin;
  final double humidityCriticalMax;
  final double airPurityMin;
  final double airPurityCriticalMin;
  final double feedLowThreshold;
  final double waterLowThreshold;
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.useDemoDataWhenDisconnected = false,
  });

  final ThemeMode themeMode;

  /// Show generated readings while no ESP32 is connected.
  ///
  /// Off by default: with nothing connected the dashboard shows zeros, so a
  /// plausible-looking number is never mistaken for a measurement. Generated
  /// readings are never logged or alerted on either way.
  final bool useDemoDataWhenDisconnected;

  StageThresholds get thresholds => StageThresholds.starter;

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? useDemoDataWhenDisconnected,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      useDemoDataWhenDisconnected:
          useDemoDataWhenDisconnected ?? this.useDemoDataWhenDisconnected,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'useDemoDataWhenDisconnected': useDemoDataWhenDisconnected,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == (json['themeMode'] as String? ?? 'system'),
          orElse: () => ThemeMode.system,
        ),
        useDemoDataWhenDisconnected:
            json['useDemoDataWhenDisconnected'] as bool? ?? false,
      );

  static AppSettings defaults() => const AppSettings();
}
