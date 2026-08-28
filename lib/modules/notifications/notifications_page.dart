import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/common_widgets.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TelemetryController>();

    return Obx(() {
      final items = c.notifications;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notifications',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: c.markAllNotificationsRead,
                  child: const Text('Mark all read'),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    message: 'No notifications yet',
                    icon: Icons.notifications_none,
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final n = items[index];
                      return Card(
                        color: n.isActive
                            ? AppTheme.severityColor(n.severity.name)
                                .withValues(alpha: 0.05)
                            : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.severityColor(n.severity.name)
                                .withValues(alpha: 0.15),
                            child: Icon(
                              _iconFor(n.type),
                              color: AppTheme.severityColor(n.severity.name),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.message),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.MMMd().add_Hm().format(n.timestamp),
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (!n.isActive && n.clearedAt != null)
                                Text(
                                  'Cleared ${DateFormat.Hm().format(n.clearedAt!)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                            ],
                          ),
                          trailing: n.isActive
                              ? const Icon(Icons.circle, size: 10, color: AppTheme.criticalRed)
                              : null,
                          onTap: () => c.markNotificationRead(n.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }

  IconData _iconFor(AlertType type) {
    switch (type) {
      case AlertType.abnormalTemperature:
        return Icons.thermostat;
      case AlertType.abnormalHumidity:
        return Icons.water_drop;
      case AlertType.poorAirPurity:
        return Icons.air;
      case AlertType.lowFeed:
        return Icons.grain;
      case AlertType.lowWater:
        return Icons.water;
      case AlertType.actuatorFailure:
        return Icons.error_outline;
      case AlertType.systemRestart:
        return Icons.restart_alt;
      case AlertType.deviceReconnected:
        return Icons.bluetooth_connected;
      case AlertType.custom:
        return Icons.notifications;
    }
  }
}
