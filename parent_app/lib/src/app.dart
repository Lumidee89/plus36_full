import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'core/api_client.dart';
import 'core/offline_store.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/notifications/push_service.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/parent_shell.dart';

const _onboardingCompleteKey = 'parent_onboarding_complete';

class SchoolOsApp extends ConsumerStatefulWidget {
  const SchoolOsApp({super.key});
  @override
  ConsumerState<SchoolOsApp> createState() => _AppState();
}

class _AppState extends ConsumerState<SchoolOsApp> {
  bool? authenticated;
  bool? onboardingComplete;
  Timer? _syncTimer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _syncOfflineChanges);
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _syncOfflineChanges(),
    );
    _bootstrap();
  }

  Future<void> _syncOfflineChanges() async {
    if (authenticated == true) {
      await OfflineStore.flush(ref.read(apiClientProvider));
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait<Object>([
      ref.read(authRepositoryProvider).hasToken(),
      SharedPreferences.getInstance(),
    ]);
    final hasToken = results[0] as bool;
    final preferences = results[1] as SharedPreferences;
    if (!mounted) return;
    setState(() {
      authenticated = hasToken;
      onboardingComplete =
          hasToken || (preferences.getBool(_onboardingCompleteKey) ?? false);
    });
    if (hasToken) ref.read(pushServiceProvider).start();
  }

  Future<void> _completeOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingCompleteKey, true);
    if (mounted) setState(() => onboardingComplete = true);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Plus36 SchoolOS',
    theme: schoolTheme(),
    builder: (context, child) => ValueListenableBuilder<bool>(
      valueListenable: OfflineStore.isOffline,
      child: child,
      builder: (context, offline, app) => Column(
        children: [
          if (offline)
            Material(
              color: const Color(0xFFFFF2CC),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.cloud_off_rounded, size: 16),
                      SizedBox(width: 7),
                      Text(
                        'Offline — showing saved school data',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(child: app ?? const SizedBox.shrink()),
        ],
      ),
    ),
    home: authenticated == null || onboardingComplete == null
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : authenticated!
        ? ParentShell(
            onLogout: () async {
              await ref.read(pushServiceProvider).stop();
              await ref.read(authRepositoryProvider).logout();
              setState(() => authenticated = false);
            },
          )
        : !onboardingComplete!
        ? OnboardingScreen(onComplete: _completeOnboarding)
        : LoginScreen(
            onAuthenticated: () {
              setState(() => authenticated = true);
              ref.read(pushServiceProvider).start();
            },
          ),
  );
}
