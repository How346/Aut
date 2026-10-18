import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/models/totp_account.dart';

class SecureAccountRepository {
  static const String _storageKey = 'authly_accounts_vault_v1';
  final FlutterSecureStorage _storage;

  SecureAccountRepository({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: true,
              ),
            );

  Future<List<TotpAccount>> getAccounts() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => TotpAccount.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAccounts(List<TotpAccount> accounts) async {
    final encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _storage.write(key: _storageKey, value: encoded);
  }

  Future<void> addAccount(TotpAccount account) async {
    final current = await getAccounts();
    current.add(account);
    await saveAccounts(current);
  }

  Future<void> updateAccount(TotpAccount account) async {
    final current = await getAccounts();
    final index = current.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      current[index] = account;
      await saveAccounts(current);
    }
  }

  Future<void> deleteAccount(String id) async {
    final current = await getAccounts();
    current.removeWhere((a) => a.id == id);
    await saveAccounts(current);
  }

  /// Adds accounts that are not already present (same id, or same
  /// issuer + name + secret). Returns how many were added.
  Future<int> mergeAccounts(List<TotpAccount> incoming) async {
    final current = await getAccounts();
    final ids = current.map((a) => a.id).toSet();
    final keys = current.map(_dedupeKey).toSet();
    var added = 0;
    for (final account in incoming) {
      if (ids.contains(account.id) || keys.contains(_dedupeKey(account))) {
        continue;
      }
      current.add(account);
      ids.add(account.id);
      keys.add(_dedupeKey(account));
      added++;
    }
    if (added > 0) {
      await saveAccounts(current);
    }
    return added;
  }

  static String _dedupeKey(TotpAccount a) =>
      '${a.issuer}\u0000${a.accountName}\u0000${a.secret}';
}
