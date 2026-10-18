import 'dart:convert';
import 'dart:typed_data';

import 'package:authly/features/authenticator/domain/models/totp_account.dart';
import 'package:authly/features/authenticator/domain/services/totp_service.dart';
import 'package:base32/base32.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // RFC 6238 Appendix B seeds (ASCII), Base32-encoded.
  final seeds = <TotpAlgorithm, String>{
    TotpAlgorithm.sha1:
        base32.encode(Uint8List.fromList(ascii.encode('12345678901234567890'))),
    TotpAlgorithm.sha256: base32.encode(
        Uint8List.fromList(ascii.encode('12345678901234567890123456789012'))),
    TotpAlgorithm.sha512: base32.encode(Uint8List.fromList(ascii.encode(
        '1234567890123456789012345678901234567890123456789012345678901234'))),
  };

  // time -> [sha1, sha256, sha512], 8 digits, 30s period.
  const vectors = <int, List<String>>{
    59: ['94287082', '46119246', '90693936'],
    1111111109: ['07081804', '68084774', '25091201'],
    1111111111: ['14050471', '67062674', '99943326'],
    1234567890: ['89005924', '91819424', '93441116'],
    2000000000: ['69279037', '90698825', '38618901'],
  };

  group('RFC 6238 test vectors', () {
    for (final entry in vectors.entries) {
      const algorithms = TotpAlgorithm.values;
      for (var i = 0; i < algorithms.length; i++) {
        final algo = algorithms[i];
        test('T=${entry.key} ${algo.name}', () {
          final account = TotpAccount(
            id: 'x',
            accountName: 'rfc',
            issuer: 'rfc',
            secret: seeds[algo]!,
            digits: 8,
            period: 30,
            algorithm: algo,
            createdAt: DateTime.utc(2024),
          );
          final code = TotpService.generateCode(
            account,
            time: DateTime.fromMillisecondsSinceEpoch(
              entry.key * 1000,
              isUtc: true,
            ),
          );
          expect(code, entry.value[i]);
        });
      }
    }

    test('6-digit code is the low 6 digits of the 8-digit RFC code', () {
      final code = TotpService.generateCodeForStep(
        secret: seeds[TotpAlgorithm.sha1]!,
        timeStep: 1,
        digits: 6,
      );
      expect(code, '287082');
    });
  });

  group('URI parsing', () {
    test('parses a full otpauth URI', () {
      final a = TotpService.parseUri(
        'otpauth://totp/GitHub:octocat?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&digits=8&period=60&algorithm=SHA256',
      );
      expect(a, isNotNull);
      expect(a!.issuer, 'GitHub');
      expect(a.accountName, 'octocat');
      expect(a.secret, 'JBSWY3DPEHPK3PXP');
      expect(a.digits, 8);
      expect(a.period, 60);
      expect(a.algorithm, TotpAlgorithm.sha256);
    });

    test('handles URL encoding and lower-case spaced secrets', () {
      final a = TotpService.parseUri(
        'otpauth://totp/Example%20Co%3Aalice%40example.com?secret=jbsw%20y3dp%20ehpk%203pxp',
      );
      expect(a, isNotNull);
      expect(a!.issuer, 'Example Co');
      expect(a.accountName, 'alice@example.com');
      expect(a.secret, 'JBSWY3DPEHPK3PXP');
    });

    test('rejects invalid Base32 secret', () {
      expect(
        TotpService.parseUri('otpauth://totp/A:b?secret=NOT-BASE32!1'),
        isNull,
      );
    });

    test('rejects wrong scheme, type, digits and algorithm', () {
      expect(TotpService.parseUri('https://example.com'), isNull);
      expect(TotpService.parseUri('otpauth://hotp/A:b?secret=JBSWY3DPEHPK3PXP'), isNull);
      expect(TotpService.parseUri('otpauth://totp/A:b?secret=JBSWY3DPEHPK3PXP&digits=7'), isNull);
      expect(TotpService.parseUri('otpauth://totp/A:b?secret=JBSWY3DPEHPK3PXP&algorithm=MD5'), isNull);
    });
  });

  group('Base32 validation', () {
    test('generateCodeForStep throws on invalid Base32', () {
      expect(
        () => TotpService.generateCodeForStep(secret: '1890!!', timeStep: 1),
        throwsFormatException,
      );
    });
  });

  test('period progress', () {
    final p = TotpService.getPeriodProgress(
      period: 30,
      time: DateTime.fromMillisecondsSinceEpoch(1600000010000),
    );
    expect(p.secondsRemaining, 20);
    expect(p.progress, closeTo(20 / 30, 0.001));
  });
}
