import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';
import '../../core/json_cache.dart';

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);

class AuthRepository {
  AuthRepository(this._dio, this._storage);
  final Dio _dio;
  final FlutterSecureStorage _storage;
  Future<void> login(String email, String password) async {
    final response = await _dio.post(
      '/parent/login',
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        'device_name': 'SchoolOS Parent App',
      },
    );
    await _storage.write(
      key: 'auth_token',
      value: response.data['data']['token'],
    );
  }

  Future<bool> hasToken() async =>
      (await _storage.read(key: 'auth_token')) != null;
  Future<void> changePassword(String current, String password) async {
    await _dio.put(
      '/parent/password',
      data: {
        'current_password': current,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  Future<void> logout() async {
    try {
      await _dio.post('/parent/logout');
    } finally {
      await _storage.delete(key: 'auth_token');
      await JsonCache.clear();
    }
  }
}
