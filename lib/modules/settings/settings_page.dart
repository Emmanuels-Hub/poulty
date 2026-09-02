import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/enums.dart';
import '../../core/services/esp32_ble_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/enum_labels.dart';
import '../../core/services/notification_service.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/common_widgets.dart';
import '../history/history_page.dart';
import '../simulation/simulation_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TelemetryController>();

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
          const SectionHeader(title: 'Appearance'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme',
                    style: TextStyle(color: AppTheme.secondaryText(context)),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode),
                        label: Text('Dark'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto),
                        label: Text('System'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        c.setThemeMode(selection.first),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Operating Mode'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<OperatingMode>(
                    initialValue:
                        snapshot?.operatingMode ?? OperatingMode.automatic,
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
                  const SizedBox(height: 8),
                  Text(
                    'Manual mode activates the actuator switches on the '
                    'dashboard. In Automatic the controller runs them.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.secondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'Production Stage'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<PoultryStage>(
                initialValue: snapshot?.poultryStage ?? PoultryStage.starter,
                decoration: const InputDecoration(labelText: 'Growth Stage'),
                items: PoultryStage.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(EnumLabels.poultryStage(s)),
                      ),
                    )
                    .toList(),
                // Starter is the only supported stage.
                onChanged: null,
              ),
            ),
          ),
          const SectionHeader(title: 'ESP32 Connection (Bluetooth)'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    c.isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: c.isConnected
                        ? AppTheme.successGreen
                        : AppTheme.secondaryText(context),
                  ),
                  title: Text(
                    c.activeDevice.value?.name ?? 'No controller paired',
                  ),
                  subtitle: Text(
                    EnumLabels.connectionStatus(c.connectionStatus.value),
                  ),
                  trailing: c.isConnected
                      ? TextButton(
                          onPressed: canControl ? c.disconnectDevice : null,
                          child: const Text('Disconnect'),
                        )
                      : TextButton(
                          onPressed: canControl
                              ? () => _showScanSheet(context, c)
                              : null,
                          child: const Text('Scan'),
                        ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Demo data when disconnected'),
                  subtitle: const Text(
                    'Show generated readings while no controller is linked',
                  ),
                  value: settings.useDemoDataWhenDisconnected,
                  onChanged: canControl
                      ? (v) => c.saveSettings(
                          settings.copyWith(useDemoDataWhenDisconnected: v),
                        )
                      : null,
                ),
                if (!c.isConnected && c.lastConnectionError.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.error_outline,
                      color: AppTheme.criticalRed,
                    ),
                    title: const Text('Last connection error'),
                    subtitle: Text(c.lastConnectionError),
                  ),
                ],
              ],
            ),
          ),
          const SectionHeader(title: 'Data'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.show_chart),
                  title: const Text('Sensor history'),
                  subtitle: const Text(
                    'Logged readings, statistics and CSV export',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.to(() => const HistoryPage()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.science_outlined,
                    color: c.isSimulating ? AppTheme.warningOrange : null,
                  ),
                  title: const Text('Simulation'),
                  subtitle: Text(
                    c.isSimulating
                        ? 'Running — actuators are following injected values'
                        : 'Inject sensor readings and watch the actuators react',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Get.to(() => const SimulationPage()),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Load Cell Calibration'),
          Card(
            child: Column(
              children: [
                if (snapshot != null &&
                    (!snapshot.feedScaleTared || !snapshot.waterScaleTared))
                  ListTile(
                    leading: const Icon(
                      Icons.warning_amber,
                      color: AppTheme.warningOrange,
                    ),
                    title: const Text('Levels are not calibrated'),
                    subtitle: Text(
                      'Feed and water percentages stay unreliable until '
                      '${!snapshot.feedScaleTared && !snapshot.waterScaleTared ? 'both scales are' : 'the scale is'} '
                      'zeroed with the container empty.',
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.scale),
                  title: const Text('Feed scale'),
                  subtitle: Text(
                    snapshot?.feedScaleTared ?? true
                        ? 'Zero point saved'
                        : 'Never zeroed',
                  ),
                  trailing: TextButton(
                    onPressed: canControl && c.isConnected
                        ? () => _tare(context, c, 'feed', 'feed')
                        : null,
                    child: const Text('Zero'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.scale),
                  title: const Text('Water scale'),
                  subtitle: Text(
                    snapshot?.waterScaleTared ?? true
                        ? 'Zero point saved'
                        : 'Never zeroed',
                  ),
                  trailing: TextButton(
                    onPressed: canControl && c.isConnected
                        ? () => _tare(context, c, 'water', 'water')
                        : null,
                    child: const Text('Zero'),
                  ),
                ),
                if (!c.isConnected)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      'Connect to the controller to calibrate.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryText(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SectionHeader(title: 'Notifications'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Alert notifications'),
              subtitle: const Text(
                'Get warned about temperature, air purity, feed and water '
                'even when the app is closed',
              ),
              trailing: TextButton(
                onPressed: () async {
                  final granted = await Get.find<NotificationService>()
                      .requestPermission();
                  Get.snackbar(
                    granted ? 'Notifications on' : 'Notifications blocked',
                    granted
                        ? 'Alerts will be delivered to this phone.'
                        : 'Enable notifications for Smart Poultry in your '
                              'phone settings.',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                },
                child: const Text('Enable'),
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Zeroing is destructive if the container is not empty, so it is confirmed
  /// and explained rather than being a bare button.
  Future<void> _tare(
    BuildContext context,
    TelemetryController c,
    String scale,
    String label,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Zero the $label scale?'),
        content: Text(
          'The controller will record the weight on the $label scale right '
          'now as "empty".\n\n'
          'Only do this with the container actually empty — otherwise every '
          'level reading will be wrong until you redo it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('It is empty, zero it'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final sent = await c.tareScale(scale);
    Get.snackbar(
      sent ? 'Scale zeroed' : 'Could not zero the scale',
      sent
          ? 'The $label zero point is saved on the controller.'
          : 'The controller did not accept the command.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> _showScanSheet(
    BuildContext context,
    TelemetryController c,
  ) async {
    c.startScan();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Nearby controllers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Obx(
                      () => c.isScanning.value
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: c.startScan,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Obx(() {
                final found = c.discoveredDevices;
                if (found.isEmpty) {
                  return EmptyState(
                    icon: Icons.bluetooth_searching,
                    message: c.isScanning.value
                        ? 'Scanning for your ESP32…'
                        : 'No controllers found. Make sure the ESP32 is '
                              'powered on and advertising.',
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: found.length,
                    itemBuilder: (context, index) {
                      final device = found[index];
                      return ListTile(
                        leading: const Icon(Icons.memory),
                        title: Text(
                          device.name.isEmpty ? 'Unnamed device' : device.name,
                        ),
                        subtitle: Text('${device.id} · ${device.rssi} dBm'),
                        trailing: const Icon(Icons.link),
                        onTap: () => _pair(ctx, c, device),
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );

    await c.stopScan();
  }

  Future<void> _pair(
    BuildContext sheetContext,
    TelemetryController c,
    DiscoveredDevice device,
  ) async {
    final connected = await c.pairAndConnect(device);
    if (!sheetContext.mounted) return;
    Navigator.pop(sheetContext);
    Get.snackbar(
      connected ? 'Connected' : 'Connection failed',
      connected
          ? 'Linked to ${device.name}'
          : 'Could not connect to ${device.name}. Check that it is powered on.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
