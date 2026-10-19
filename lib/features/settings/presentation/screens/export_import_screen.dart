import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/confirm_dialogs.dart';
import '../../../authenticator/data/repositories/secure_account_repository.dart';
import '../../../backup/domain/services/backup_service.dart';
import '../widgets/settings_widgets.dart';

class ExportImportScreen extends StatefulWidget {
  const ExportImportScreen({
    super.key,
    required this.repository,
    required this.onDataChanged,
  });

  final SecureAccountRepository repository;
  final Future<void> Function() onDataChanged;

  @override
  State<ExportImportScreen> createState() => _ExportImportScreenState();
}

class _ExportImportScreenState extends State<ExportImportScreen> {
  bool _busy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
      final files = result?.files;
      final bytes = (files == null || files.isEmpty) ? null : files.first.bytes;
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
      await widget.onDataChanged();
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

  Future<void> _clearAll() async {
    final ok = await confirmAction(
      context,
      title: 'Clear all accounts?',
      message: 'This permanently removes every account from this device. '
          'Make sure you have a backup.',
      confirmLabel: 'Clear all',
    );
    if (!ok) return;
    await widget.repository.saveAccounts([]);
    await widget.onDataChanged();
    _toast('All accounts removed.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Export / Import')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.upload_file_outlined,
                    title: 'Export Accounts',
                    subtitle: 'Save your accounts to an encrypted file',
                    enabled: !_busy,
                    trailing: SettingsRow.chevron(context),
                    onTap: () => _export(share: false),
                  ),
                  SettingsRow(
                    icon: Icons.ios_share,
                    title: 'Share Backup',
                    subtitle: 'Send the .authly file via the share sheet',
                    enabled: !_busy,
                    trailing: SettingsRow.chevron(context),
                    onTap: () => _export(share: true),
                  ),
                  SettingsRow(
                    icon: Icons.file_download_outlined,
                    title: 'Import Accounts',
                    subtitle: 'Restore from a file',
                    enabled: !_busy,
                    trailing: SettingsRow.chevron(context),
                    onTap: _importFromFile,
                  ),
                  SettingsRow(
                    icon: Icons.content_paste,
                    title: 'Import from Clipboard',
                    subtitle: 'Paste a copied backup',
                    enabled: !_busy,
                    trailing: SettingsRow.chevron(context),
                    onTap: _importFromClipboard,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error.withValues(alpha: 0.12),
                    foregroundColor: scheme.error,
                    elevation: 0,
                  ),
                  onPressed: _busy ? null : _clearAll,
                  child: const Text('Clear All Accounts'),
                ),
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
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({
    required this.title,
    required this.message,
    required this.action,
    required this.confirm,
  });

  final String title;
  final String message;
  final String action;
  final bool confirm;

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
              decoration: AppTheme.inputDecoration(
                context,
                label: 'Backup password',
                icon: Icons.lock_outline,
              ),
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: true,
                decoration: AppTheme.inputDecoration(
                  context,
                  label: 'Confirm password',
                  icon: Icons.lock_outline,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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
