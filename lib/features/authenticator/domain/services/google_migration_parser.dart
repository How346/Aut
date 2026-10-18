import 'dart:convert';
import 'dart:typed_data';

import 'package:base32/base32.dart';
import 'package:uuid/uuid.dart';

import '../models/totp_account.dart';

/// Parses Google Authenticator "export accounts" QR codes
/// (otpauth-migration://offline?data=...).
class GoogleMigrationParser {
  GoogleMigrationParser._();

  static bool isMigrationUri(String raw) =>
      raw.trim().toLowerCase().startsWith('otpauth-migration://');

  /// Returns the TOTP accounts contained in the export.
  /// Throws [FormatException] if the data is invalid or has no TOTP entries.
  static List<TotpAccount> parse(String raw) {
    final uri = Uri.parse(raw.trim());
    final data = uri.queryParameters['data'];
    if (data == null || data.isEmpty) {
      throw const FormatException('Missing migration data');
    }
    final bytes = _decodeBase64(data);
    final reader = _ProtoReader(bytes);
    final accounts = <TotpAccount>[];
    while (reader.hasMore) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wire = tag & 7;
      if (field == 1 && wire == 2) {
        final account = _parseOtp(reader.readBytes());
        if (account != null) accounts.add(account);
      } else {
        reader.skip(wire);
      }
    }
    if (accounts.isEmpty) {
      throw const FormatException('No TOTP accounts found in this QR code');
    }
    return accounts;
  }

  static Uint8List _decodeBase64(String input) {
    var s = input.trim().replaceAll(' ', '+').replaceAll('-', '+').replaceAll('_', '/');
    s = s.replaceAll('=', '');
    final rem = s.length % 4;
    if (rem == 1) {
      throw const FormatException('Invalid migration data');
    }
    if (rem != 0) {
      s = s + '=' * (4 - rem);
    }
    return base64.decode(s);
  }

  static TotpAccount? _parseOtp(Uint8List message) {
    final reader = _ProtoReader(message);
    Uint8List secret = Uint8List(0);
    var name = '';
    var issuer = '';
    var algorithm = 1;
    var digits = 1;
    var type = 2;
    while (reader.hasMore) {
      final tag = reader.readVarint();
      final field = tag >> 3;
      final wire = tag & 7;
      if (field == 1 && wire == 2) {
        secret = reader.readBytes();
      } else if (field == 2 && wire == 2) {
        name = utf8.decode(reader.readBytes(), allowMalformed: true);
      } else if (field == 3 && wire == 2) {
        issuer = utf8.decode(reader.readBytes(), allowMalformed: true);
      } else if (field == 4 && wire == 0) {
        algorithm = reader.readVarint();
      } else if (field == 5 && wire == 0) {
        digits = reader.readVarint();
      } else if (field == 6 && wire == 0) {
        type = reader.readVarint();
      } else {
        reader.skip(wire);
      }
    }
    if (secret.isEmpty) return null;
    if (type == 1) return null; // HOTP is not supported.

    final TotpAlgorithm algo;
    switch (algorithm) {
      case 2:
        algo = TotpAlgorithm.sha256;
      case 3:
        algo = TotpAlgorithm.sha512;
      case 4:
        return null; // MD5 is not supported.
      default:
        algo = TotpAlgorithm.sha1;
    }

    var accountName = name.trim();
    var issuerName = issuer.trim();
    if (accountName.contains(':')) {
      final index = accountName.indexOf(':');
      final prefix = accountName.substring(0, index).trim();
      final rest = accountName.substring(index + 1).trim();
      if (issuerName.isEmpty) {
        issuerName = prefix;
        accountName = rest;
      } else if (prefix == issuerName) {
        accountName = rest;
      }
    }

    return TotpAccount(
      id: Uuid().v4(),
      accountName: accountName.isEmpty ? 'Account' : accountName,
      issuer: issuerName.isEmpty ? 'Authenticator' : issuerName,
      secret: base32.encode(secret).replaceAll('=', ''),
      digits: digits == 2 ? 8 : 6,
      period: 30,
      algorithm: algo,
      createdAt: DateTime.now(),
    );
  }
}

class _ProtoReader {
  _ProtoReader(this._bytes);

  final Uint8List _bytes;
  int _pos = 0;

  bool get hasMore => _pos < _bytes.length;

  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_pos >= _bytes.length) {
        throw const FormatException('Truncated migration data');
      }
      final byte = _bytes[_pos++];
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
      if (shift > 63) {
        throw const FormatException('Invalid varint in migration data');
      }
    }
  }

  Uint8List readBytes() {
    final length = readVarint();
    if (length < 0 || _pos + length > _bytes.length) {
      throw const FormatException('Truncated migration data');
    }
    final view = Uint8List.sublistView(_bytes, _pos, _pos + length);
    _pos += length;
    return view;
  }

  void skip(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
      case 1:
        _advance(8);
      case 2:
        readBytes();
      case 5:
        _advance(4);
      default:
        throw const FormatException('Unsupported migration data');
    }
  }

  void _advance(int count) {
    if (_pos + count > _bytes.length) {
      throw const FormatException('Truncated migration data');
    }
    _pos += count;
  }
}
