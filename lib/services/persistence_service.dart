import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background persistence service with debouncing to avoid frequent disk writes.
/// Automatically batches multiple writes together and flushes on a timer.
/// Prevents UI jank caused by synchronous SharedPreferences operations.
abstract class PersistenceService {
  static final PersistenceService _instance = _PersistenceServiceImpl._();

  /// Get or initialize the persistence service singleton.
  static PersistenceService get instance => _instance;

  /// Queue a write operation (key-value pair). Will be debounced and batched.
  void queueWrite(String key, dynamic value);

  /// Force immediate flush of all pending writes to disk.
  Future<void> flushNow();

  /// Clear all pending batched writes without flushing.
  void clearPending();

  /// Dispose resources (timers, etc).
  void dispose();
}

class _PersistenceServiceImpl implements PersistenceService {
  // Batch writes to be applied together
  final Map<String, dynamic> _pendingWrites = {};
  
  // Debounce timer
  Timer? _flushTimer;
  
  // Settings
  static const _debounceMs = 500; // Batch writes for 500ms before flushing
  static const _maxBatchSize = 50; // Flush if batch exceeds 50 items

  bool _disposed = false;
  SharedPreferences? _prefs;

  _PersistenceServiceImpl._();

  /// Initialize with SharedPreferences instance (call once at app startup).
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  @override
  void queueWrite(String key, dynamic value) {
    if (_disposed) {
      debugPrint('[PersistenceService] WARNING: Write queued after dispose: $key');
      return;
    }

    _pendingWrites[key] = value;

    // If batch is getting too large, flush immediately
    if (_pendingWrites.length >= _maxBatchSize) {
      _scheduleFlush(immediate: true);
      return;
    }

    // Otherwise, reschedule the debounce timer
    _scheduleFlush();
  }

  void _scheduleFlush({bool immediate = false}) {
    // Cancel existing timer
    _flushTimer?.cancel();

    if (immediate || _pendingWrites.isEmpty) {
      // Flush now
      _flush();
    } else {
      // Schedule flush after debounce delay
      _flushTimer = Timer(const Duration(milliseconds: _debounceMs), _flush);
    }
  }

  void _flush() {
    if (_disposed || _prefs == null || _pendingWrites.isEmpty) {
      return;
    }

    // Run flush in background isolate-like manner using compute() for heavy workloads,
    // or just run async to not block UI thread.
    _flushAsync();
  }

  Future<void> _flushAsync() async {
    if (_disposed || _prefs == null) return;

    final batch = Map<String, dynamic>.from(_pendingWrites);
    _pendingWrites.clear();

    try {
      // Apply batched writes
      for (final entry in batch.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value == null) {
          await _prefs!.remove(key);
        } else if (value is String) {
          await _prefs!.setString(key, value);
        } else if (value is int) {
          await _prefs!.setInt(key, value);
        } else if (value is double) {
          await _prefs!.setDouble(key, value);
        } else if (value is bool) {
          await _prefs!.setBool(key, value);
        } else if (value is List<String>) {
          await _prefs!.setStringList(key, value);
        } else {
          debugPrint('[PersistenceService] Unsupported type for key $key: ${value.runtimeType}');
        }
      }

      if (kDebugMode) {
        debugPrint('[PersistenceService] Flushed ${batch.length} items to disk');
      }
    } catch (e) {
      debugPrint('[PersistenceService] Error flushing: $e');
      // Re-queue failed writes for next attempt
      _pendingWrites.addAll(batch);
    }
  }

  @override
  Future<void> flushNow() async {
    if (_disposed) return;
    _flushTimer?.cancel();
    await _flushAsync();
  }

  @override
  void clearPending() {
    _flushTimer?.cancel();
    _pendingWrites.clear();
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _disposed = true;
  }

  /// Get number of pending writes (useful for debugging).
  int get pendingCount => _pendingWrites.length;

  /// Check if pending writes exist.
  bool get hasPending => _pendingWrites.isNotEmpty;
}
