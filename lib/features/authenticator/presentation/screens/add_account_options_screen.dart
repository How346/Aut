import 'package:flutter/material.dart';

import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/service_icon.dart';
import '../../../scanner/data/qr_gallery_picker.dart';
import '../../../scanner/presentation/screens/qr_scanner_screen.dart';
import '../../data/repositories/secure_account_repository.dart';
import '../../domain/services/google_migration_parser.dart';
import '../../domain/services/totp_service.dart';
import 'setup_key_screen.dart';

class AddAccountOptionsScreen extends StatefulWidget {
  const AddAccountOptionsScreen({super.key, required this.repository});

  final SecureAccountRepository repository;

  @override
  State<AddAccountOptionsScreen> createState() =>
      _AddAccountOptionsScreenState();
}

class _AddAccountOptionsScreenState extends State<AddAccountOptionsScreen> {
  static const List<String> _popular = [
    'Google',
    'Microsoft',
    'GitHub',
    'Amazon',
    'Discord',
    'Dropbox',
    'Slack',
  ];

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (raw != null) await _handleRaw(raw);
  }

  Future<void> _gallery() async {
    final result = await QrGalleryPicker.pickAndDecode();
    if (!mounted || result.cancelled) return;
    final value = result.value;
    if (value == null) {
      _snack('No QR code found in that image.');
      return;
    }
    await _handleRaw(value);
  }

  Future<void> _setupKey({String? issuer}) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SetupKeyScreen(
          repository: widget.repository,
          initialIssuer: issuer,
        ),
      ),
    );
    if (added == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _handleRaw(String raw) async {
    try {
      if (GoogleMigrationParser.isMigrationUri(raw)) {
        final accounts = GoogleMigrationParser.parse(raw);
        final added = await widget.repository.mergeAccounts(accounts);
        final skipped = accounts.length - added;
        _snack(
          'Imported $added account${added == 1 ? '' : 's'}'
          '${skipped > 0 ? ' ($skipped already added)' : ''}.',
        );
        if (added > 0 && mounted) Navigator.pop(context, true);
        return;
      }
      final parsed = TotpService.parseUri(raw);
      if (parsed == null) {
        _snack('That is not a valid 2FA QR code.');
        return;
      }
      final added = await widget.repository.mergeAccounts([parsed]);
      if (added == 0) {
        _snack('This account is already added.');
        return;
      }
      _snack('${parsed.issuer} added.');
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not add that account.');
    }
  }

  Widget _optionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return PressScale(
      child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _optionTile(
            context,
            icon: Icons.qr_code_scanner,
            title: 'Scan QR Code',
            subtitle: 'Scan a QR code from your service',
            onTap: _scan,
          ),
          const SizedBox(height: 10),
          _optionTile(
            context,
            icon: Icons.photo_library_outlined,
            title: 'Choose QR from Gallery',
            subtitle: 'Pick a saved screenshot or photo',
            onTap: _gallery,
          ),
          const SizedBox(height: 10),
          _optionTile(
            context,
            icon: Icons.key_outlined,
            title: 'Enter Setup Key',
            subtitle: 'Manually enter your setup key',
            onTap: _setupKey,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 24, 0, 8),
            child: Text(
              'Popular Services',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < _popular.length; i++) ...[
                  if (i > 0) const Divider(indent: 56),
                  ListTile(
                    dense: true,
                    leading: ServiceIcon(issuer: _popular[i], size: 28),
                    title: Text(
                      _popular[i],
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                    onTap: () => _setupKey(issuer: _popular[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
