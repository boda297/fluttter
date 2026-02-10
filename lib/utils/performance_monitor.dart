import 'package:flutter/foundation.dart';

/// Simple performance monitoring utility for clip logic and API calls.
class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};

  /// Start timing an operation.
  static void start(String operation) {
    final stopwatch = Stopwatch()..start();
    _timers[operation] = stopwatch;
    debugPrint('📊 Started: $operation');
  }

  /// End timing and log result.
  static void end(String operation) {
    final stopwatch = _timers[operation];
    if (stopwatch == null) {
      debugPrint('⚠️ Timer not found: $operation');
      return;
    }
    stopwatch.stop();
    final ms = stopwatch.elapsedMilliseconds;
    final icon = ms < 100
        ? '✅'
        : ms < 500
            ? '⚠️'
            : '❌';
    debugPrint('$icon Completed: $operation in ${ms}ms');
    _timers.remove(operation);
  }

  /// Wrap async operations with timing.
  static Future<T> measure<T>(
    String operation,
    Future<T> Function() fn,
  ) async {
    start(operation);
    try {
      final result = await fn();
      end(operation);
      return result;
    } catch (e) {
      end(operation);
      rethrow;
    }
  }
}
