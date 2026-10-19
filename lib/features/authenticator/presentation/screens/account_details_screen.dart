import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/confirm_dialogs.dart';
import '../../../../core/widgets/countdown_ring.dart';
import '../../../../core/widgets/service_icon.dart';
import '../../data/repositories/secure_account_repository.dart';
import '../../domain/models/totp_account.dart';
import '../../domain/services/totp_service.dart';
import '../code_clipboard.dart';
import 'edit_account_screen.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({
    super.key,
    required this.accountId,
    required this.repository,
    required this.settings,
  });

  final String accountId;
  final SecureAccountRepository repository;
  final AppSettings settings;

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  TotpAccount? _account;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _account != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await widget.repository.getAccounts();
    if (!mounted) return;
    final matches = all.where((a) => a.id == widget.accountId);
    if (matches.isEmpty) {
      Navigator.pop(context, true);
      return;
    }
    setState(() => _account = matches.first);
  }

  Future<void> _edit(TotpAccount account) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditAccountScreen(
          account: account,
          repository: widget.repository,
        ),
      ),
    );
    await _load();
  }

  Future<void> _remove(TotpAccount account) async {
    final ok = await confirmAction(
      context,
      title: 'Remove account?',
      message: 'Remove ${account.issuer}? Make sure you can still sign in '
          'without it.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    await widget.repository.deleteAccount(account.id);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  void _more(TotpAccount account) {
    final algorithm = switch (account.algorithm) {
      TotpAlgorithm.sha1 => 'SHA-1',
      TotpAlgorithm.sha256 => 'SHA-256',
      TotpAlgorithm.sha512 => 'SHA-512',
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Digits'),
              trailing: Text('${account.digits}'),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Refresh interval'),
              trailing: Text('${account.period} seconds'),
            ),
            ListTile(
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: const Text('Algorithm'),
              trailing: Text(algorithm),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Added on'),
              trailing: Text(
                account.createdAt.toLocal().toString().substring(0, 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurface;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: c),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color ?? scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final account = _account;
    if (account == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final info = TotpService.getPeriodProgress(period: account.period);
    String? code;
    try {
      code = TotpService.generateCode(account);
    } catch (_) {
      code = null;
    }
    final urgent = info.secondsRemaining <= 5;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 330,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppTheme.hero(context)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      color: Colors.white,
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ),
                  ServiceIcon(issuer: account.issuer, size: 64),
                  const SizedBox(height: 10),
                  Text(
                    account.issuer,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.accountName,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 26),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Card(
                      elevation: 3,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      code == null
                                          ? 'Invalid key'
                                          : CodeClipboard.group(code),
                                      style: TextStyle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                        color: code == null || urgent
                                            ? scheme.error
                                            : scheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                CountdownRing(
                                  progress: info.progress,
                                  seconds: info.secondsRemaining,
                                  size: 46,
                                  strokeWidth: 3.5,
                                  showSuffix: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: code == null
                                  ? null
                                  : () => CodeClipboard.copy(
                                        context,
                                        account,
                                        widget.settings,
                                      ),
                              icon: const Icon(Icons.copy_outlined, size: 18),
                              label: const Text('Copy'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Row(
                      children: [
                        _action(
                          context,
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          onTap: () => _edit(account),
                        ),
                        _action(
                          context,
                          icon: Icons.delete_outline,
                          label: 'Remove',
                          color: scheme.error,
                          onTap: () => _remove(account),
                        ),
                        _action(
                          context,
                          icon: Icons.more_horiz,
                          label: 'More',
                          onTap: () => _more(account),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
