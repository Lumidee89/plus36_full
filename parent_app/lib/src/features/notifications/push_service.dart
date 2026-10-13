import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'notifications_screen.dart';

final firebaseAvailableProvider = Provider<bool>((_) => false);
final pushServiceProvider = Provider((ref) => PushService(ref));

class PushService {
  PushService(this.ref);
  final Ref ref;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  String? _registeredToken;

  Future<void> start() async {
    if (!ref.read(firebaseAvailableProvider)) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      _tokenSubscription ??= messaging.onTokenRefresh.listen(_register);
      _messageSubscription ??= FirebaseMessaging.onMessage.listen((_) {
        ref.invalidate(notificationsProvider);
      });
    } catch (_) {
      // In-app notifications remain available when push delivery is unavailable.
    }
  }

  Future<void> stop() async {
    if (_registeredToken != null) {
      try {
        await ref
            .read(apiClientProvider)
            .delete('/parent/devices', data: {'token': _registeredToken});
      } catch (_) {}
    }
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    _tokenSubscription = null;
    _messageSubscription = null;
    _registeredToken = null;
  }

  Future<void> _register(String token) async {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      _ => 'android',
    };
    await ref
        .read(apiClientProvider)
        .post('/parent/devices', data: {'token': token, 'platform': platform});
    _registeredToken = token;
  }
}
