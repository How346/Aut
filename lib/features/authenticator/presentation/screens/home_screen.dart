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
  final TextEditingController _searchController = TextEditingController();
  List<TotpAccount> _accounts = [];
  String _query = '';
  Timer? _ticker;
  Timer? _clipboardTimer;
  bool _isLoading = true;
  bool _hideCodes = false;

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
    _searchController.dispose();
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

  String? _safeCode(TotpAccount account) {
    try {
      return TotpService.generateCode(account);
    } catch (_) {
      return null;
    }
  }

  Future<void> _copy(TotpAccount account) async {
    final code = _safeCode(account);
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    await HapticFeedback.mediumImpact();
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
          content: Text('${account.issuer} code copied. Clipboard clears in 30s.'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<bool> _confirmDelete(TotpAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove account?'),
        content: Text(
          'Remove ${account.issuer} (${account.accountName})? '
          'You will lose access to its codes unless you have a backup or '
          'another way to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  Future<void> _delete(TotpAccount account) async {
    if (!await _confirmDelete(account)) return;
    await widget.repository.deleteAccount(account.id);
    await _loadAccounts();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${account.issuer} removed')));
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

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = _accounts.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Authly',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  count == 0
                      ? 'Offline • Private • Secure'
                      : '$count account${count == 1 ? '' : 's'} • Offline & encrypted',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _hideCodes ? 'Show codes' : 'Hide codes',
            icon: Icon(
              _hideCodes
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
            onPressed: () => setState(() => _hideCodes = !_hideCodes),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: AppTheme.inputDecoration(
          context,
          label: 'Search accounts',
          icon: Icons.search_rounded,
          suffix: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
        ),
        onChanged: (val) => setState(() => _query = val),
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
          'No accounts match "$_query"',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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
              padding: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.delete_rounded, color: Colors.white),
            ),
            child: _AccountCard(
              account: account,
              hidden: _hideCodes,
              onCopy: () => _copy(account),
              onEdit: () => _edit(account),
              onDelete: () => _delete(account),
            ),
          );
        },
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            if (_accounts.isNotEmpty) _buildSearch(context),
            Expanded(child: body),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add account'),
      ),
    );
  }
}

enum _CardAction { copy, edit, delete }

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.hidden,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final TotpAccount account;
  final bool hidden;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String? _code(DateTime time) {
    try {
      return TotpService.generateCode(account, time: time);
    } catch (_) {
      return null;
    }
  }

  static String _group(String code) {
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    if (code.length == 8) return '${code.substring(0, 4)} ${code.substring(4)}';
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final info = TotpService.getPeriodProgress(
      period: account.period,
      time: now,
    );
    final urgent = info.secondsRemaining <= 5;
    final code = _code(now);
    final next = urgent
        ? _code(now.add(Duration(seconds: info.secondsRemaining)))
        : null;
    final accent = urgent ? scheme.error : scheme.primary;

    final String shown;
    if (code == null) {
      shown = 'Invalid key';
    } else if (hidden) {
      shown = account.digits == 8 ? '•••• ••••' : '••• •••';
    } else {
      shown = _group(code);
    }

    final initial = account.issuer.trim().isEmpty
        ? '?'
        : account.issuer.trim().substring(0, 1).toUpperCase();
    final seed = account.issuer.codeUnits.fold<int>(0, (a, b) => a + b);
    final colors =
        AppTheme.avatarGradients[seed % AppTheme.avatarGradients.length];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: code == null ? null : onCopy,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.issuer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        shown,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          fontFamily: 'monospace',
                          color: code == null ? scheme.error : accent,
                        ),
                      ),
                    ),
                    if (next != null && !hidden)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Next: ${_group(next)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: info.progress,
                        strokeWidth: 4,
                        strokeCap: StrokeCap.round,
                        backgroundColor: scheme.outlineVariant,
                        color: accent,
                      ),
                    ),
                    Text(
                      '${info.secondsRemaining}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_CardAction>(
                tooltip: 'More',
                icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
                onSelected: (action) {
                  switch (action) {
                    case _CardAction.copy:
                      onCopy();
                    case _CardAction.edit:
                      onEdit();
                    case _CardAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _CardAction.copy,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.copy_rounded),
                      title: Text('Copy code'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _CardAction.edit,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_rounded),
                      title: Text('Edit'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _CardAction.delete,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_rounded),
                      title: Text('Remove'),
                    ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                gradient: AppTheme.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 54,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No accounts yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a QR code, pick one from your gallery, or enter a key to start generating secure one-time codes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first account'),
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
    Navigator.pop(context, (issuer.isEmpty ? widget.account.issuer : issuer, name));
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
              decoration: AppTheme.inputDecoration(
                context,
                label: 'Service / issuer',
                icon: Icons.business_rounded,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: AppTheme.inputDecoration(
                context,
                label: 'Account name',
                icon: Icons.person_rounded,
              ),
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
