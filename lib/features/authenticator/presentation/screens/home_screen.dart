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
  const HomeScreen({super.key, required this.repository, required this.themeController, required this.lockController});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
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
    setState(() { _accounts = loaded; _isLoading = false; });
  }

  List<TotpAccount> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _accounts;
    return _accounts.where((a) => a.accountName.toLowerCase().contains(q) || a.issuer.toLowerCase().contains(q)).toList();
  }

  String? _safeCode(TotpAccount account) {
    try { return TotpService.generateCode(account); } catch (_) { return null; }
  }

  Future<void> _copy(TotpAccount account) async {
    final code = _safeCode(account);
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    await HapticFeedback.selectionClick();
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(const Duration(seconds: 30), () async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == code) await Clipboard.setData(const ClipboardData(text: ''));
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
      SnackBar(content: Text('${account.issuer} code copied'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  Future<bool> _confirmDelete(TotpAccount account) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Remove account?'),
      content: Text('Remove ${account.issuer} (${account.accountName})? You may lose access to its codes unless you have a backup.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove'))],
    ));
    return confirm == true;
  }

  Future<void> _delete(TotpAccount account) async {
    if (!await _confirmDelete(account)) return;
    await widget.repository.deleteAccount(account.id);
    await _loadAccounts();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${account.issuer} removed')));
  }

  Future<void> _edit(TotpAccount account) async {
    final result = await showDialog<(String, String)>(context: context, builder: (ctx) => _EditDialog(account: account));
    if (result == null) return;
    await widget.repository.updateAccount(account.copyWith(issuer: result.$1, accountName: result.$2));
    await _loadAccounts();
  }

  Future<void> _openAdd() async {
    final added = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AddAccountScreen(repository: widget.repository)));
    if (added == true) await _loadAccounts();
  }

  void _openSettings() => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(
    repository: widget.repository, themeController: widget.themeController, lockController: widget.lockController, onDataRestored: _loadAccounts,
  )));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accounts = _filtered;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
            child: Row(children: [
              Image.asset('assets/authly_logo.png', width: 38, height: 38, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.shield_rounded, size: 36, color: scheme.primary)),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Authly', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                Text('Verification codes', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ])),
              IconButton(tooltip: _hideCodes ? 'Show codes' : 'Hide codes', onPressed: () => setState(() => _hideCodes = !_hideCodes),
                icon: Icon(_hideCodes ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
              IconButton(tooltip: 'Settings', onPressed: _openSettings, icon: const Icon(Icons.settings_outlined)),
            ]),
          ),
          if (_accounts.isNotEmpty) Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search accounts', prefixIcon: const Icon(Icons.search_rounded, size: 21),
                suffixIcon: _query.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: () { _searchController.clear(); setState(() => _query = ''); }),
                filled: true, fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.primary, width: 1.2)),
              ),
            ),
          ),
          Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _accounts.isEmpty ? _EmptyState(onAdd: _openAdd)
            : accounts.isEmpty ? Center(child: Text('No accounts found', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)))
            : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
                Padding(padding: const EdgeInsets.fromLTRB(3, 2, 3, 12), child: Row(children: [
                  Text('YOUR ACCOUNTS', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.1, color: scheme.onSurfaceVariant)),
                  const Spacer(), Text('${accounts.length}', style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ])),
                for (final account in accounts) Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AccountCard(account: account, hidden: _hideCodes, onCopy: () => _copy(account), onEdit: () => _edit(account), onDelete: () => _delete(account)),
                ),
              ])),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add account')),
    );
  }
}

enum _CardAction { edit, delete }

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.hidden, required this.onCopy, required this.onEdit, required this.onDelete});
  final TotpAccount account;
  final bool hidden;
  final VoidCallback onCopy, onEdit, onDelete;

  String? _code(DateTime time) { try { return TotpService.generateCode(account, time: time); } catch (_) { return null; } }
  String _group(String code) => code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final progress = TotpService.getPeriodProgress(period: account.period, time: now);
    final code = _code(now);
    final urgent = progress.secondsRemaining <= 5;
    final color = urgent ? scheme.error : scheme.primary;
    final issuer = account.issuer.trim().isEmpty ? 'Account' : account.issuer.trim();
    final initial = issuer.substring(0, 1).toUpperCase();
    final seed = issuer.codeUnits.fold<int>(0, (a, b) => a + b);
    final colors = AppTheme.avatarGradients[seed % AppTheme.avatarGradients.length];
    final shown = code == null ? 'Invalid key' : hidden ? (account.digits == 8 ? '•••• ••••' : '••• •••') : _group(code);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55))),
      child: InkWell(onTap: code == null ? null : onCopy, child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(13)),
              child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
            const SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(issuer, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(account.accountName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ])),
            PopupMenuButton<_CardAction>(tooltip: 'Account options', padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 44),
              icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurfaceVariant), onSelected: (a) { if (a == _CardAction.edit) onEdit(); else onDelete(); },
              itemBuilder: (_) => const [PopupMenuItem(value: _CardAction.edit, child: Text('Edit account')), PopupMenuItem(value: _CardAction.delete, child: Text('Remove account'))]),
          ]),
          const SizedBox(height: 15),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(shown,
              maxLines: 1, style: TextStyle(fontFamily: 'monospace', fontSize: 31, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: code == null ? scheme.error : color)))),
            const SizedBox(width: 12),
            SizedBox(width: 38, height: 38, child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(child: CircularProgressIndicator(value: progress.progress, strokeWidth: 3, strokeCap: StrokeCap.round, backgroundColor: scheme.surfaceContainerHighest, color: color)),
              Text('${progress.secondsRemaining}', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
            ])),
            const SizedBox(width: 5),
            IconButton(onPressed: code == null ? null : onCopy, tooltip: 'Copy code', visualDensity: VisualDensity.compact,
              icon: Icon(Icons.copy_rounded, size: 20, color: scheme.primary)),
          ]),
        ]),
      )),
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
    return Center(child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 104, height: 104, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.65), shape: BoxShape.circle),
        child: Image.asset('assets/authly_logo.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.shield_outlined, size: 64, color: scheme.primary))),
      const SizedBox(height: 24),
      Text('Your codes, all in one place', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4)),
      const SizedBox(height: 9),
      Text('Add an account to generate verification codes. Your accounts stay on this device.', textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 22),
      FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Add your first account'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14))),
    ]))));
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.account});
  final TotpAccount account;
  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _issuer = TextEditingController(text: widget.account.issuer);
  late final TextEditingController _name = TextEditingController(text: widget.account.accountName);
  @override
  void dispose() { _issuer.dispose(); _name.dispose(); super.dispose(); }
  void _save() { final issuer = _issuer.text.trim(); final name = _name.text.trim(); if (name.isEmpty) return; Navigator.pop(context, (issuer.isEmpty ? widget.account.issuer : issuer, name)); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit account'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _issuer, textCapitalization: TextCapitalization.words, decoration: AppTheme.inputDecoration(context, label: 'Service name', icon: Icons.business_outlined)),
      const SizedBox(height: 12),
      TextField(controller: _name, decoration: AppTheme.inputDecoration(context, label: 'Account name', icon: Icons.person_outline_rounded)),
    ])),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _save, child: const Text('Save'))],
  );
}
