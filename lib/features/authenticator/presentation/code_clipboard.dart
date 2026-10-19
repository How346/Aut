import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/settings/app_settings.dart';
import '../domain/models/totp_account.dart';
import '../domain/services/totp_service.dart';

/// Copies a code and (optionally) clears the clipboard 30 s later.
class CodeClipboard {
  CodeClipboard._();

  static Timer? _timer;

  static String group(String code) {
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    if (code.length == 8) return '${code.substring(0, 4)} ${code.substring(4)}';
    return code;
  }

  static Future<void> copy(
    BuildContext context,
    TotpAccount account,
    AppSettings settings,
  ) async {
    final String code;
    try {
      code = TotpService.generateCode(account);
    } catch (_) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    await HapticFeedback.lightImpact();
    _timer?.cancel();
    if (settings.clipboardClear) {
      _timer = Timer(const Duration(seconds: 30), () async {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text == code) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      });
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Code copied for ${account.issuer}'),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
