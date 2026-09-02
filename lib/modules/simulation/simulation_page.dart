import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/enum_labels.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/common_widgets.dart';

/// Range and unit for each sensor slider.
class _SensorRange {
  const _SensorRange(this.min, this.max, this.unit, this.icon);

  final double min;
  final double max;
  final String unit;
  final IconData icon;
}

const Map<SensorType, _SensorRange> _ranges = {
  SensorType.temperature: _SensorRange(15, 45, '°C', Icons.thermostat),
  SensorType.humidity: _SensorRange(0, 100, '%', Icons.water_drop),
  SensorType.airPurity: _SensorRange(0, 100, '%', Icons.air),
  SensorType.feedLevel: _SensorRange(0, 100, '%', Icons.grain),
  SensorType.waterLevel: _SensorRange(0, 100, '%', Icons.water),
};

/// Injects sensor readings so the actuators respond to them.
///
/// With a controller connected the values go to the ESP32, which runs its own
/// control logic and drives the real relays. Without one they drive the local
/// demo generator instead, so the flow can still be shown.
class SimulationPage extends StatelessWidget {
  const SimulationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TelemetryController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Simulation')),
      body: Obx(() {
        final snapshot = c.current.value;
        final active = c.isSimulating;
        final connected = c.isConnected;
        final canControl = c.canControl;
        final isAutomatic =
            snapshot?.operatingMode == OperatingMode.automatic;

        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _StatusBanner(active: active, connected: connected),

            if (!canControl)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.visibility, color: AppTheme.infoBlue),
                  title: Text('View-only mode'),
                  subtitle: Text('Administrators can run simulations'),
                ),
              ),

            // Injected values only move the relays while the controller is in
            // charge of them; in Manual it is waiting for the operator.
            if (active && !isAutomatic)
              Card(
                color: AppTheme.warningOrange.withValues(alpha: 0.12),
                child: const ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: AppTheme.warningOrange,
                  ),
                  title: Text('System is in Manual mode'),
                  subtitle: Text(
                    'Switch to Automatic in Settings for the actuators to '
                    'respond to simulated readings.',
                  ),
                ),
              ),

            const SectionHeader(title: 'Session'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      active ? Icons.science : Icons.science_outlined,
                      color: active
                          ? AppTheme.warningOrange
                          : AppTheme.secondaryText(context),
                    ),
                    title: Text(active ? 'Simulation running' : 'Not running'),
                    subtitle: Text(
                      active
                          ? 'Ends automatically after at most '
                                '${AppConstants.simulationMaxDuration.inMinutes} minutes'
                          : 'Runs for '
                                '${AppConstants.simulationDefaultDuration.inMinutes} minutes, '
                                'then stops on its own',
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: canControl && !active
                                ? () => _start(context, c)
                                : null,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: canControl && active
                                ? () => c.stopSimulation()
                                : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SectionHeader(title: 'Sensor Values'),
            if (!active)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Start a session to inject readings.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ..._ranges.entries.map(
              (entry) => _SensorSlider(
                sensor: entry.key,
                range: entry.value,
                enabled: canControl && active,
                controller: c,
              ),
            ),

            const SectionHeader(title: 'Actuator Response'),
            Card(
              child: Column(
                children: ActuatorType.values.map((type) {
                  final state = snapshot?.actuator(type);
                  final isOn = state?.isOn ?? false;
                  return ListTile(
                    leading: Icon(
                      type == ActuatorType.ventilationFan
                          ? Icons.air
                          : Icons.whatshot,
                      color: isOn
                          ? AppTheme.successGreen
                          : AppTheme.secondaryText(context),
                    ),
                    title: Text(EnumLabels.actuator(type)),
                    subtitle: Text(isOn ? 'Running' : 'Idle'),
                    trailing: StatusChip(
                      label: isOn ? 'ON' : 'OFF',
                      color: isOn
                          ? AppTheme.successGreen
                          : AppTheme.secondaryText(context),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SectionHeader(title: 'Safety'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _safetyNote(
                      context,
                      Icons.sensors,
                      'Real sensors keep running',
                      'The controller still reads its own sensors the whole '
                          'time. Simulation only replaces the numbers its '
                          'control logic sees.',
                    ),
                    _safetyNote(
                      context,
                      Icons.local_fire_department,
                      'Real overheating always wins',
                      'If the actual temperature reaches '
                          '${AppConstants.starterTempCriticalMax.toStringAsFixed(0)}°C the '
                          'session is cancelled, the fan is forced on and the '
                          'heat lamp off. No simulated value can suppress that.',
                    ),
                    _safetyNote(
                      context,
                      Icons.assignment_outlined,
                      'The dataset stays honest',
                      'With a controller connected, readings logged during a '
                          'session are marked as simulated in the CSV export. '
                          'Without one, nothing is logged at all.',
                    ),
                    _safetyNote(
                      context,
                      Icons.timer_outlined,
                      'It stops on its own',
                      'A session cannot run longer than '
                          '${AppConstants.simulationMaxDuration.inMinutes} minutes, and ends '
                          'immediately if the Bluetooth link drops.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _safetyNote(
    BuildContext context,
    IconData icon,
    String title,
    String body,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.successGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _start(BuildContext context, TelemetryController c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start simulation?'),
        content: Text(
          c.isConnected
              ? 'The controller will act on the readings you inject and drive '
                    'the real fan and heat lamp.\n\n'
                    'Make sure no birds are relying on the coop right now.'
              : 'No controller is connected, so this drives the on-screen '
                    'demo only. Nothing physical will move.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final started = await c.startSimulation();
    if (!started && c.isConnected) {
      Get.snackbar(
        'Could not start',
        'The controller did not accept the command. Check the connection.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.active, required this.connected});

  final bool active;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();

    final color = connected ? AppTheme.warningOrange : AppTheme.infoBlue;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.science, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              connected
                  ? 'Simulation is driving the real actuators.'
                  : 'Simulation is running on demo data only.',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorSlider extends StatefulWidget {
  const _SensorSlider({
    required this.sensor,
    required this.range,
    required this.enabled,
    required this.controller,
  });

  final SensorType sensor;
  final _SensorRange range;
  final bool enabled;
  final TelemetryController controller;

  @override
  State<_SensorSlider> createState() => _SensorSliderState();
}

class _SensorSliderState extends State<_SensorSlider> {
  /// Held while the thumb is being dragged.
  ///
  /// Slider.onChanged fires on every tick, and sending each one would put
  /// dozens of BLE writes a second into the controller's command buffer. The
  /// drag is tracked locally and committed once, on release.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = widget.controller;
      final range = widget.range;
      final sensor = widget.sensor;

      final isOverridden = controller.simulatedSensors.contains(sensor);
      final value = _dragValue ??
          controller.simulationValues[sensor] ??
          _liveValue() ??
          (range.min + range.max) / 2;

      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(range.icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      EnumLabels.sensor(sensor),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (isOverridden)
                    const StatusChip(
                      label: 'Simulated',
                      color: AppTheme.warningOrange,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '${value.toStringAsFixed(1)}${range.unit}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: value.clamp(range.min, range.max),
                min: range.min,
                max: range.max,
                divisions: ((range.max - range.min) * 2).round(),
                label: '${value.toStringAsFixed(1)}${range.unit}',
                onChanged: widget.enabled
                    ? (v) => setState(() => _dragValue = v)
                    : null,
                onChangeEnd: widget.enabled
                    ? (v) {
                        setState(() => _dragValue = null);
                        controller.setSimulatedSensor(sensor, v);
                      }
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: widget.enabled && isOverridden
                      ? () => controller.clearSimulatedSensor(sensor)
                      : null,
                  child: const Text('Use real reading'),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  double? _liveValue() {
    final snapshot = widget.controller.current.value;
    if (snapshot == null) return null;
    switch (widget.sensor) {
      case SensorType.temperature:
        return snapshot.temperatureC;
      case SensorType.humidity:
        return snapshot.humidityPercent;
      case SensorType.airPurity:
        return snapshot.airPurityPercent;
      case SensorType.feedLevel:
        return snapshot.feedLevelPercent;
      case SensorType.waterLevel:
        return snapshot.waterLevelPercent;
    }
  }
}
