import 'package:flutter/material.dart';

import 'app.dart';
import 'core/theme/theme_controller.dart';
import 'features/authenticator/data/repositories/secure_account_repository.dart';
import 'features/security/app_lock_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = ThemeController();
  final lockController = AppLockController();
  await Future.wait([themeController.load(), lockController.load()]);
  runApp(
    AuthlyApp(
      repository: SecureAccountRepository(),
      themeController: themeController,
      lockController: lockController,
    ),
  );
}
