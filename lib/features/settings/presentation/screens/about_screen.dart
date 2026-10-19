import 'package:flutter/material.dart';

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
            child: SizedBox(
              width: 86,
              height: 92,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.shield_rounded, size: 92, color: scheme.secondary),
                  const Icon(Icons.lock_rounded, size: 36, color: Colors.white),
                ],
              ),
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
