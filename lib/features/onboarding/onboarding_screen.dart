import 'package:flutter/material.dart';

import '../../core/widgets/service_icon.dart';
import '../../core/widgets/shield_lock_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinish});

  /// Called when the user taps "Get Started" or "Skip".
  final Future<void> Function(BuildContext context) onFinish;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const List<(String, String)> _copy = [
    (
      'Simple & Secure',
      'Get verification codes for your accounts. Authly keeps your data safe and private.',
    ),
    (
      'Scan & Add',
      'Scan QR codes or enter setup keys to add your accounts in seconds.',
    ),
    (
      'Get Your Codes',
      'Your 6-digit codes refresh every 30 seconds. Just copy and use them when you need.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index == _copy.length - 1) {
      await widget.onFinish(context);
    } else {
      await _pages.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = _index == _copy.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _copy.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Expanded(child: Center(child: _Illustration(page: i))),
                        Text(
                          _copy[i].$1,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _copy[i].$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 14.5,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _copy.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(last ? 'Get Started' : 'Next'),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: last
                  ? null
                  : TextButton(
                      onPressed: () => widget.onFinish(context),
                      child: const Text('Skip'),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget phoneContent;
    switch (page) {
      case 0:
        phoneContent = ShieldLockLogo(
          size: 76,
          shieldColor: scheme.primary,
          filled: true,
        );
      case 1:
        phoneContent = Icon(Icons.qr_code_2_rounded, size: 96, color: scheme.primary);
      default:
        phoneContent = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '123 456',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                value: 0.7,
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
                color: scheme.primary,
                backgroundColor: scheme.outlineVariant,
              ),
            ),
          ],
        );
    }

    Widget floating(Widget child, {double? left, double? right, double? top, double? bottom}) {
      return Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: 280,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 138,
            height: 220,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: scheme.primary, width: 4),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(child: phoneContent),
          ),
          if (page == 0) ...[
            floating(const ServiceIcon(issuer: 'Google', size: 44), left: 6, top: 70),
            floating(const ServiceIcon(issuer: 'Microsoft', size: 44), right: 4, top: 40),
            floating(const ServiceIcon(issuer: 'GitHub', size: 44), right: 10, bottom: 70),
          ],
          if (page == 1)
            floating(
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lock_rounded, color: Colors.white),
              ),
              left: 14,
              bottom: 60,
            ),
        ],
      ),
    );
  }
}
