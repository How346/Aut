import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../security/app_lock_controller.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../data/repositories/secure_account_repository.dart';
import '../../domain/models/totp_account.dart';
import '../../domain/services/totp_service.dart';
import 'add_account_screen.dart';

class HomeScreen extends StatefulWidget {
  final SecureAccountRepository repository;
  final ThemeController themeController;
  final AppLockController lockController;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.themeController,
    required this.lockController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TotpAccount> _accounts = [];
  String _query = '';
  Timer? _ticker;
  Timer? _clipboardTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _accounts.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clipboardTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final loaded = await widget.repository.getAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = loaded;
      _isLoading = false;
    });
  }

  List<TotpAccount> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _accounts;
    return _accounts
        .where((a) =>
            a.accountName.toLowerCase().contains(q) ||
            a.issuer.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _copy(TotpAccount account) async {
    final String code;
    try {
      code = TotpService.generateCode(account);
    } catch (_) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    await HapticFeedback.lightImpact();
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(const Duration(seconds: 30), () async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == code) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Code copied for ${account.issuer}'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _delete(TotpAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text(
          'Remove ${account.issuer} (${account.accountName})? '
          'Make sure you can still sign in without it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.repository.deleteAccount(account.id);
    await _loadAccounts();
  }

  Future<void> _edit(TotpAccount account) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => _EditDialog(account: account),
    );
    if (result == null) return;
    await widget.repository.updateAccount(
      account.copyWith(issuer: result.$1, accountName: result.$2),
    );
    await _loadAccounts();
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAccountScreen(repository: widget.repository),
      ),
    );
    if (added == true) {
      await _loadAccounts();
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          repository: widget.repository,
          themeController: widget.themeController,
          lockController: widget.lockController,
          onDataRestored: _loadAccounts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = _filtered;

    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_accounts.isEmpty) {
      body = _EmptyState(onAdd: _openAdd);
    } else if (accounts.isEmpty) {
      body = Center(
        child: Text(
          'No matching accounts',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final account = accounts[index];
          return Dismissible(
            key: ValueKey(account.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async {
              await _delete(account);
              return false;
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: _AccountCard(
              account: account,
              onCopy: () => _copy(account),
              onEdit: () => _edit(account),
              onDelete: () => _delete(account),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Authly'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_accounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                decoration: AppTheme.inputDecoration(
                  context,
                  label: 'Search',
                  icon: Icons.search,
                ),
                onChanged: (val) => setState(() => _query = val),
              ),
            ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add account',
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}

enum _CardAction { edit, delete }

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final TotpAccount account;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static String _group(String code) {
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    if (code.length == 8) return '${code.substring(0, 4)} ${code.substring(4)}';
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final info = TotpService.getPeriodProgress(period: account.period);
    final urgent = info.secondsRemaining <= 5;
    final color = urgent ? scheme.error : scheme.primary;

    String? code;
    try {
      code = TotpService.generateCode(account);
    } catch (_) {
      code = null;
    }

    final initial = account.issuer.trim().isEmpty
        ? '?'
        : account.issuer.trim().substring(0, 1).toUpperCase();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: code == null ? null : onCopy,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.issuer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      account.accountName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        code == null ? 'Invalid key' : _group(code),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                          color: code == null ? scheme.error : color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: info.progress,
                        strokeWidth: 3.5,
                        backgroundColor: scheme.outlineVariant,
                        color: color,
                      ),
                    ),
                    Text(
                      '${info.secondsRemaining}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_CardAction>(
                tooltip: 'More',
                onSelected: (action) {
                  switch (action) {
                    case _CardAction.edit:
                      onEdit();
                    case _CardAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _CardAction.edit, child: Text('Edit')),
                  PopupMenuItem(
                    value: _CardAction.delete,
                    child: Text('Remove'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.shield_outlined,
                size: 44,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No accounts yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add an account by scanning a QR code or entering a key.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.account});

  final TotpAccount account;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
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

  void _save() {
    final issuer = _issuer.text.trim();
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      (issuer.isEmpty ? widget.account.issuer : issuer, name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _issuer,
              textCapitalization: TextCapitalization.words,
              decoration: AppTheme.inputDecoration(context, label: 'Service'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration:
                  AppTheme.inputDecoration(context, label: 'Account name'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
