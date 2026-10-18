import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../authenticator/data/repositories/secure_account_repository.dart';
import '../../../backup/domain/services/backup_service.dart';
import '../../../security/app_lock_controller.dart';

class SettingsScreen extends StatefulWidget {
  final SecureAccountRepository repository;
  final ThemeController themeController;
  final AppLockController lockController;
  final Future<void> Function() onDataRestored;

  const SettingsScreen({
    super.key,
    required this.repository,
    required this.themeController,
    required this.lockController,
    required this.onDataRestored,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<String?> _askPassword({
    required String title,
    required String message,
    required String action,
    bool confirm = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _PasswordDialog(
        title: title,
        message: message,
        action: action,
        confirm: confirm,
      ),
    );
  }

  Future<void> _export({required bool share}) async {
    final accounts = await widget.repository.getAccounts();
    if (accounts.isEmpty) {
      _toast('No accounts to export.');
      return;
    }
    if (!mounted) return;
    final password = await _askPassword(
      title: 'Export Encrypted Backup',
      message:
          'Choose a password (min ${BackupService.minPasswordLength} characters). '
          'You will need it to restore. It cannot be recovered.',
      action: 'Export',
      confirm: true,
    );
    if (password == null) return;

    setState(() => _busy = true);
    try {
      final backup = await BackupService.createEncryptedBackup(
        accounts: accounts,
        password: password,
      );
      final bytes = Uint8List.fromList(utf8.encode(backup));
      const fileName = 'authly-backup.authly';
      if (share) {
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'application/octet-stream')],
          fileNameOverrides: [fileName],
          subject: 'Authly Encrypted Backup',
        );
      } else {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Authly backup',
          fileName: fileName,
          bytes: bytes,
        );
        if (path != null) _toast('Backup saved.');
      }
    } catch (e) {
      _toast('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      final bytes = result?.files.single.bytes;
      if (bytes == null) return;
      await _restore(utf8.decode(bytes));
    } on FormatException {
      _toast('That file is not a valid Authly backup.');
    } catch (e) {
      _toast('Import failed: $e');
    }
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _toast('Clipboard is empty.');
      return;
    }
    await _restore(text);
  }

  Future<void> _restore(String backupJson) async {
    if (!mounted) return;
    final password = await _askPassword(
      title: 'Import Backup',
      message: 'Enter the password used to encrypt this backup.',
      action: 'Restore',
    );
    if (password == null) return;

    setState(() => _busy = true);
    try {
      final accounts = await BackupService.restoreBackup(
        backupJson: backupJson,
        password: password,
      );
      final added = await widget.repository.mergeAccounts(accounts);
      await widget.onDataRestored();
      final skipped = accounts.length - added;
      _toast(
        'Imported $added account${added == 1 ? '' : 's'}'
        '${skipped > 0 ? ' ($skipped duplicate${skipped == 1 ? '' : 's'} skipped)' : ''}.',
      );
    } on BackupException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Failed to restore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLock(bool value) async {
    final ok = await widget.lockController.setEnabled(value);
    if (!ok) {
      _toast(value
          ? 'Biometric / device credential unavailable or not confirmed.'
          : 'Could not change app lock.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: Listenable.merge(
          [widget.themeController, widget.lockController],
        ),
        builder: (context, _) {
          return Stack(
            children: [
              ListView(
                children: [
                  const ListTile(
                    leading: Icon(Icons.shield_outlined),
                    title: Text('Security & Vault'),
                    subtitle: Text('Secrets stored via Android Keystore'),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Biometric app lock'),
                    subtitle: const Text('Require unlock on launch and resume'),
                    value: widget.lockController.enabled,
                    onChanged: _busy ? null : _toggleLock,
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theme',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text('System'),
                              icon: Icon(Icons.brightness_auto),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode),
                            ),
                          ],
                          selected: {widget.themeController.mode},
                          onSelectionChanged: (s) =>
                              widget.themeController.setMode(s.first),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.save_alt),
                    title: const Text('Export backup to file'),
                    subtitle: const Text('Save a password-encrypted .authly file'),
                    enabled: !_busy,
                    onTap: () => _export(share: false),
                  ),
                  ListTile(
                    leading: const Icon(Icons.ios_share),
                    title: const Text('Share encrypted backup'),
                    subtitle: const Text('Send the .authly file via the share sheet'),
                    enabled: !_busy,
                    onTap: () => _export(share: true),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Import backup from file'),
                    enabled: !_busy,
                    onTap: _importFromFile,
                  ),
                  ListTile(
                    leading: const Icon(Icons.content_paste),
                    title: const Text('Import backup from clipboard'),
                    enabled: !_busy,
                    onTap: _importFromClipboard,
                  ),
                  const Divider(),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('About Authly'),
                    subtitle: Text('Version 1.0.0 • Offline-first • Zero-tracking'),
                  ),
                ],
              ),
              if (_busy)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  final String title;
  final String message;
  final String action;
  final bool confirm;

  const _PasswordDialog({
    required this.title,
    required this.message,
    required this.action,
    required this.confirm,
  });

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final pw = _password.text;
    if (widget.confirm) {
      if (pw.length < BackupService.minPasswordLength) {
        setState(() => _error =
            'Use at least ${BackupService.minPasswordLength} characters.');
        return;
      }
      if (pw != _confirm.text) {
        setState(() => _error = 'Passwords do not match.');
        return;
      }
    } else if (pw.isEmpty) {
      setState(() => _error = 'Password is required.');
      return;
    }
    Navigator.pop(context, pw);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.message),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Backup password',
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.action)),
      ],
    );
  }
}
