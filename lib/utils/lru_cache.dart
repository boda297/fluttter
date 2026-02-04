import 'dart:collection';

/// Generic Least Recently Used (LRU) cache implementation.
/// Automatically evicts oldest entries when max size is reached.
class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  LRUCache(this.maxSize) : assert(maxSize > 0, 'maxSize must be positive');

  /// Get value from cache (moves to end = most recently used).
  V? get(K key) {
    if (!_cache.containsKey(key)) {
      return null;
    }
    // Move to end (most recently used)
    final value = _cache.remove(key)!;
    _cache[key] = value;
    return value;
  }

  /// Put value in cache (evicts oldest if at capacity).
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    _cache[key] = value;
  }

  /// Clear all entries.
  void clear() => _cache.clear();

  /// Check if key exists.
  bool containsKey(K key) => _cache.containsKey(key);

  /// Get current size.
  int get length => _cache.length;

  /// Get all values (e.g. for fallback iteration).
  Iterable<V> get values => _cache.values;

  /// Get cache statistics.
  Map<String, dynamic> get stats => {
        'size': _cache.length,
        'maxSize': maxSize,
        'utilization': '${(_cache.length / maxSize * 100).toStringAsFixed(1)}%',
      };
}
