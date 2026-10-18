import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../scanner/data/qr_gallery_picker.dart';
import '../../../scanner/presentation/screens/qr_scanner_screen.dart';
import '../../data/repositories/secure_account_repository.dart';
import '../../domain/models/totp_account.dart';
import '../../domain/services/google_migration_parser.dart';
import '../../domain/services/totp_service.dart';

class AddAccountScreen extends StatefulWidget {
  final SecureAccountRepository repository;

  const AddAccountScreen({super.key, required this.repository});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _issuerController = TextEditingController();
  final _accountController = TextEditingController();
  final _secretController = TextEditingController();
  int _digits = 6;
  int _period = 30;
  TotpAlgorithm _algorithm = TotpAlgorithm.sha1;
  bool _isSaving = false;
  bool _hideSecret = true;

  @override
  void dispose() {
    _issuerController.dispose();
    _accountController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _scanQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result != null) {
      await _handleRaw(result);
    }
  }

  Future<void> _pickFromGallery() async {
    final result = await QrGalleryPicker.pickAndDecode();
    if (!mounted || result.cancelled) return;
    final value = result.value;
    if (value == null) {
      _snack('No QR code found in that image.');
      return;
    }
    await _handleRaw(value);
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _snack('Clipboard is empty.');
      return;
    }
    await _handleRaw(text);
  }

  Future<void> _handleRaw(String raw) async {
    if (!mounted) return;
    if (GoogleMigrationParser.isMigrationUri(raw)) {
      await _importMigration(raw);
      return;
    }
    final parsed = TotpService.parseUri(raw);
    if (parsed == null) {
      _snack('That is not a valid 2FA QR code or otpauth:// link.');
      return;
    }
    setState(() {
      _issuerController.text = parsed.issuer;
      _accountController.text = parsed.accountName;
      _secretController.text = parsed.secret;
      _digits = parsed.digits;
      _period = parsed.period;
      _algorithm = parsed.algorithm;
    });
    _snack('Details filled in. Review and save.');
  }

  Future<void> _importMigration(String raw) async {
    try {
      final accounts = GoogleMigrationParser.parse(raw);
      final added = await widget.repository.mergeAccounts(accounts);
      final skipped = accounts.length - added;
      _snack(
        'Imported $added account${added == 1 ? '' : 's'}'
        '${skipped > 0 ? ' ($skipped duplicate${skipped == 1 ? '' : 's'} skipped)' : ''}.',
      );
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not import that export.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final issuer = _issuerController.text.trim();
    final account = TotpAccount(
      id: const Uuid().v4(),
      accountName: _accountController.text.trim(),
      issuer: issuer.isNotEmpty ? issuer : 'Custom Account',
      secret: TotpService.normalizeSecret(_secretController.text),
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
      if (mounted) setState(() => _isSaving = false);
      _snack('Invalid Base32 secret key.');
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
      _snack('Could not save the account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add a new account',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scan a QR code, pick one from your gallery, paste a link, or type the key.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Scan',
                            onTap: _scanQr,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.photo_library_rounded,
                            label: 'Gallery',
                            onTap: _pickFromGallery,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.link_rounded,
                            label: 'Paste link',
                            onTap: _pasteLink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'OR ENTER MANUALLY',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              ),
              TextFormField(
                controller: _issuerController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: AppTheme.inputDecoration(
                  context,
                  label: 'Service / issuer',
                  hint: 'e.g. GitHub, Google, AWS',
                  icon: Icons.business_rounded,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _accountController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                decoration: AppTheme.inputDecoration(
                  context,
                  label: 'Account name or email',
                  hint: 'e.g. user@example.com',
                  icon: Icons.person_rounded,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Account name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _secretController,
                obscureText: _hideSecret,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                decoration: AppTheme.inputDecoration(
                  context,
                  label: 'Secret key (Base32)',
                  hint: 'e.g. JBSWY3DPEHPK3PXP',
                  icon: Icons.key_rounded,
                  suffix: IconButton(
                    tooltip: _hideSecret ? 'Show key' : 'Hide key',
                    icon: Icon(
                      _hideSecret
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                    onPressed: () => setState(() => _hideSecret = !_hideSecret),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Secret key is required';
                  }
                  try {
                    TotpService.generateCodeForStep(
                      secret: val,
                      timeStep: 0,
                      digits: _digits,
                      algorithm: _algorithm,
                    );
                  } on FormatException {
                    return 'Use a valid Base32 key (A-Z and 2-7)';
                  }
                  return null;
                },
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
                    'Advanced options',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Digits, interval and algorithm'),
                  expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text('Digits', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 6, label: Text('6 digits')),
                        ButtonSegment(value: 8, label: Text('8 digits')),
                      ],
                      selected: {_digits},
                      onSelectionChanged: (v) =>
                          setState(() => _digits = v.first),
                    ),
                    const SizedBox(height: 16),
                    Text('Interval', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 30, label: Text('30 s')),
                        ButtonSegment(value: 60, label: Text('60 s')),
                      ],
                      selected: {_period},
                      onSelectionChanged: (v) =>
                          setState(() => _period = v.first),
                    ),
                    const SizedBox(height: 16),
                    Text('Algorithm', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
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
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Save account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: scheme.primary, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
