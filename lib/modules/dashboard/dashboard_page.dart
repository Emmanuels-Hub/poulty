import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
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

      return RefreshIndicator(
        onRefresh: c.refreshNow,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
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
                  value: snapshot.temperatureC.toStringAsFixed(1),
                  unit: '°C',
                  icon: Icons.thermostat,
                  color: AppTheme.criticalRed,
                ),
                MetricCard(
                  title: 'Humidity',
                  value: snapshot.humidityPercent.toStringAsFixed(0),
                  unit: '%',
                  icon: Icons.water_drop,
                  color: AppTheme.infoBlue,
                ),
                MetricCard(
                  title: 'Air Purity',
                  value: snapshot.airPurityPercent.toStringAsFixed(0),
                  unit: '%',
                  icon: Icons.air,
                  color: snapshot.airPurityPercent <
                          AppConstants.starterAirPurityMin
                      ? AppTheme.criticalRed
                      : AppTheme.successGreen,
                  subtitle: _airPurityLabel(snapshot.airPurityPercent),
                ),
                MetricCard(
                  title: 'Feed Level',
                  value: snapshot.feedLevelPercent.toStringAsFixed(0),
                  unit: '%',
                  icon: Icons.grain,
                  color: AppTheme.accentAmber,
                ),
                MetricCard(
                  title: 'Water Level',
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
