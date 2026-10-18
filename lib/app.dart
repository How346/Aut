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
    final theme = Theme.of(context);
    return Positioned.fill(
      child: Material(
        color: theme.scaffoldBackgroundColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Authly is locked', style: theme.textTheme.titleLarge),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onUnlock,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
