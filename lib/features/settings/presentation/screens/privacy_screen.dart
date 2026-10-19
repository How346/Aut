import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../authenticator/data/repositories/secure_account_repository.dart';
import '../../../security/app_lock_controller.dart';
import '../../../security/lock_actions.dart';
import '../widgets/settings_widgets.dart';
import 'export_import_screen.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({
    super.key,
    required this.lockController,
    required this.settings,
    required this.repository,
    required this.onDataChanged,
  });

  final AppLockController lockController;
  final AppSettings settings;
  final SecureAccountRepository repository;
  final Future<void> Function() onDataChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Security')),
      body: ListenableBuilder(
        listenable: Listenable.merge([lockController, settings]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.lock_outline,
                    title: 'App Lock',
                    subtitle: 'Use PIN or biometric to protect the app',
                    trailing: Switch(
                      value: lockController.enabled,
                      onChanged: (v) =>
                          LockActions.toggleAppLock(context, lockController, v),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.visibility_off_outlined,
                    title: 'Hide PIN',
                    subtitle: 'Hide the PIN while entering',
                    trailing: Switch(
                      value: lockController.hidePin,
                      onChanged: lockController.setHidePin,
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.content_paste_off_outlined,
                    title: 'Clipboard Protection',
                    subtitle: 'Clear clipboard after 30 seconds',
                    trailing: Switch(
                      value: settings.clipboardClear,
                      onChanged: settings.setClipboardClear,
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.timer_outlined,
                    title: 'Auto Lock',
                    subtitle: LockActions.autoLockLabel(
                      lockController.autoLockMinutes,
                    ),
                    trailing: SettingsRow.chevron(context),
                    onTap: () =>
                        LockActions.pickAutoLock(context, lockController),
                  ),
                  SettingsRow(
                    icon: Icons.save_outlined,
                    title: 'Data Backup',
                    subtitle: 'Export / Import accounts',
                    trailing: SettingsRow.chevron(context),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ExportImportScreen(
                          repository: repository,
                          onDataChanged: onDataChanged,
                        ),
                      ),
                    ),
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
