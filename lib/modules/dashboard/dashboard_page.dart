import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

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
                            color: AppTheme.textSecondary,
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
                  SizedBox(width: 8.w),
                  StatusChip(
                    label:
                        'Health ${c.systemHealthScore.value.toStringAsFixed(0)}%',
                    color: c.systemHealthScore.value > 70
                        ? AppTheme.successGreen
                        : AppTheme.warningOrange,
                  ),
                  if (c.isOffline.value) ...[
                    SizedBox(width: 8.w),
                    const StatusChip(
                      label: 'Cached Data',
                      color: AppTheme.warningOrange,
                      icon: Icons.offline_bolt,
                    ),
                  ],
                  if (c.queuedCommands.value > 0) ...[
                    SizedBox(width: 8.w),
                    StatusChip(
                      label: '${c.queuedCommands.value} queued',
                      color: AppTheme.infoBlue,
                      icon: Icons.sync,
                    ),
                  ],
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
                return 1.2;              // small phones (< 400px)
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
                  title: 'Ammonia',
                  value: snapshot.ammoniaPpm.toStringAsFixed(1),
                  unit: 'ppm',
                  icon: Icons.cloud,
                  color: AppTheme.warningOrange,
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
                MetricCard(
                  title: 'Battery',
                  value: snapshot.batteryPercent.toStringAsFixed(0),
                  unit: '%',
                  icon: Icons.battery_charging_full,
                  color: AppTheme.successGreen,
                ),
              ],
            ),
            const SectionHeader(title: 'Actuators'),
            ...ActuatorType.values.map((type) {
              final state = snapshot.actuator(type);
              return Card(
                child: ListTile(
                  leading: Icon(
                    _actuatorIcon(type),
                    color: state.isOn
                        ? AppTheme.successGreen
                        : AppTheme.textSecondary,
                  ),
                  title: Text(EnumLabels.actuator(type)),
                  subtitle: Text(
                    state.hasFailure
                        ? 'Failure detected'
                        : state.isManualOverride
                        ? 'Manual override active'
                        : 'Automatic control',
                  ),
                  trailing: Switch(
                    value: state.isOn,
                    onChanged: c.canControl
                        ? (v) => _confirmActuator(context, c, type, v)
                        : null,
                  ),
                ),
              );
            }),
            const SectionHeader(title: 'Recent Events'),
            if (c.events.isEmpty)
              const EmptyState(message: 'No events recorded yet')
            else
              ...c.events
                  .take(5)
                  .map(
                    (e) => ListTile(
                      dense: true,
                      leading: Icon(_eventIcon(e.category), size: 20),
                      title: Text(
                        e.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        DateFormat.MMMd().add_Hm().format(e.timestamp),
                      ),
                    ),
                  ),
            const SectionHeader(title: 'Operating Statistics'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _statRow('Uptime', '${c.uptimeHours.value} hours'),
                    _statRow('WiFi Signal', '${snapshot.wifiRssi} dBm'),
                    _statRow(
                      'Ambient Light',
                      '${snapshot.ambientLightLux.toStringAsFixed(0)} lux',
                    ),
                    _statRow(
                      'Device',
                      c.activeDevice.value?.name ?? 'Not configured',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  IconData _actuatorIcon(ActuatorType type) {
    switch (type) {
      case ActuatorType.ventilationFan:
        return Icons.air;
      case ActuatorType.heatLamp:
        return Icons.whatshot;
      case ActuatorType.lighting:
        return Icons.lightbulb;
    }
  }

  IconData _eventIcon(EventCategory category) {
    switch (category) {
      case EventCategory.alert:
        return Icons.warning_amber;
      case EventCategory.actuator:
        return Icons.power_settings_new;
      case EventCategory.network:
        return Icons.wifi;
      default:
        return Icons.info_outline;
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
          '${c.settings.value.manualActuatorTimeoutMinutes} minutes.',
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
