import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/confirm_dialogs.dart';
import '../../../../core/widgets/labeled_field.dart';
import '../../../../core/widgets/service_icon.dart';
import '../../data/repositories/secure_account_repository.dart';
import '../../domain/models/totp_account.dart';

class EditAccountScreen extends StatefulWidget {
  const EditAccountScreen({
    super.key,
    required this.account,
    required this.repository,
  });

  final TotpAccount account;
  final SecureAccountRepository repository;

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  late final TextEditingController _issuer =
      TextEditingController(text: widget.account.issuer);
  late final TextEditingController _name =
      TextEditingController(text: widget.account.accountName);

  @override
  void dispose() {
    _issuer.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final issuer = _issuer.text.trim();
    if (issuer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service name is required.')),
      );
      return;
    }
    await widget.repository.updateAccount(
      widget.account.copyWith(issuer: issuer, accountName: _name.text.trim()),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _remove() async {
    final ok = await confirmAction(
      context,
      title: 'Remove account?',
      message: 'Remove ${widget.account.issuer}? Make sure you can still '
          'sign in without it.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    await widget.repository.deleteAccount(widget.account.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final account = widget.account;
    final algorithm = switch (account.algorithm) {
      TotpAlgorithm.sha1 => 'SHA-1',
      TotpAlgorithm.sha256 => 'SHA-256',
      TotpAlgorithm.sha512 => 'SHA-512',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          LabeledField(
            label: 'Service Name',
            child: TextField(
              controller: _issuer,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: AppTheme.inputDecoration(context),
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Email',
            child: TextField(
              controller: _name,
              keyboardType: TextInputType.emailAddress,
              decoration: AppTheme.inputDecoration(context),
            ),
          ),
          const SizedBox(height: 16),
          LabeledField(
            label: 'Icon',
            child: Align(
              alignment: Alignment.centerLeft,
              child: ServiceIcon(issuer: _issuer.text, size: 48),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                title: const Text(
                  'Advanced Options',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                children: [
                  ListTile(
                    dense: true,
                    title: const Text('Algorithm'),
                    trailing: Text(algorithm),
                  ),
                  ListTile(
                    dense: true,
                    title: const Text('Digits'),
                    trailing: Text('${account.digits}'),
                  ),
                  ListTile(
                    dense: true,
                    title: const Text('Refresh interval'),
                    trailing: Text('${account.period} seconds'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error.withValues(alpha: 0.12),
              foregroundColor: scheme.error,
              elevation: 0,
            ),
            onPressed: _remove,
            child: const Text('Remove Account'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _save, child: const Text('Save Changes')),
        ],
      ),
    );
  }
}
