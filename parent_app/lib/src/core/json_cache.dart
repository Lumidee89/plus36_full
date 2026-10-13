import 'offline_store.dart';

class JsonCache {
  static Future<T> through<T>(String key, Future<T> Function() fetch) async {
    return OfflineStore.cached<T>(key, fetch);
  }

  static Future<void> clear() async {
    await OfflineStore.clear();
  }
}
