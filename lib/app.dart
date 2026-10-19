import 'package:flutter/material.dart';

import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/authenticator/data/repositories/secure_account_repository.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/security/app_lock_controller.dart';
import 'features/security/presentation/lock_overlay.dart';
import 'features/shell/home_shell.dart';
import 'features/splash/splash_screen.dart';

class AuthlyApp extends StatefulWidget {
  const AuthlyApp({
    super.key,
    required this.repository,
    required this.themeController,
    required this.lockController,
    required this.settings,
  });

  final SecureAccountRepository repository;
  final ThemeController themeController;
  final AppLockController lockController;
  final AppSettings settings;

  @override
  State<AuthlyApp> createState() => _AuthlyAppState();
}

class _AuthlyAppState extends State<AuthlyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.lockController.onBackground();
    } else if (state == AppLifecycleState.resumed) {
      widget.lockController.onForeground();
    }
  }

  Widget _shell() {
    return HomeShell(
      repository: widget.repository,
      themeController: widget.themeController,
      lockController: widget.lockController,
      settings: widget.settings,
    );
  }

  Future<void> _finishOnboarding(BuildContext context) async {
    await widget.settings.setOnboardingDone();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => _shell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.themeController, widget.lockController]),
      builder: (context, _) {
        final accent = widget.themeController.accent;
        return MaterialApp(
          title: 'Authly',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(accent),
          darkTheme: AppTheme.dark(accent),
          themeMode: widget.themeController.mode,
          builder: (context, child) {
            return Stack(
              children: [
                if (child != null) child,
                if (widget.lockController.locked)
                  LockOverlay(controller: widget.lockController),
              ],
            );
          },
          home: SplashScreen(
            nextBuilder: (_) => widget.settings.onboardingDone
                ? _shell()
                : OnboardingScreen(onFinish: _finishOnboarding),
          ),
        );
      },
    );
  }
}
