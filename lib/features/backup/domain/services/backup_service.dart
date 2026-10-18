import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../../authenticator/domain/models/totp_account.dart';

/// Thrown when a backup cannot be decrypted or is malformed.
class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

class BackupService {
  static const int version = 1;
  static const int iterations = 210000;
  static const int saltLength = 32;
  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int minPasswordLength = 8;

  static final AesGcm _cipher = AesGcm.with256bits();
  static final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );

  static List<int> _randomBytes(int length) {
    final rng = Random.secure();
    return List<int>.generate(length, (_) => rng.nextInt(256));
  }

  /// Creates a PBKDF2-HMAC-SHA256 + AES-256-GCM encrypted backup (JSON string).
  static Future<String> createEncryptedBackup({
    required List<TotpAccount> accounts,
    required String password,
  }) async {
    if (password.length < minPasswordLength) {
      throw ArgumentError(
        'Backup password must be at least $minPasswordLength characters',
      );
    }
    final plaintext =
        utf8.encode(jsonEncode(accounts.map((a) => a.toJson()).toList()));
    final salt = _randomBytes(saltLength);
    final nonce = _cipher.newNonce();
    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final box = await _cipher.encrypt(plaintext, secretKey: key, nonce: nonce);
    return jsonEncode({
      'app': 'authly',
      'version': version,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  /// Decrypts and validates a backup. Throws [BackupException] on any failure.
  static Future<List<TotpAccount>> restoreBackup({
    required String backupJson,
    required String password,
  }) async {
    final List<int> salt;
    final List<int> nonce;
    final List<int> ciphertext;
    final List<int> macBytes;
    try {
      final container = jsonDecode(backupJson) as Map<String, dynamic>;
      if (container['version'] != version ||
          container['kdf'] != 'PBKDF2-HMAC-SHA256' ||
          container['cipher'] != 'AES-256-GCM' ||
          container['iterations'] != iterations) {
        throw const BackupException('Unsupported backup format');
      }
      salt = base64Decode(container['salt'] as String);
      nonce = base64Decode(container['nonce'] as String);
      ciphertext = base64Decode(container['ciphertext'] as String);
      macBytes = base64Decode(container['mac'] as String);
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException('Not a valid Authly backup file');
    }
    if (salt.length != saltLength ||
        nonce.length != nonceLength ||
        macBytes.length != macLength) {
      throw const BackupException('Invalid backup cryptographic parameters');
    }

    final List<int> plaintext;
    try {
      final key = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      plaintext = await _cipher.decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes)),
        secretKey: key,
      );
    } catch (_) {
      throw const BackupException('Incorrect password or corrupted backup');
    }

    try {
      final list = jsonDecode(utf8.decode(plaintext)) as List<dynamic>;
      final accounts = list
          .map((e) => TotpAccount.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      if (accounts.map((a) => a.id).toSet().length != accounts.length) {
        throw const BackupException('Backup contains duplicate accounts');
      }
      return accounts;
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException('Backup contents are malformed');
    }
  }
}
