import 'dart:convert';
import 'dart:typed_data';

import 'package:authly/features/authenticator/domain/models/totp_account.dart';
import 'package:authly/features/authenticator/domain/services/google_migration_parser.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _varint(int value) {
  final out = <int>[];
  var v = value;
  while (v > 0x7F) {
    out.add((v & 0x7F) | 0x80);
    v >>= 7;
  }
  out.add(v);
  return out;
}

List<int> _bytesField(int number, List<int> data) =>
    [..._varint((number << 3) | 2), ..._varint(data.length), ...data];

List<int> _varintField(int number, int value) =>
    [..._varint(number << 3), ..._varint(value)];

String _uriFor(List<List<int>> entries) {
  final payload = <int>[
    for (final entry in entries) ..._bytesField(1, entry),
    ..._varintField(2, 1),
    ..._varintField(3, 1),
  ];
  final data = Uri.encodeComponent(base64Encode(Uint8List.fromList(payload)));
  return 'otpauth-migration://offline?data=$data';
}

List<int> _otp({
  required List<int> secret,
  required String name,
  required String issuer,
  int algorithm = 1,
  int digits = 1,
  int type = 2,
}) =>
    [
      ..._bytesField(1, secret),
      ..._bytesField(2, utf8.encode(name)),
      ..._bytesField(3, utf8.encode(issuer)),
      ..._varintField(4, algorithm),
      ..._varintField(5, digits),
      ..._varintField(6, type),
    ];

void main() {
  final secret = ascii.encode('12345678901234567890');

  test('parses a TOTP entry from a Google Authenticator export', () {
    final uri = _uriFor([
      _otp(secret: secret, name: 'alice@example.com', issuer: 'Example'),
    ]);
    expect(GoogleMigrationParser.isMigrationUri(uri), isTrue);
    final accounts = GoogleMigrationParser.parse(uri);
    expect(accounts, hasLength(1));
    expect(accounts.single.issuer, 'Example');
    expect(accounts.single.accountName, 'alice@example.com');
    expect(accounts.single.secret, 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    expect(accounts.single.digits, 6);
    expect(accounts.single.algorithm, TotpAlgorithm.sha1);
  });

  test('maps algorithm and digits and splits "Issuer:name" labels', () {
    final uri = _uriFor([
      _otp(
        secret: secret,
        name: 'GitHub:octocat',
        issuer: '',
        algorithm: 2,
        digits: 2,
      ),
    ]);
    final account = GoogleMigrationParser.parse(uri).single;
    expect(account.issuer, 'GitHub');
    expect(account.accountName, 'octocat');
    expect(account.algorithm, TotpAlgorithm.sha256);
    expect(account.digits, 8);
  });

  test('skips HOTP entries and rejects exports without TOTP accounts', () {
    final uri = _uriFor([
      _otp(secret: secret, name: 'a', issuer: 'b', type: 1),
    ]);
    expect(() => GoogleMigrationParser.parse(uri), throwsFormatException);
  });

  test('rejects missing or truncated data', () {
    expect(
      () => GoogleMigrationParser.parse('otpauth-migration://offline'),
      throwsFormatException,
    );
    expect(
      () => GoogleMigrationParser.parse(
        'otpauth-migration://offline?data=${Uri.encodeComponent(base64Encode([10, 50, 1]))}',
      ),
      throwsFormatException,
    );
  });
}
