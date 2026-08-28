import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/enum_labels.dart';
import '../../modules/auth/auth_controller.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../analytics/analytics_page.dart';
import '../camera/camera_page.dart';

import '../dashboard/dashboard_page.dart';
import '../diagnostics/diagnostics_page.dart';
import '../notifications/notifications_page.dart';
import '../settings/settings_page.dart';
import '../../widgets/common_widgets.dart';
import '../devices/devices_page.dart';
import '../users/users_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final telemetry = Get.find<TelemetryController>();

    final pages = [
      const DashboardPage(),
      const AnalyticsPage(),
      const CameraPage(),
      const NotificationsPage(),
      const DiagnosticsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Poultry'),
        actions: [
          Obx(() {
            final status = telemetry.connectionStatus.value;
            final color = status == DeviceConnectionStatus.offline
                ? AppTheme.criticalRed
                : AppTheme.successGreen;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: StatusChip(
                label: EnumLabels.connectionStatus(status),
                color: color,
                icon: status == DeviceConnectionStatus.offline
                    ? Icons.cloud_off
                    : Icons.cloud_done,
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
                  onPressed: () => setState(() => _index = 3),
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
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
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
                child: Obx(() => Text(
                      auth.user.value?.displayName ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )),
              ),
              if (auth.isAdmin)
                const PopupMenuItem(value: 'users', child: Text('User Management')),
              if (auth.isAdmin)
                const PopupMenuItem(value: 'devices', child: Text('Device Management')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), selectedIcon: Icon(Icons.camera_alt), label: 'Camera'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: 'Diagnostics'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}