import 'package:flutter/material.dart';

import '../../../../core/widgets/shield_lock_logo.dart';
import '../widgets/settings_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SizedBox(height: 16),
          Center(
            child: ShieldLockLogo(
              size: 84,
              shieldColor: scheme.secondary,
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Authly',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Your Codes. Your Security.',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SettingsGroup(
            children: [
              SettingsRow(
                icon: Icons.storage_outlined,
                title: 'Local Storage',
                subtitle: 'Your data stays on your device',
              ),
              SettingsRow(
                icon: Icons.wifi_off_outlined,
                title: 'No Internet Required',
                subtitle: 'Works offline',
              ),
              SettingsRow(
                icon: Icons.verified_user_outlined,
                title: 'Secure & Private',
                subtitle: 'Your privacy matters',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
