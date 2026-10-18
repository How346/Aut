import 'dart:convert';

import 'package:authly/features/authenticator/domain/models/totp_account.dart';
import 'package:authly/features/backup/domain/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final accounts = [
    TotpAccount(
      id: 'id-1',
      accountName: 'alice@example.com',
      issuer: 'Example',
      secret: 'JBSWY3DPEHPK3PXP',
      digits: 8,
      period: 60,
      algorithm: TotpAlgorithm.sha256,
      createdAt: DateTime.utc(2024, 1, 1),
    ),
  ];
  const password = 'correct horse battery';

  test('encrypt then decrypt round-trips accounts', () async {
    final backup = await BackupService.createEncryptedBackup(
      accounts: accounts,
      password: password,
    );
    final restored =
        await BackupService.restoreBackup(backupJson: backup, password: password);
    expect(restored, hasLength(1));
    expect(restored.single.secret, 'JBSWY3DPEHPK3PXP');
    expect(restored.single.algorithm, TotpAlgorithm.sha256);
    expect(restored.single.digits, 8);
    expect(restored.single.period, 60);
  });

  test('uses 32-byte salt, 12-byte nonce, 16-byte tag and hides plaintext',
      () async {
    final backup = await BackupService.createEncryptedBackup(
      accounts: accounts,
      password: password,
    );
    final map = jsonDecode(backup) as Map<String, dynamic>;
    expect(base64Decode(map['salt'] as String), hasLength(32));
    expect(base64Decode(map['nonce'] as String), hasLength(12));
    expect(base64Decode(map['mac'] as String), hasLength(16));
    expect(map['iterations'], 210000);
    expect(backup.contains('JBSWY3DPEHPK3PXP'), isFalse);
  });

  test('wrong password is rejected', () async {
    final backup = await BackupService.createEncryptedBackup(
      accounts: accounts,
      password: password,
    );
    expect(
      BackupService.restoreBackup(backupJson: backup, password: 'wrong password!'),
      throwsA(isA<BackupException>()),
    );
  });

  test('corrupted ciphertext is detected', () async {
    final backup = await BackupService.createEncryptedBackup(
      accounts: accounts,
      password: password,
    );
    final map = jsonDecode(backup) as Map<String, dynamic>;
    final ct = base64Decode(map['ciphertext'] as String);
    ct[0] ^= 0x01;
    map['ciphertext'] = base64Encode(ct);
    expect(
      BackupService.restoreBackup(backupJson: jsonEncode(map), password: password),
      throwsA(isA<BackupException>()),
    );
  });

  test('garbage input and short passwords are rejected', () async {
    expect(
      BackupService.restoreBackup(backupJson: 'not json', password: password),
      throwsA(isA<BackupException>()),
    );
    expect(
      BackupService.createEncryptedBackup(accounts: accounts, password: 'short'),
      throwsArgumentError,
    );
  });
}
