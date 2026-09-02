import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/history_service.dart';
import '../../core/theme/app_theme.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/history_chart.dart';

/// Logged sensor history, with per-parameter stats and a CSV export.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TelemetryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export CSV',
            onPressed: () => _export(context, c),
          ),
          Obx(
            () => c.canControl
                ? IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear history',
                    onPressed: () => _confirmClear(context, c),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(() {
        // Rebuilds whenever a new point is logged.
        c.historyRevision.value;

        final history = c.history;
        if (history.isEmpty) {
          return const EmptyState(
            icon: Icons.show_chart,
            message: 'No readings logged yet.\n'
                'History is recorded once a minute while monitoring.',
          );
        }

        final oldest = history.oldestPoint;

        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage),
                title: Text('${history.pointCount} points logged'),
                subtitle: Text(
                  oldest == null
                      ? 'Recording once a minute'
                      : 'Since ${DateFormat.MMMd().add_Hm().format(oldest)} · '
                            'one point a minute',
                ),
              ),
            ),
            ...historyParameters.map((parameter) {
              final series = history.series(parameter.key);
              final stats = history.stats(parameter.key);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: parameter.label),
                  HistoryChart(
                    title: parameter.label,
                    unit: parameter.unit,
                    data: series,
                    color: _colorFor(parameter.key),
                    minY: parameter.axisMin,
                    maxY: parameter.axisMax,
                  ),
                  if (stats.count > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          _stat(context, 'Min', stats.min, parameter.unit),
                          _stat(context, 'Avg', stats.average, parameter.unit),
                          _stat(context, 'Max', stats.max, parameter.unit),
                        ],
                      ),
                    ),
                ],
              );
            }),
          ],
        );
      }),
    );
  }

  Widget _stat(BuildContext context, String label, double value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.secondaryText(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Color _colorFor(String key) {
    switch (key) {
      case 'temperature':
        return AppTheme.criticalRed;
      case 'humidity':
        return AppTheme.infoBlue;
      case 'airPurity':
        return AppTheme.successGreen;
      case 'feed':
        return AppTheme.accentAmber;
      default:
        return AppTheme.infoBlue;
    }
  }

  Future<void> _export(BuildContext context, TelemetryController c) async {
    // Make sure anything still buffered in memory lands in the export.
    await c.history.flush();

    if (c.history.isEmpty) {
      Get.snackbar(
        'Nothing to export',
        'No readings have been logged yet.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      final csv = c.history.toCsv();
      final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/smart_poultry_$stamp.csv');
      await file.writeAsString(csv);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: 'Smart Poultry sensor log',
          text: 'Sensor readings exported $stamp',
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Export failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    TelemetryController c,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'This permanently deletes every logged reading. Export first if you '
          'still need the data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.criticalRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) await c.clearHistory();
  }
}
