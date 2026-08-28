import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../data/models/telemetry_model.dart';

/// A single point of the approximated series.
class _Bucket {
  const _Bucket(this.timestamp, this.value);

  final DateTime timestamp;
  final double value;
}

/// Plots a sensor's history as an approximated trend line.
///
/// Raw samples arrive every few seconds, which is far denser than a phone
/// chart can show usefully. Points are grouped into equal-sized buckets and
/// averaged, so the line reads as a smooth trend instead of sensor noise.
class HistoryChart extends StatelessWidget {
  const HistoryChart({
    super.key,
    required this.title,
    required this.unit,
    required this.data,
    required this.color,
    this.minY,
    this.maxY,
    this.decimals = 1,
  });

  final String title;
  final String unit;
  final List<TelemetryHistoryPoint> data;
  final Color color;
  final double? minY;
  final double? maxY;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.secondaryText(context);

    if (data.isEmpty) {
      return Card(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text(
              'No $title history yet',
              style: TextStyle(color: muted),
            ),
          ),
        ),
      );
    }

    final buckets = _approximate(data);
    final spots = buckets
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final values = buckets.map((b) => b.value).toList();
    final dataMin = values.reduce((a, b) => a < b ? a : b);
    final dataMax = values.reduce((a, b) => a > b ? a : b);
    final average = values.reduce((a, b) => a + b) / values.length;

    final chartMinY = minY ?? (dataMin - 2);
    final chartMaxY = maxY ?? (dataMax + 2);
    final safeMaxY = chartMaxY <= chartMinY ? chartMinY + 1 : chartMaxY;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '~${average.toStringAsFixed(decimals)} $unit avg',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
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
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: AppTheme.hairline(context), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(0),
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: (buckets.length / 4).clamp(1, 999).toDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= buckets.length) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            DateFormat.Hm().format(buckets[index].timestamp),
                            style: TextStyle(fontSize: 9, color: muted),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              '~${spot.y.toStringAsFixed(decimals)} $unit',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      preventCurveOverShooting: true,
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
            Text(
              'Approximated from ${data.length} readings · unit: $unit',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  /// Averages [points] into at most [AppConstants.chartApproximationBuckets]
  /// evenly sized buckets.
  List<_Bucket> _approximate(List<TelemetryHistoryPoint> points) {
    const target = AppConstants.chartApproximationBuckets;
    if (points.length <= target) {
      return points.map((p) => _Bucket(p.timestamp, p.value)).toList();
    }

    final size = (points.length / target).ceil();
    final buckets = <_Bucket>[];

    for (var start = 0; start < points.length; start += size) {
      final end = (start + size).clamp(0, points.length);
      final slice = points.sublist(start, end);
      final mean =
          slice.map((p) => p.value).reduce((a, b) => a + b) / slice.length;
      buckets.add(_Bucket(slice[slice.length ~/ 2].timestamp, mean));
    }

    return buckets;
  }
}
