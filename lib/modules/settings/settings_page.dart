import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/enums.dart';
import '../../core/services/esp32_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/enum_labels.dart';
import '../../data/models/settings_model.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/common_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final c = Get.find<TelemetryController>();
  final api = Get.find<Esp32ApiService>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final settings = c.settings.value;
      final snapshot = c.current.value;
      final canControl = c.canControl;

      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          if (!canControl)
            const Card(
              child: ListTile(
                leading: Icon(Icons.visibility, color: AppTheme.infoBlue),
                title: Text('View-only mode'),
                subtitle: Text('Contact an administrator to change settings'),
              ),
            ),
          const SectionHeader(title: 'Operating Mode'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<OperatingMode>(
                value: snapshot?.operatingMode ?? OperatingMode.automatic,
                decoration: const InputDecoration(labelText: 'System Mode'),
                items: OperatingMode.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(EnumLabels.operatingMode(m)),
                      ),
                    )
                    .toList(),
                onChanged: canControl
                    ? (m) {
                        if (m != null) c.setOperatingMode(m);
                      }
                    : null,
              ),
            ),
          ),
          const SectionHeader(title: 'Production Stage'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<PoultryStage>(
                value: snapshot?.poultryStage ?? PoultryStage.starter,
                decoration: const InputDecoration(labelText: 'Growth Stage'),
                items: PoultryStage.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(EnumLabels.poultryStage(s)),
                      ),
                    )
                    .toList(),
                onChanged: canControl
                    ? (s) {
                        if (s != null) c.setPoultryStage(s);
                      }
                    : null,
              ),
            ),
          ),
          const SectionHeader(title: 'Sensor Data Sources'),
          ...SensorType.values.map((sensor) {
            final source = snapshot?.sourceFor(sensor) ?? DataSource.live;
            return SwitchListTile(
              title: Text(EnumLabels.sensor(sensor)),
              subtitle: Text(source == DataSource.live ? 'Live data' : 'Simulated data'),
              value: source == DataSource.simulated,
              onChanged: canControl
                  ? (v) => c.setSensorSource(
                        sensor,
                        v ? DataSource.simulated : DataSource.live,
                      )
                  : null,
            );
          }),
          const SectionHeader(title: 'Thresholds & Notifications'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Notification interval'),
                    subtitle: Text('${settings.notificationIntervalMinutes} minutes'),
                    trailing: SizedBox(
                      width: 120,
                      child: Slider(
                        value: settings.notificationIntervalMinutes.toDouble(),
                        min: 1,
                        max: 30,
                        divisions: 29,
                        label: '${settings.notificationIntervalMinutes} min',
                        onChanged: canControl
                            ? (v) => _updateSettings(
                                  settings.copyWith(
                                    notificationIntervalMinutes: v.round(),
                                  ),
                                )
                            : null,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Battery low threshold'),
                    subtitle: Text('${settings.batteryLowThreshold.toStringAsFixed(0)}%'),
                    trailing: SizedBox(
                      width: 120,
                      child: Slider(
                        value: settings.batteryLowThreshold,
                        min: 5,
                        max: 50,
                        divisions: 9,
                        onChanged: canControl
                            ? (v) => _updateSettings(
                                  settings.copyWith(batteryLowThreshold: v),
                                )
                            : null,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Manual actuator timeout'),
                    subtitle: Text('${settings.manualActuatorTimeoutMinutes} minutes'),
                    trailing: SizedBox(
                      width: 120,
                      child: Slider(
                        value: settings.manualActuatorTimeoutMinutes.toDouble(),
                        min: 5,
                        max: 60,
                        divisions: 11,
                        onChanged: canControl
                            ? (v) => _updateSettings(
                                  settings.copyWith(
                                    manualActuatorTimeoutMinutes: v.round(),
                                  ),
                                )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Stage Thresholds'),
          ...settings.stageThresholds.map(
            (t) => Card(
              child: ExpansionTile(
                title: Text('${EnumLabels.poultryStage(t.stage)} Stage'),
                children: [
                  _thresholdField('Temp Min (°C)', t.tempMin, canControl, (v) {
                    _updateStageThreshold(t.copyWith(tempMin: v));
                  }),
                  _thresholdField('Temp Max (°C)', t.tempMax, canControl, (v) {
                    _updateStageThreshold(t.copyWith(tempMax: v));
                  }),
                  _thresholdField('Humidity Min (%)', t.humidityMin, canControl, (v) {
                    _updateStageThreshold(t.copyWith(humidityMin: v));
                  }),
                  _thresholdField('Humidity Max (%)', t.humidityMax, canControl, (v) {
                    _updateStageThreshold(t.copyWith(humidityMax: v));
                  }),
                  _thresholdField('Ammonia Max (ppm)', t.ammoniaMax, canControl, (v) {
                    _updateStageThreshold(t.copyWith(ammoniaMax: v));
                  }),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Lighting Schedule'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Use lighting schedule'),
                    value: settings.lightingSchedule.useSchedule,
                    onChanged: canControl
                        ? (v) => _updateSettings(
                              settings.copyWith(
                                lightingSchedule: settings.lightingSchedule
                                    .copyWith(useSchedule: v),
                              ),
                            )
                        : null,
                  ),
                  ListTile(
                    title: const Text('Lights ON'),
                    subtitle: Text(settings.lightingSchedule.onTime),
                    trailing: canControl
                        ? IconButton(
                            icon: const Icon(Icons.schedule),
                            onPressed: () => _pickTime(
                              settings.lightingSchedule.onTime,
                              (t) => _updateSettings(
                                settings.copyWith(
                                  lightingSchedule:
                                      settings.lightingSchedule.copyWith(onTime: t),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  ListTile(
                    title: const Text('Lights OFF'),
                    subtitle: Text(settings.lightingSchedule.offTime),
                    trailing: canControl
                        ? IconButton(
                            icon: const Icon(Icons.schedule),
                            onPressed: () => _pickTime(
                              settings.lightingSchedule.offTime,
                              (t) => _updateSettings(
                                settings.copyWith(
                                  lightingSchedule:
                                      settings.lightingSchedule.copyWith(offTime: t),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Connection'),
          SwitchListTile(
            title: const Text('Simulation mode (no hardware)'),
            subtitle: const Text('Use simulated ESP32 data for development'),
            value: api.useSimulation,
            onChanged: canControl
                ? (v) {
                    api.setUseSimulation(v);
                    setState(() {});
                    c.refreshNow();
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('Simulate when offline'),
            value: settings.useSimulationWhenOffline,
            onChanged: canControl
                ? (v) => _updateSettings(
                      settings.copyWith(useSimulationWhenOffline: v),
                    )
                : null,
          ),
        ],
      );
    });
  }

  Widget _thresholdField(
    String label,
    double value,
    bool enabled,
    ValueChanged<double> onChanged,
  ) {
    return ListTile(
      title: Text(label),
      subtitle: Slider(
        value: value,
        min: 0,
        max: 100,
        divisions: 100,
        label: value.toStringAsFixed(1),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }

  Future<void> _pickTime(String current, ValueChanged<String> onPicked) async {
    final parts = current.split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (time != null) {
      onPicked(
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  void _updateSettings(AppSettings newSettings) {
    c.saveSettings(newSettings);
  }

  void _updateStageThreshold(StageThresholds updated) {
    final settings = c.settings.value;
    final list = settings.stageThresholds.map((t) {
      return t.stage == updated.stage ? updated : t;
    }).toList();
    c.saveSettings(settings.copyWith(stageThresholds: list));
  }
}
