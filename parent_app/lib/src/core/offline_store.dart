import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineStore {
  static const _queueKey = 'parent_offline_mutations';
  static final ValueNotifier<bool> isOffline = ValueNotifier(false);
  static final ValueNotifier<DateTime?> lastSync = ValueNotifier(null);

  static Future<T> cached<T>(String key, Future<T> Function() fetch) async {
    final preferences = await SharedPreferences.getInstance();
    try {
      final value = await fetch();
      final now = DateTime.now();
      await preferences.setString(
        key,
        jsonEncode({'data': value, 'cached_at': now.toIso8601String()}),
      );
      isOffline.value = false;
      lastSync.value = now;
      return value;
    } catch (_) {
      final saved = preferences.getString(key);
      if (saved == null) rethrow;
      isOffline.value = true;
      final decoded = jsonDecode(saved);
      if (decoded is Map && decoded.containsKey('data')) {
        final cachedAt = DateTime.tryParse('${decoded['cached_at']}');
        if (cachedAt != null) lastSync.value = cachedAt;
        return decoded['data'] as T;
      }
      return decoded as T;
    }
  }

  static Future<void> enqueue(
    String method,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final queue = _readQueue(preferences);
    queue.add({
      'id': '${DateTime.now().microsecondsSinceEpoch}-$path',
      'method': method,
      'path': path,
      'data': data ?? <String, dynamic>{},
      'created_at': DateTime.now().toIso8601String(),
    });
    await preferences.setString(_queueKey, jsonEncode(queue));
    isOffline.value = true;
  }

  static Future<int> flush(Dio dio) async {
    final preferences = await SharedPreferences.getInstance();
    final queue = _readQueue(preferences);
    var completed = 0;
    while (queue.isNotEmpty) {
      final item = Map<String, dynamic>.from(queue.first as Map);
      try {
        await dio.request(
          item['path'] as String,
          data: item['data'],
          options: Options(method: item['method'] as String),
        );
        queue.removeAt(0);
        completed++;
        await preferences.setString(_queueKey, jsonEncode(queue));
      } catch (_) {
        isOffline.value = true;
        return completed;
      }
    }
    isOffline.value = false;
    lastSync.value = DateTime.now();
    return completed;
  }

  static List<dynamic> _readQueue(SharedPreferences preferences) {
    final raw = preferences.getString(_queueKey);
    return raw == null ? <dynamic>[] : List<dynamic>.from(jsonDecode(raw));
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    for (final key in preferences.getKeys().where(
      (key) => key.startsWith('parent_'),
    )) {
      await preferences.remove(key);
    }
    isOffline.value = false;
    lastSync.value = null;
  }
}
