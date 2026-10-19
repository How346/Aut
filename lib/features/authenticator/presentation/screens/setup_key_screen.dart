import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/labeled_field.dart';
import '../../data/repositories/secure_account_repository.dart';
import '../../domain/models/totp_account.dart';
import '../../domain/services/totp_service.dart';

class SetupKeyScreen extends StatefulWidget {
  const SetupKeyScreen({
    super.key,
    required this.repository,
    this.initialIssuer,
  });

  final SecureAccountRepository repository;
  final String? initialIssuer;

  @override
  State<SetupKeyScreen> createState() => _SetupKeyScreenState();
}

class _SetupKeyScreenState extends State<SetupKeyScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _issuer =
      TextEditingController(text: widget.initialIssuer ?? '');
  final _name = TextEditingController();
  final _secret = TextEditingController();
  int _digits = 6;
  int _period = 30;
  TotpAlgorithm _algorithm = TotpAlgorithm.sha1;
  bool _saving = false;

  @override
  void dispose() {
    _issuer.dispose();
    _name.dispose();
    _secret.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    final parsed = TotpService.parseUri(text);
    if (parsed == null) {
      _snack('Clipboard does not contain a valid otpauth:// link.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _issuer.text = parsed.issuer;
      _name.text = parsed.accountName;
      _secret.text = parsed.secret;
      _digits = parsed.digits;
      _period = parsed.period;
      _algorithm = parsed.algorithm;
    });
    _snack('Details filled in from the link.');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final account = TotpAccount(
      id: const Uuid().v4(),
      accountName: _name.text.trim(),
      issuer: _issuer.text.trim(),
      secret: TotpService.normalizeSecret(_secret.text),
      digits: _digits,
      period: _period,
      algorithm: _algorithm,
      createdAt: DateTime.now(),
    );
    try {
      TotpService.generateCode(account);
      await widget.repository.addAccount(account);
      if (mounted) Navigator.pop(context, true);
    } on FormatException {
      if (mounted) setState(() => _saving = false);
      _snack('Invalid setup key.');
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      _snack('Could not save the account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Enter Setup Key')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the setup key provided by your service. '
                'It usually looks like this:\nJBSWY3DPEHPK3PXP.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              LabeledField(
                label: 'Setup Key',
                child: TextFormField(
                  controller: _secret,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: AppTheme.inputDecoration(
                    context,
                    hint: 'JBSW Y3DP EHPK 3PXP',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Setup key is required';
                    }
                    try {
                      TotpService.generateCodeForStep(
                        secret: val,
                        timeStep: 0,
                        digits: _digits,
                        algorithm: _algorithm,
                      );
                    } on FormatException {
                      return 'Use a valid key (letters A-Z and digits 2-7)';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Service Name',
                child: TextFormField(
                  controller: _issuer,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: AppTheme.inputDecoration(context, hint: 'Google'),
                  validator: (val) => (val == null || val.trim().isEmpty)
                      ? 'Service name is required'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Account Name (Optional)',
                child: TextFormField(
                  controller: _name,
                  keyboardType: TextInputType.emailAddress,
                  decoration: AppTheme.inputDecoration(
                    context,
                    hint: 'you@example.com',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: const Text(
                    'Advanced Options',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 6, label: Text('6 digits')),
                        ButtonSegment(value: 8, label: Text('8 digits')),
                      ],
                      selected: {_digits},
                      onSelectionChanged: (v) =>
                          setState(() => _digits = v.first),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 30, label: Text('30 s')),
                        ButtonSegment(value: 60, label: Text('60 s')),
                      ],
                      selected: {_period},
                      onSelectionChanged: (v) =>
                          setState(() => _period = v.first),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<TotpAlgorithm>(
                      segments: const [
                        ButtonSegment(
                          value: TotpAlgorithm.sha1,
                          label: Text('SHA-1'),
                        ),
                        ButtonSegment(
                          value: TotpAlgorithm.sha256,
                          label: Text('SHA-256'),
                        ),
                        ButtonSegment(
                          value: TotpAlgorithm.sha512,
                          label: Text('SHA-512'),
                        ),
                      ],
                      selected: {_algorithm},
                      onSelectionChanged: (v) =>
                          setState(() => _algorithm = v.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Add Account'),
              ),
              TextButton.icon(
                onPressed: _pasteLink,
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Paste otpauth:// link'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
