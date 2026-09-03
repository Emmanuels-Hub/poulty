import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/telemetry_model.dart';
import '../../core/utils/enum_labels.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/common_widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TelemetryController>();

    return Obx(() {
      final snapshot = c.current.value;
      if (snapshot == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final isManual = c.isManualModeActive;
      final hasData = c.hasLiveData.value;

      return RefreshIndicator(
        onRefresh: c.refreshNow,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Without this, zeros read as measurements rather than as the
            // absence of one.
            if (!hasData)
              Container(
                margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withValues(alpha: 0.10),
                  border: Border.all(
                    color: AppTheme.infoBlue.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.sensors_off,
                      size: 18,
                      color: AppTheme.infoBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        snapshot.simulationMode
                            ? 'Simulated readings — no controller connected, '
                                  'so nothing is being logged.'
                            : 'No readings. Connect the controller in '
                                  'Settings; values show zero until then.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.infoBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coop Overview',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Updated ${DateFormat.Hms().format(snapshot.timestamp)}',
                          style: TextStyle(
                            color: AppTheme.secondaryText(context),
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: EnumLabels.poultryStage(snapshot.poultryStage),
                    color: AppTheme.accentAmber,
                    icon: Icons.timeline,
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              child: Row(
                children: [
                  StatusChip(
                    label: EnumLabels.operatingMode(snapshot.operatingMode),
                    color: AppTheme.infoBlue,
                    icon: isManual ? Icons.pan_tool_alt : Icons.auto_mode,
                  ),
                  SizedBox(width: 8.w),
                  StatusChip(
                    label: snapshot.isDaytime ? 'Day' : 'Night',
                    color: snapshot.isDaytime
                        ? AppTheme.accentAmber
                        : AppTheme.infoBlue,
                    icon: snapshot.isDaytime
                        ? Icons.wb_sunny
                        : Icons.nightlight_round,
                  ),
                ],
              ),
            ),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              childAspectRatio: () {
                final w = MediaQuery.of(context).size.width;
                if (w >= 600) return 1.6; // tablets / wide screens
                if (w >= 400) return 1.4; // normal phones
                return 1.2; // small phones (< 400px)
              }(),
              children: [
                MetricCard(
                  title: 'Temperature',
                  trailing: _simulatedMark(snapshot, SensorType.temperature),
                  value: snapshot.temperatureC.toStringAsFixed(1),
                  unit: '°C',
                  icon: Icons.thermostat,
                  color: AppTheme.criticalRed,
                ),
                MetricCard(
                  title: 'Humidity',
                  trailing: _simulatedMark(snapshot, SensorType.humidity),
                  value: snapshot.humidityPercent.toStringAsFixed(0),
                  unit: '%',
                  icon: Icons.water_drop,
                  color: AppTheme.infoBlue,
                ),
                MetricCard(
                  title: 'Air Purity',
                  trailing: !snapshot.airPuritySensorOk
                      ? const Tooltip(
                          message: 'Gas sensor not detected',
                          child: Icon(
                            Icons.error_outline,
                            size: 14,
                            color: AppTheme.criticalRed,
                          ),
                        )
                      : _simulatedMark(snapshot, SensorType.airPurity),
                  value: snapshot.airPuritySensorOk
                      ? snapshot.airPurityPercent.toStringAsFixed(0)
                      : '--',
                  unit: '%',
                  icon: Icons.air,
                  color: !snapshot.airPuritySensorOk
                      ? AppTheme.criticalRed
                      : snapshot.airPurityPercent <
                            AppConstants.starterAirPurityMin
                      ? AppTheme.criticalRed
                      : AppTheme.successGreen,
                  subtitle: snapshot.airPuritySensorOk
                      ? _airPurityLabel(snapshot.airPurityPercent)
                      : 'Sensor not detected',
                ),
                MetricCard(
                  title: 'Feed Level',
                  trailing: _simulatedMark(snapshot, SensorType.feedLevel),
                  value: snapshot.feedLevelPercent.toStringAsFixed(0),
                  unit: '%',
                  icon: Icons.grain,
                  color: AppTheme.accentAmber,
                ),
                MetricCard(
                  title: 'Water Level',
                  trailing: _simulatedMark(snapshot, SensorType.waterLevel),
                  value: snapshot.waterLevelPercent.toStringAsFixed(0),
                  unit: '%',
                  icon: Icons.water,
                  color: AppTheme.infoBlue,
                ),
              ],
            ),
            const SectionHeader(title: 'Actuators'),
            if (!isManual)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.lock_outline,
                    color: AppTheme.infoBlue,
                  ),
                  title: const Text('Manual control is off'),
                  subtitle: const Text(
                    'Switch Operating Mode to Manual in Settings to control '
                    'actuators by hand.',
                  ),
                  dense: true,
                  textColor: AppTheme.secondaryText(context),
                ),
              ),
            ...ActuatorType.values.map((type) {
              final state = snapshot.actuator(type);
              return Card(
                child: ListTile(
                  leading: Icon(
                    _actuatorIcon(type),
                    color: state.isOn
                        ? AppTheme.successGreen
                        : AppTheme.secondaryText(context),
                  ),
                  title: Text(EnumLabels.actuator(type)),
                  subtitle: Text(
                    state.hasFailure
                        ? 'Failure detected'
                        : isManual
                        ? 'Manual control'
                        : 'Automatic control',
                  ),
                  trailing: Switch(
                    value: state.isOn,
                    onChanged: c.canControlActuators
                        ? (v) => _confirmActuator(context, c, type, v)
                        : null,
                  ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  String _airPurityLabel(double percent) {
    if (percent >= 85) return 'Clean';
    if (percent >= AppConstants.starterAirPurityMin) return 'Acceptable';
    if (percent >= 40) return 'Poor';
    return 'Hazardous';
  }

  /// A small marker on any reading the controller is not actually measuring
  /// right now, so an injected value is never mistaken for a real one.
  static Widget? _simulatedMark(TelemetrySnapshot snapshot, SensorType sensor) {
    if (!snapshot.isSimulated(sensor)) return null;
    return const Tooltip(
      message: 'Simulated value',
      child: Icon(Icons.science, size: 14, color: AppTheme.warningOrange),
    );
  }

  IconData _actuatorIcon(ActuatorType type) {
    switch (type) {
      case ActuatorType.ventilationFan:
        return Icons.wind_power;
      case ActuatorType.heatLamp:
        return Icons.whatshot;
    }
  }

  Future<void> _confirmActuator(
    BuildContext context,
    TelemetryController c,
    ActuatorType type,
    bool value,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Manual Control'),
        content: Text(
          'Turn ${EnumLabels.actuator(type)} ${value ? 'ON' : 'OFF'}?\n\n'
          'Manual control will automatically revert after '
          '${AppConstants.manualActuatorTimeout.inMinutes} minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await c.toggleActuator(type, value);
    }
  }
}
