import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/enum_labels.dart';
import '../../modules/diagnostics/diagnostics_controller.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/common_widgets.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final diagnostics = Get.find<DiagnosticsController>();
    final telemetry = Get.find<TelemetryController>();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'System Diagnostics',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        if (!telemetry.canControl)
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock, color: AppTheme.warningOrange),
              title: Text('View-only access'),
              subtitle: Text('Administrator privileges required for diagnostics controls'),
            ),
          ),
        const SectionHeader(title: 'Actuator Testing'),
        ...ActuatorType.values.map(
          (type) => Card(
            child: ListTile(
              title: Text(EnumLabels.actuator(type)),
              subtitle: const Text('Pulse actuator for 3 seconds'),
              trailing: Obx(() => diagnostics.isTestingActuator.value
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: diagnostics.canControl
                          ? () => diagnostics.testActuator(type)
                          : null,
                    )),
            ),
          ),
        ),
        Obx(() {
          if (diagnostics.lastTestResult.value.isEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(diagnostics.lastTestResult.value),
          );
        }),
        const SectionHeader(title: 'Simulate Sensor Values'),
        ...SensorType.values.map((sensor) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(EnumLabels.sensor(sensor),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Slider(
                    value: diagnostics.simulatedValues[sensor] ?? _defaultFor(sensor),
                    min: _minFor(sensor),
                    max: _maxFor(sensor),
                    divisions: 20,
                    label: (diagnostics.simulatedValues[sensor] ?? _defaultFor(sensor))
                        .toStringAsFixed(1),
                    onChanged: telemetry.canControl
                        ? (v) => diagnostics.setSimulatedValue(sensor, v)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
        const SectionHeader(title: 'Simulate Actuator Failures'),
        ...ActuatorType.values.map(
          (type) => Obx(() {
            final snapshot = telemetry.current.value;
            final hasFailure = snapshot?.actuator(type).hasFailure ?? false;
            return SwitchListTile(
              title: Text('${EnumLabels.actuator(type)} failure'),
              value: hasFailure,
              onChanged: diagnostics.canControl
                  ? (v) => diagnostics.simulateActuatorFailure(type, v)
                  : null,
            );
          }),
        ),
        const SectionHeader(title: 'System Event Log'),
        Obx(() {
          if (telemetry.events.isEmpty) {
            return const EmptyState(message: 'No diagnostic events');
          }
          return Column(
            children: telemetry.events
                .take(20)
                .map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e.message),
                    subtitle: Text('${e.category.name} · ${e.timestamp}'),
                  ),
                )
                .toList(),
          );
        }),
      ],
    );
  }

  double _defaultFor(SensorType sensor) {
    switch (sensor) {
      case SensorType.temperature:
        return 32;
      case SensorType.humidity:
        return 60;
      case SensorType.ammonia:
        return 15;
      case SensorType.ambientLight:
        return 300;
      case SensorType.feedLevel:
        return 70;
      case SensorType.waterLevel:
        return 75;
      case SensorType.battery:
        return 85;
    }
  }

  double _minFor(SensorType sensor) {
    switch (sensor) {
      case SensorType.temperature:
        return 15;
      case SensorType.humidity:
        return 20;
      case SensorType.ammonia:
        return 0;
      case SensorType.ambientLight:
        return 0;
      case SensorType.feedLevel:
      case SensorType.waterLevel:
      case SensorType.battery:
        return 0;
    }
  }

  double _maxFor(SensorType sensor) {
    switch (sensor) {
      case SensorType.temperature:
        return 45;
      case SensorType.humidity:
        return 100;
      case SensorType.ammonia:
        return 50;
      case SensorType.ambientLight:
        return 1000;
      case SensorType.feedLevel:
      case SensorType.waterLevel:
      case SensorType.battery:
        return 100;
    }
  }
}
