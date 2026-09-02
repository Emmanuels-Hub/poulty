import 'dart:async';

import '../../data/models/telemetry_model.dart';
import '../constants/app_constants.dart';
import 'local_storage_service.dart';

/// One logged series. Keeping the key, label and unit together means the
/// charts, the CSV header and the stats cards all stay in step.
class HistoryParameter {
  const HistoryParameter({
    required this.key,
    required this.label,
    required this.unit,
    required this.csvColumn,
    this.axisMin,
    this.axisMax,
  });

  final String key;
  final String label;
  final String unit;
  final String csvColumn;
  final double? axisMin;
  final double? axisMax;
}

const List<HistoryParameter> historyParameters = [
  HistoryParameter(
    key: 'temperature',
    label: 'Temperature',
    unit: '°C',
    csvColumn: 'temperature_c',
  ),
  HistoryParameter(
    key: 'humidity',
    label: 'Humidity',
    unit: '%',
    csvColumn: 'humidity_pct',
    axisMin: 0,
    axisMax: 100,
  ),
  HistoryParameter(
    key: 'airPurity',
    label: 'Air Purity',
    unit: '%',
    csvColumn: 'air_purity_pct',
    axisMin: 0,
    axisMax: 100,
  ),
  HistoryParameter(
    key: 'feed',
    label: 'Feed Level',
    unit: '%',
    csvColumn: 'feed_level_pct',
    axisMin: 0,
    axisMax: 100,
  ),
  HistoryParameter(
    key: 'water',
    label: 'Water Level',
    unit: '%',
    csvColumn: 'water_level_pct',
    axisMin: 0,
    axisMax: 100,
  ),
];

/// Summary of one series over the loaded window.
class HistoryStats {
  const HistoryStats({
    required this.min,
    required this.max,
    required this.average,
    required this.count,
    this.first,
    this.last,
  });

  final double min;
  final double max;
  final double average;
  final int count;
  final DateTime? first;
  final DateTime? last;

  static const empty = HistoryStats(min: 0, max: 0, average: 0, count: 0);
}

/// Logs sensor readings to disk.
///
/// Telemetry arrives roughly every 3 s, which is far denser than anything
/// worth keeping and would rewrite the whole stored series 5× a second. So
/// readings are averaged in memory and committed once per
/// [AppConstants.historyLogInterval], then flushed to Hive in batches.
class HistoryService {
  HistoryService(this._storage);

  final LocalStorageService _storage;

  final Map<String, List<double>> _pending = {};
  bool _pendingSimulated = false;
  final Map<String, List<TelemetryHistoryPoint>> _series = {};

  DateTime? _lastCommitAt;
  bool _dirty = false;
  Timer? _flushTimer;

  /// Loads persisted history into memory. Call once at startup.
  void load() {
    for (final parameter in historyParameters) {
      _series[parameter.key] = _storage.getHistory(parameter.key);
    }
  }

  List<TelemetryHistoryPoint> series(String key) =>
      List<TelemetryHistoryPoint>.unmodifiable(_series[key] ?? const []);

  bool get isEmpty => _series.values.every((s) => s.isEmpty);

  int get pointCount =>
      _series.values.fold(0, (total, series) => total + series.length);

  DateTime? get oldestPoint {
    DateTime? oldest;
    for (final series in _series.values) {
      if (series.isEmpty) continue;
      final first = series.first.timestamp;
      if (oldest == null || first.isBefore(oldest)) oldest = first;
    }
    return oldest;
  }

  /// Accumulates [snapshot], committing an averaged point when the log
  /// interval has elapsed. Returns true when a new point was written, so the
  /// caller knows to refresh its charts.
  bool record(TelemetrySnapshot snapshot) {
    // If any reading in the window was injected, the committed point is
    // marked simulated so an exported dataset stays honest.
    if (snapshot.simulationMode) _pendingSimulated = true;

    _accumulate('temperature', snapshot.temperatureC);
    _accumulate('humidity', snapshot.humidityPercent);
    _accumulate('airPurity', snapshot.airPurityPercent);
    _accumulate('feed', snapshot.feedLevelPercent);
    _accumulate('water', snapshot.waterLevelPercent);

    final now = DateTime.now();
    final last = _lastCommitAt;

    // Commit the first reading immediately so charts are not blank for a
    // whole interval after launch.
    if (last != null && now.difference(last) < AppConstants.historyLogInterval) {
      return false;
    }

    _commit(now);
    return true;
  }

