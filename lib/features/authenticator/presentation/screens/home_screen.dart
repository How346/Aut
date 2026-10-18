import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/totp_account.dart';
import '../../domain/services/totp_service.dart';
import '../../data/repositories/secure_account_repository.dart';
import 'add_account_screen.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../security/app_lock_controller.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<TotpAccount> _accounts = [];
  String _searchQuery = '';
  Timer? _ticker;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAccounts();
    _startTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadAccounts() async {
    final loaded = await widget.repository.getAccounts();
    if (mounted) {
      setState(() {
        _accounts = loaded;
        _isLoading = false;
      });
    }
  }

  List<TotpAccount> get _filteredAccounts {
    if (_searchQuery.trim().isEmpty) return _accounts;
    final q = _searchQuery.toLowerCase();
    return _accounts.where((a) {
      return a.accountName.toLowerCase().contains(q) ||
          a.issuer.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _copyToClipboard(String code, String issuer) async {
    await Clipboard.setData(ClipboardData(text: code));
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$issuer code copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteAccount(TotpAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Are you sure you want to remove ${account.issuer} (${account.accountName})? You cannot undo this without a backup.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repository.deleteAccount(account.id);
      await _loadAccounts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${account.issuer} removed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.shield_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Text('Authly', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
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
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search accounts or issuers...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                  ),
                ),
                Expanded(
                  child: _filteredAccounts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_clock, size: 64, color: theme.disabledColor),
                              const SizedBox(height: 16),
                              Text(
                                _accounts.isEmpty
                                    ? 'No accounts yet'
                                    : 'No accounts match "$_searchQuery"',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _accounts.isEmpty
                                    ? 'Tap the + button below to scan a QR code'
                                    : 'Try searching with a different term',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.disabledColor,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredAccounts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final account = _filteredAccounts[index];
                            final periodInfo = TotpService.getPeriodProgress(
                              period: account.period,
                            );
                            final code = TotpService.generateCode(account);
                            final formattedCode = code.length == 6
                                ? '${code.substring(0, 3)} ${code.substring(3)}'
                                : code;

                            return Dismissible(
                              key: ValueKey(account.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) async {
                                await _deleteAccount(account);
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _copyToClipboard(code, account.issuer),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            CircularProgressIndicator(
                                              value: periodInfo.progress,
                                              strokeWidth: 3.5,
                                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                periodInfo.secondsRemaining <= 5
                                                    ? Colors.red
                                                    : theme.colorScheme.primary,
                                              ),
                                            ),
                                            Center(
                                              child: Text(
                                                '${periodInfo.secondsRemaining}s',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: periodInfo.secondsRemaining <= 5
                                                      ? Colors.red
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              account.issuer,
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              account.accountName,
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              formattedCode,
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 2.0,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _deleteAccount(account),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddAccountScreen(repository: widget.repository),
            ),
          );
          if (added == true) {
            await _loadAccounts();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
      ),
    );
  }
}
