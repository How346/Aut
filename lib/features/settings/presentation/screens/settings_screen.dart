import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../authenticator/data/repositories/secure_account_repository.dart';
import '../../../security/app_lock_controller.dart';
import '../../../security/lock_actions.dart';
import '../widgets/settings_widgets.dart';
import 'about_screen.dart';
import 'export_import_screen.dart';
import 'privacy_screen.dart';
import 'theme_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.repository,
    required this.themeController,
    required this.lockController,
    required this.settings,
    required this.onDataChanged,
  });

  final SecureAccountRepository repository;
  final ThemeController themeController;
  final AppLockController lockController;
  final AppSettings settings;
  final Future<void> Function() onDataChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricsSupported = true;

  @override
  void initState() {
    super.initState();
    widget.lockController.biometricsSupported().then((value) {
      if (mounted) setState(() => _biometricsSupported = value);
    });
  }

  String get _themeLabel {
    switch (widget.themeController.mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final lock = widget.lockController;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Settings'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge(
          [widget.themeController, lock, widget.settings],
        ),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SettingsGroup(
                title: 'Security',
                children: [
                  SettingsRow(
                    icon: Icons.lock_outline,
                    title: 'App Lock',
                    trailing: Switch(
                      value: lock.enabled,
                      onChanged: (v) =>
                          LockActions.toggleAppLock(context, lock, v),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.password_outlined,
                    title: 'Change PIN',
                    trailing: SettingsRow.chevron(context),
                    onTap: () => LockActions.changePin(context, lock),
                  ),
                  SettingsRow(
                    icon: Icons.visibility_off_outlined,
                    title: 'Mask 2FA Codes',
                    subtitle: 'Show ••• ••• until you tap the eye',
                    trailing: Switch(
                      value: widget.settings.maskCodes,
                      onChanged: widget.settings.setMaskCodes,
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.fingerprint,
                    title: 'Biometric Authentication',
                    enabled: lock.enabled && _biometricsSupported,
                    trailing: Switch(
                      value: lock.biometricEnabled,
                      onChanged: (lock.enabled && _biometricsSupported)
                          ? (v) => LockActions.toggleBiometric(context, lock, v)
                          : null,
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: 'Appearance',
                children: [
                  SettingsRow(
                    icon: Icons.brightness_6_outlined,
                    title: 'Theme',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _themeLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SettingsRow.chevron(context),
                      ],
                    ),
                    onTap: () => _push(
                      ThemeScreen(controller: widget.themeController),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.palette_outlined,
                    title: 'Accent Color',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 9,
                          backgroundColor:
                              AppTheme.accents[widget.themeController.accentIndex],
                        ),
                        SettingsRow.chevron(context),
                      ],
                    ),
                    onTap: () => _push(
                      ThemeScreen(controller: widget.themeController),
                    ),
                  ),
                ],
              ),
              SettingsGroup(
                title: 'General',
                children: [
                  SettingsRow(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy & Security',
                    trailing: SettingsRow.chevron(context),
                    onTap: () => _push(
                      PrivacyScreen(
                        lockController: lock,
                        settings: widget.settings,
                        repository: widget.repository,
                        onDataChanged: widget.onDataChanged,
                      ),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.import_export,
                    title: 'Export / Import',
                    trailing: SettingsRow.chevron(context),
                    onTap: () => _push(
                      ExportImportScreen(
                        repository: widget.repository,
                        onDataChanged: widget.onDataChanged,
                      ),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.content_copy_outlined,
                    title: 'Copy to Clipboard (30s)',
                    subtitle: 'Clear the clipboard after copying a code',
                    trailing: Switch(
                      value: widget.settings.clipboardClear,
                      onChanged: widget.settings.setClipboardClear,
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.info_outline,
                    title: 'About',
                    trailing: SettingsRow.chevron(context),
                    onTap: () => _push(const AboutScreen()),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
