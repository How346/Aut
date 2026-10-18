import 'dart:math';
import 'dart:typed_data';
import 'package:base32/base32.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../models/totp_account.dart';

class TotpService {
  /// Generates the current TOTP code for an account.
  static String generateCode(TotpAccount account, {DateTime? time}) {
    if (account.period <= 0) {
      throw ArgumentError.value(account.period, 'period', 'Must be positive');
    }
    final now = time ?? DateTime.now();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    if (epochSeconds < 0) {
      throw ArgumentError.value(now, 'time', 'Must be on or after Unix epoch');
    }
    final timeStep = epochSeconds ~/ account.period;
    return generateCodeForStep(
      secret: account.secret,
      timeStep: timeStep,
      digits: account.digits,
      algorithm: account.algorithm,
    );
  }

  /// Calculates seconds remaining in the current period and the 0.0 - 1.0 progress fraction.
  static ({int secondsRemaining, double progress}) getPeriodProgress({
    int period = 30,
    DateTime? time,
  }) {
    if (period <= 0) {
      throw ArgumentError.value(period, 'period', 'Must be positive');
    }
    final now = time ?? DateTime.now();
    final epochSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final elapsed = epochSeconds % period;
    final remaining = period - elapsed;
    final progress = remaining / period;
    return (secondsRemaining: remaining, progress: progress);
  }

  /// Core RFC 6238 / RFC 4226 computation
  static String generateCodeForStep({
    required String secret,
    required int timeStep,
    int digits = 6,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
  }) {
    if (digits != 6 && digits != 8) {
      throw ArgumentError.value(digits, 'digits', 'Must be 6 or 8');
    }
    if (timeStep < 0) {
      throw ArgumentError.value(timeStep, 'timeStep', 'Must not be negative');
    }
    final sanitizedSecret = normalizeSecret(secret);
    if (!RegExp(r'^[A-Z2-7]+={0,6}$').hasMatch(sanitizedSecret)) {
      throw const FormatException('Secret must be valid Base32');
    }
    final keyBytes = base32.decode(_pad(sanitizedSecret));
    if (keyBytes.isEmpty) {
      throw const FormatException('Secret must not be empty');
    }

    final message = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      message[i] = (timeStep >> ((7 - i) * 8)) & 0xFF;
    }

    Hmac hmac;
    switch (algorithm) {
      case TotpAlgorithm.sha256:
        hmac = Hmac(sha256, keyBytes);
        break;
      case TotpAlgorithm.sha512:
        hmac = Hmac(sha512, keyBytes);
        break;
      case TotpAlgorithm.sha1:
        hmac = Hmac(sha1, keyBytes);
        break;
    }

    final hash = hmac.convert(message).bytes;

    // Dynamic truncation (RFC 4226 section 5.4)
    final offset = hash[hash.length - 1] & 0x0F;
    final binary = ((hash[offset] & 0x7F) << 24) |
        ((hash[offset + 1] & 0xFF) << 16) |
        ((hash[offset + 2] & 0xFF) << 8) |
        (hash[offset + 3] & 0xFF);

    final modulo = pow(10, digits).toInt();
    final codeInt = binary % modulo;

    return codeInt.toString().padLeft(digits, '0');
  }

  /// Strips whitespace and dashes and upper-cases a Base32 secret.
  static String normalizeSecret(String secret) =>
      secret.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

  static String _pad(String s) {
    final stripped = s.replaceAll('=', '');
    final rem = stripped.length % 8;
    return rem == 0 ? stripped : stripped + '=' * (8 - rem);
  }

  /// Parses otpauth://totp/ URI according to standard spec
  static TotpAccount? parseUri(String uriString) {
    try {
      final uri = Uri.parse(uriString.trim());
      if (uri.scheme.toLowerCase() != 'otpauth') return null;
      if (uri.host.toLowerCase() != 'totp') return null;

      final path = Uri.decodeComponent(uri.path).replaceFirst(RegExp(r'^/'), '');
      if (path.isEmpty) return null;
      String issuerFromPath = '';
      String accountName = path;

      if (path.contains(':')) {
        final parts = path.split(':');
        issuerFromPath = parts[0].trim();
        accountName = parts.sublist(1).join(':').trim();
      }

      final query = uri.queryParameters;
      final secret = query['secret'];
      if (secret == null || secret.isEmpty) return null;

      final issuer = (query['issuer'] ?? issuerFromPath).trim();
      final digits = int.tryParse(query['digits'] ?? '') ?? 6;
      final period = int.tryParse(query['period'] ?? '') ?? 30;
      if (digits != 6 && digits != 8) return null;
      if (period <= 0) return null;

      final algorithm = switch ((query['algorithm'] ?? 'SHA1').toUpperCase()) {
        'SHA1' => TotpAlgorithm.sha1,
        'SHA256' => TotpAlgorithm.sha256,
        'SHA512' => TotpAlgorithm.sha512,
        _ => null,
      };
      if (algorithm == null) return null;
      final normalizedSecret = normalizeSecret(secret);
      generateCodeForStep(secret: normalizedSecret, timeStep: 0, digits: digits, algorithm: algorithm);

      return TotpAccount(
        id: Uuid().v4(),
        accountName: accountName.trim(),
        issuer: issuer.isNotEmpty ? issuer : 'Authenticator',
        secret: normalizedSecret,
        digits: digits,
        period: period,
        algorithm: algorithm,
        createdAt: DateTime.now(),
      );
    } on Exception {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}
