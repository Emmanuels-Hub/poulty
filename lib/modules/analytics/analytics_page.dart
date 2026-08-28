import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/telemetry_model.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/history_chart.dart';

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<TelemetryController>();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historical Analytics',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Readings are averaged into trend points, so values are '
                'approximate.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
        Obx(
          () => HistoryChart(
            title: 'Temperature',
            unit: '°C',
            data: List<TelemetryHistoryPoint>.from(c.temperatureHistory),
            color: AppTheme.criticalRed,
          ),
        ),
        Obx(
          () => HistoryChart(
            title: 'Humidity',
            unit: '%',
            data: List<TelemetryHistoryPoint>.from(c.humidityHistory),
            color: AppTheme.infoBlue,
            decimals: 0,
          ),
        ),
        Obx(
          () => HistoryChart(
            title: 'Air Purity',
            unit: '%',
            data: List<TelemetryHistoryPoint>.from(c.airPurityHistory),
            color: AppTheme.successGreen,
            minY: 0,
            maxY: 100,
            decimals: 0,
          ),
        ),
        Obx(
          () => HistoryChart(
            title: 'Feed Level',
            unit: '%',
            data: List<TelemetryHistoryPoint>.from(c.feedHistory),
            color: AppTheme.accentAmber,
            minY: 0,
            maxY: 100,
            decimals: 0,
          ),
        ),
        Obx(
          () => HistoryChart(
            title: 'Water Level',
            unit: '%',
            data: List<TelemetryHistoryPoint>.from(c.waterHistory),
            color: AppTheme.infoBlue,
            minY: 0,
            maxY: 100,
            decimals: 0,
          ),
        ),
      ],
    );
  }
}
