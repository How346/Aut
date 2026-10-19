import 'package:flutter/material.dart';

import '../../../../core/widgets/countdown_ring.dart';
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
  });

  final TotpAccount account;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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

    return Card(
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
                    Text(
                      code == null ? 'Invalid key' : CodeClipboard.group(code),
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: code == null
                            ? scheme.error
                            : (urgent ? scheme.error : scheme.primary),
                      ),
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
    );
  }
}
