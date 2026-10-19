import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/confirm_dialogs.dart';
import '../../core/widgets/service_icon.dart';
import '../authenticator/data/repositories/secure_account_repository.dart';
import '../authenticator/domain/models/totp_account.dart';
import '../authenticator/presentation/code_clipboard.dart';
import '../authenticator/presentation/screens/account_details_screen.dart';
import '../authenticator/presentation/screens/add_account_options_screen.dart';
import '../authenticator/presentation/screens/edit_account_screen.dart';
import '../authenticator/presentation/widgets/account_card.dart';
import '../security/app_lock_controller.dart';
import '../settings/presentation/screens/settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    required this.themeController,
    required this.lockController,
    required this.settings,
  });

  final SecureAccountRepository repository;
  final ThemeController themeController;
  final AppLockController lockController;
  final AppSettings settings;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  List<TotpAccount> _accounts = [];
  bool _loading = true;
  String _query = '';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _tab != 2 && _accounts.isNotEmpty) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await widget.repository.getAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = loaded;
      _loading = false;
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

  Future<void> _openAdd() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAccountOptionsScreen(repository: widget.repository),
      ),
    );
    if (added == true) await _load();
  }

  Future<void> _openDetails(TotpAccount account) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountDetailsScreen(
          accountId: account.id,
          repository: widget.repository,
          settings: widget.settings,
        ),
      ),
    );
    await _load();
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

  Future<void> _delete(TotpAccount account) async {
    final ok = await confirmAction(
      context,
      title: 'Remove account?',
      message: 'Remove ${account.issuer}? Make sure you can still sign in '
          'without it.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    await widget.repository.deleteAccount(account.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _HomeTab(
        loading: _loading,
        allAccounts: _accounts,
        accounts: _filtered,
        query: _query,
        onQuery: (v) => setState(() => _query = v),
        onOpen: _openDetails,
        onCopy: (a) => CodeClipboard.copy(context, a, widget.settings),
        onAdd: _openAdd,
        onSettings: () => setState(() => _tab = 2),
      ),
      _AccountsTab(
        loading: _loading,
        accounts: _accounts,
        onOpen: _openDetails,
        onEdit: _edit,
        onDelete: _delete,
        onAdd: _openAdd,
      ),
      SettingsScreen(
        repository: widget.repository,
        themeController: widget.themeController,
        lockController: widget.lockController,
        settings: widget.settings,
        onDataChanged: _load,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: tabs),
      floatingActionButton: _tab == 2
          ? null
          : FloatingActionButton(
              tooltip: 'Add account',
              onPressed: _openAdd,
              child: const Icon(Icons.add, size: 30),
            ),
      bottomNavigationBar: _BottomBar(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.people_outline, Icons.people_rounded, 'Accounts'),
      (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == index ? items[i].$2 : items[i].$1,
                          color: i == index
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].$3,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: i == index
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.shield_rounded, size: 64, color: scheme.primary),
                  const Icon(Icons.lock_rounded, size: 26, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'No Accounts Yet',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first account to get started with Authly.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.loading,
    required this.allAccounts,
    required this.accounts,
    required this.query,
    required this.onQuery,
    required this.onOpen,
    required this.onCopy,
    required this.onAdd,
    required this.onSettings,
  });

  final bool loading;
  final List<TotpAccount> allAccounts;
  final List<TotpAccount> accounts;
  final String query;
  final ValueChanged<String> onQuery;
  final ValueChanged<TotpAccount> onOpen;
  final ValueChanged<TotpAccount> onCopy;
  final VoidCallback onAdd;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (allAccounts.isEmpty) {
      body = _EmptyState(onAdd: onAdd);
    } else if (accounts.isEmpty) {
      body = Center(
        child: Text(
          'No matching accounts',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final account = accounts[i];
          return AccountCard(
            account: account,
            onTap: () => onOpen(account),
            onLongPress: () => onCopy(account),
          );
        },
      );
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Authly',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.tune),
                  onPressed: onSettings,
                ),
              ],
            ),
          ),
          if (allAccounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: TextField(
                onChanged: onQuery,
                decoration: InputDecoration(
                  hintText: 'Search accounts...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab({
    required this.loading,
    required this.accounts,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final bool loading;
  final List<TotpAccount> accounts;
  final ValueChanged<TotpAccount> onOpen;
  final ValueChanged<TotpAccount> onEdit;
  final ValueChanged<TotpAccount> onDelete;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (accounts.isEmpty) {
      body = _EmptyState(onAdd: onAdd);
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final account = accounts[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onOpen(account),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(
                  children: [
                    ServiceIcon(issuer: account.issuer, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.issuer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (account.accountName.isNotEmpty)
                            Text(
                              account.accountName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      icon: Icon(Icons.edit_outlined, color: scheme.primary),
                      onPressed: () => onEdit(account),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: Icon(Icons.delete_outline, color: scheme.error),
                      onPressed: () => onDelete(account),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
            child: Text(
              'Accounts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
