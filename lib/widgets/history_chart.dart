import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../data/models/telemetry_model.dart';

class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.title,
    required this.unit,
    required this.data,
    required this.color,
    this.minY,
    this.maxY,
  });

  final String title;
  final String unit;
  final List<TelemetryHistoryPoint> data;
  final Color color;
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Card(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text('No $title history yet',
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
        ),
      );
    }

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final values = data.map((e) => e.value).toList();
    final dataMin = values.reduce((a, b) => a < b ? a : b);
    final dataMax = values.reduce((a, b) => a > b ? a : b);
    final chartMinY = minY ?? (dataMin - 2);
    final chartMaxY = maxY ?? (dataMax + 2);
    final safeMaxY = chartMaxY <= chartMinY ? chartMinY + 1 : chartMaxY;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: chartMinY,
                  maxY: safeMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: (data.length / 4).clamp(1, 999).toDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            DateFormat.Hm().format(data[index].timestamp),
                            style: const TextStyle(fontSize: 9),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('Unit: $unit', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
