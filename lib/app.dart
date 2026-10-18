import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/authenticator/data/repositories/secure_account_repository.dart';
import 'features/authenticator/presentation/screens/home_screen.dart';
import 'features/security/app_lock_controller.dart';

class AuthlyApp extends StatefulWidget {
  final SecureAccountRepository repository;
  final ThemeController themeController;
  final AppLockController lockController;

  const AuthlyApp({
    super.key,
    required this.repository,
    required this.themeController,
    required this.lockController,
  });

  @override
  State<AuthlyApp> createState() => _AuthlyAppState();
}

class _AuthlyAppState extends State<AuthlyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.lockController.locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.lockController.unlock();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.lockController.lock();
    } else if (state == AppLifecycleState.resumed &&
        widget.lockController.locked) {
      widget.lockController.unlock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.themeController, widget.lockController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Authly Authenticator',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: widget.themeController.mode,
          builder: (context, child) {
            return Stack(
              children: [
                if (child != null) child,
                if (widget.lockController.locked)
                  _LockOverlay(onUnlock: widget.lockController.unlock),
              ],
            );
          },
          home: HomeScreen(
            repository: widget.repository,
            themeController: widget.themeController,
            lockController: widget.lockController,
          ),
        );
      },
    );
  }
}

class _LockOverlay extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockOverlay({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E3A8A), AppTheme.navyDeep],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Authly is locked',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Authenticate to view your codes',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.brandDeep,
                    ),
                    onPressed: onUnlock,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Unlock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
