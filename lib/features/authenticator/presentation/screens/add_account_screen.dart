import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/totp_account.dart';
import '../../domain/services/totp_service.dart';
import '../../data/repositories/secure_account_repository.dart';
import '../../../scanner/presentation/screens/qr_scanner_screen.dart';

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

  @override
  void dispose() {
    _issuerController.dispose();
    _accountController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );

    if (result != null && mounted) {
      final parsed = TotpService.parseUri(result);
      if (parsed != null) {
        setState(() {
          _issuerController.text = parsed.issuer;
          _accountController.text = parsed.accountName;
          _secretController.text = parsed.secret;
          _digits = parsed.digits;
          _period = parsed.period;
          _algorithm = parsed.algorithm;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scanned QR code successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid 2FA QR code URI.')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final account = TotpAccount(
      id: const Uuid().v4(),
      accountName: _accountController.text.trim(),
      issuer: _issuerController.text.trim().isNotEmpty
          ? _issuerController.text.trim()
          : 'Custom Account',
      secret: TotpService.normalizeSecret(_secretController.text),
      digits: _digits,
      period: _period,
      algorithm: _algorithm,
      createdAt: DateTime.now(),
    );

    try {
      // Test code generation to ensure valid secret
      TotpService.generateCode(account);
      await widget.repository.addAccount(account);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on FormatException {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid Base32 secret key.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the account.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Account'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _scanQr,
                icon: const Icon(Icons.qr_code_scanner, size: 28),
                label: const Text('Scan QR Code', style: TextStyle(fontSize: 16)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR ENTER MANUALLY', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              TextFormField(
                controller: _issuerController,
                decoration: const InputDecoration(
                  labelText: 'Service / Issuer',
                  hintText: 'e.g. GitHub, Google, AWS',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountController,
                decoration: const InputDecoration(
                  labelText: 'Account Username / Email',
                  hintText: 'e.g. user@example.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Account name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _secretController,
                decoration: const InputDecoration(
                  labelText: 'Secret Key (Base32)',
                  hintText: 'e.g. JBSWY3DPEHPK3PXP',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Secret key is required';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Text('Digits', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 6, label: Text('6 digits')),
                  ButtonSegment(value: 8, label: Text('8 digits')),
                ],
                selected: {_digits},
                onSelectionChanged: (v) => setState(() => _digits = v.first),
              ),
              const SizedBox(height: 16),
              Text('Interval', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 30, label: Text('30 s')),
                  ButtonSegment(value: 60, label: Text('60 s')),
                ],
                selected: {_period},
                onSelectionChanged: (v) => setState(() => _period = v.first),
              ),
              const SizedBox(height: 16),
              Text('Algorithm', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<TotpAlgorithm>(
                segments: const [
                  ButtonSegment(value: TotpAlgorithm.sha1, label: Text('SHA-1')),
                  ButtonSegment(value: TotpAlgorithm.sha256, label: Text('SHA-256')),
                  ButtonSegment(value: TotpAlgorithm.sha512, label: Text('SHA-512')),
                ],
                selected: {_algorithm},
                onSelectionChanged: (v) => setState(() => _algorithm = v.first),
              ),
              const SizedBox(height: 32),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
