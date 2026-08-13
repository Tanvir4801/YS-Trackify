import 'telemetry_service.dart';

class PerformanceService {
  PerformanceService._();
  static final PerformanceService instance = PerformanceService._();

  /// Wraps any Future and measures its execution time.
  Future<T> measure<T>(String metricName, Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await action();
    } finally {
      stopwatch.stop();
      _logMetric(metricName, stopwatch.elapsedMilliseconds);
    }
  }

  /// Directly logs a measured duration (useful for app startup or screen loads)
  void logDuration(String metricName, int durationMs, {String? screenName}) {
    _logMetric(metricName, durationMs, screenName: screenName);
  }

  void _logMetric(String featureName, int durationMs, {String? screenName}) {
    // We send this to TelemetryService as a special eventType
    TelemetryService.instance.logEvent(
      eventType: 'performance_metric',
      featureName: featureName,
      screenName: screenName,
      additionalMetadata: {
        'durationMs': durationMs,
      },
    );
  }
}
