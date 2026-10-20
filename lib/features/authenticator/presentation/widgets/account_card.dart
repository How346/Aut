import 'package:flutter/material.dart';

import '../../../../core/widgets/animated_code.dart';
import '../../../../core/widgets/countdown_ring.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/service_icon.dart';
import '../../domain/models/totp_account.dart';
import '../../domain/services/totp_service.dart';
import '../code_clipboard.dart';

/// Home-list tile: service icon, name, e-mail, live code and countdown.
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.onTap,
    required this.onLongPress,
    this.masked = false,
    this.showEye = false,
    this.onToggleReveal,
  });

  final TotpAccount account;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool masked;
  final bool showEye;
  final VoidCallback? onToggleReveal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = TotpService.getPeriodProgress(period: account.period);
    final urgent = info.secondsRemaining <= 5;

    String? code;
    try {
      code = TotpService.generateCode(account);
    } catch (_) {
      code = null;
    }

    return PressScale(
      child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              ServiceIcon(issuer: account.issuer, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.issuer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (account.accountName.isNotEmpty)
                      Text(
                        account.accountName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (code == null)
                      Text(
                        'Invalid key',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.error,
                        ),
                      )
                    else
                      Row(
                        children: [
                          AnimatedCode(
                            code: CodeClipboard.group(code),
                            fontSize: 21,
                            masked: masked,
                            color: urgent ? scheme.error : scheme.primary,
                          ),
                          if (showEye)
                            InkResponse(
                              onTap: onToggleReveal,
                              radius: 20,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  masked
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              CountdownRing(
                progress: info.progress,
                seconds: info.secondsRemaining,
                size: 34,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