  void _accumulate(String key, double value) {
    if (value.isNaN || value.isInfinite) return;
    (_pending[key] ??= <double>[]).add(value);
  }

  void _commit(DateTime at) {
    _lastCommitAt = at;

    for (final parameter in historyParameters) {
      final samples = _pending[parameter.key];
      if (samples == null || samples.isEmpty) continue;

      final mean = samples.reduce((a, b) => a + b) / samples.length;
      samples.clear();

      final series = _series[parameter.key] ??= <TelemetryHistoryPoint>[];
      series.add(
        TelemetryHistoryPoint(
          timestamp: at,
          // Stored to one decimal: sensor precision does not justify more.
          value: double.parse(mean.toStringAsFixed(1)),
          parameter: parameter.key,
          simulated: _pendingSimulated,
        ),
      );

      while (series.length > AppConstants.maxHistoryPoints) {
        series.removeAt(0);
      }
    }

    _pendingSimulated = false;
    _dirty = true;
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(AppConstants.historyFlushInterval, () {
      _flushTimer = null;
      flush();
    });
  }

  /// Persists any pending changes. Safe to call at any time.
  Future<void> flush() async {
    if (!_dirty) return;
    _dirty = false;

    for (final parameter in historyParameters) {
      final series = _series[parameter.key];
      if (series == null) continue;
      await _storage.saveHistory(parameter.key, series);
    }
  }

  HistoryStats stats(String key) {
    final series = _series[key];
    if (series == null || series.isEmpty) return HistoryStats.empty;

    var min = series.first.value;
    var max = series.first.value;
    var total = 0.0;

    for (final point in series) {
      if (point.value < min) min = point.value;
      if (point.value > max) max = point.value;
      total += point.value;
    }

    return HistoryStats(
      min: min,
      max: max,
      average: total / series.length,
      count: series.length,
      first: series.first.timestamp,
      last: series.last.timestamp,
    );
  }

  /// Renders every series as a single CSV table.
  ///
  /// All parameters are committed at the same instant, so their timestamps
  /// line up and each row is one complete reading.
  String toCsv() {
    final timestamps = <DateTime>{};
    for (final parameter in historyParameters) {
      for (final point in _series[parameter.key] ?? const []) {
        timestamps.add(point.timestamp);
      }
    }

    final ordered = timestamps.toList()..sort();

    final lookup = <String, Map<DateTime, double>>{
      for (final parameter in historyParameters)
        parameter.key: {
          for (final point in _series[parameter.key] ?? const [])
            point.timestamp: point.value,
        },
    };

    final simulatedAt = <DateTime>{
      for (final parameter in historyParameters)
        for (final point in _series[parameter.key] ?? const [])
          if (point.simulated) point.timestamp,
    };

    final buffer = StringBuffer()
      ..writeln(
        [
          'timestamp',
          ...historyParameters.map((p) => p.csvColumn),
          'simulated',
        ].join(','),
      );

    for (final timestamp in ordered) {
      final row = <String>[timestamp.toIso8601String()];
      for (final parameter in historyParameters) {
        final value = lookup[parameter.key]?[timestamp];
        row.add(value?.toStringAsFixed(1) ?? '');
      }
      row.add(simulatedAt.contains(timestamp) ? 'true' : 'false');
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  Future<void> clear() async {
    for (final parameter in historyParameters) {
      _series[parameter.key] = <TelemetryHistoryPoint>[];
      _pending.remove(parameter.key);
      await _storage.saveHistory(parameter.key, const []);
    }
    _lastCommitAt = null;
    _pendingSimulated = false;
    _dirty = false;
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}
