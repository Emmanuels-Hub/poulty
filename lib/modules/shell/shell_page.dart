import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/enum_labels.dart';
import '../../modules/auth/auth_controller.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/common_widgets.dart';
import '../analytics/analytics_page.dart';
import '../dashboard/dashboard_page.dart';
import '../devices/devices_page.dart';
import '../livefeed/live_feed_page.dart';
import '../notifications/notifications_page.dart';
import '../settings/settings_page.dart';
import '../simulation/simulation_page.dart';
import '../users/users_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  static const _alertsIndex = 3;

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final telemetry = Get.find<TelemetryController>();

    const pages = [
      DashboardPage(),
      AnalyticsPage(),
      LiveFeedPage(),
      NotificationsPage(),
      SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Poultry'),
        actions: [
          Obx(() {
            final status = telemetry.connectionStatus.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: StatusChip(
                label: EnumLabels.connectionStatus(status),
                color: switch (status) {
                  DeviceConnectionStatus.connected => AppTheme.successGreen,
                  DeviceConnectionStatus.connecting => AppTheme.warningOrange,
                  DeviceConnectionStatus.disconnected => AppTheme.criticalRed,
                },
                icon: status == DeviceConnectionStatus.connected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
              ),
            );
          }),
          Obx(() {
            final count = telemetry.unreadNotificationCount;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => setState(() => _index = _alertsIndex),
                ),
                if (count > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.criticalRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (value) {
              if (value == 'logout') auth.logout();
              if (value == 'users') Get.to(() => const UsersPage());
              if (value == 'devices') Get.to(() => const DevicesPage());
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Obx(
                  () => Text(
                    auth.user.value?.displayName ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (auth.isAdmin)
                const PopupMenuItem(
                  value: 'users',
                  child: Text('User Management'),
                ),
              if (auth.isAdmin)
                const PopupMenuItem(
                  value: 'devices',
                  child: Text('Device Management'),
                ),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // A running simulation means the actuators are following injected
          // values, so it stays visible on every tab rather than only on the
          // page that started it.
          Obx(() {
            if (!telemetry.isSimulating) return const SizedBox.shrink();
            return Material(
              color: AppTheme.warningOrange,
              child: InkWell(
                onTap: () => Get.to(() => const SimulationPage()),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.science,
                          size: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Simulation running — readings are injected',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: telemetry.stopSimulation,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Stop'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          Expanded(
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Live Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
