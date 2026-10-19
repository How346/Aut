import 'package:flutter/material.dart';

import 'app_lock_controller.dart';
import 'presentation/pin_flow_screen.dart';

/// Shared flows for the App Lock / PIN / biometric settings.
class LockActions {
  LockActions._();

  static Future<void> toggleAppLock(
    BuildContext context,
    AppLockController controller,
    bool value,
  ) async {
    if (value) {
      if (!controller.hasPin) {
        final created = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PinFlowScreen(
              controller: controller,
              mode: PinFlowMode.create,
            ),
          ),
        );
        if (created != true) return;
      }
      await controller.setEnabled(true);
    } else {
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PinFlowScreen(
            controller: controller,
            mode: PinFlowMode.verify,
          ),
        ),
      );
      if (verified == true) {
        await controller.setEnabled(false);
        await controller.setBiometricEnabled(false);
      }
    }
  }

  static Future<void> changePin(
    BuildContext context,
    AppLockController controller,
  ) async {
    final mode = controller.hasPin ? PinFlowMode.change : PinFlowMode.create;
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PinFlowScreen(controller: controller, mode: mode),
      ),
    );
    if (done == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN updated.')),
      );
    }
  }

  static Future<void> toggleBiometric(
    BuildContext context,
    AppLockController controller,
    bool value,
  ) async {
    final ok = await controller.setBiometricEnabled(value);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrics are unavailable or were not confirmed.'),
        ),
      );
    }
  }

  static String autoLockLabel(int minutes) {
    if (minutes == 0) return 'Lock app immediately';
    return 'Lock app after $minutes minute${minutes == 1 ? '' : 's'}';
  }

  static Future<void> pickAutoLock(
    BuildContext context,
    AppLockController controller,
  ) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final minutes in AppLockController.autoLockOptions)
              ListTile(
                title: Text(minutes == 0
                    ? 'Immediately'
                    : '$minutes minute${minutes == 1 ? '' : 's'}'),
                trailing: minutes == controller.autoLockMinutes
                    ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, minutes),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await controller.setAutoLockMinutes(selected);
    }
  }
}
