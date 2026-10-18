import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/qr_gallery_picker.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  bool _handled = false;
  bool _busy = false;

  @override
  void dispose() {
    _scanLine.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish(String value) async {
    if (_handled || !mounted) return;
    _handled = true;
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.pop(context, value);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _finish(raw);
        return;
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy || _handled) return;
    setState(() => _busy = true);
    final result = await QrGalleryPicker.pickAndDecode(controller: _controller);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.cancelled) return;
    final value = result.value;
    if (value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No QR code found in that image.')),
      );
      return;
    }
    await _finish(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(
          'Scan QR code',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final unavailable = state.torchState == TorchState.unavailable;
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: 'Toggle torch',
                icon: Icon(on ? Icons.flash_on_rounded : Icons.flash_off_rounded),
                onPressed: unavailable
                    ? null
                    : () async {
                        try {
                          await _controller.toggleTorch();
                        } catch (_) {}
                      },
              );
            },
          ),
          IconButton(
            tooltip: 'Switch camera',
            icon: const Icon(Icons.cameraswitch_rounded),
            onPressed: () async {
              try {
                await _controller.switchCamera();
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          IgnorePointer(
            child: CustomPaint(
              painter: _ScanOverlayPainter(progress: _scanLine),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Align the 2FA QR code inside the frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _pickFromGallery,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_rounded),
                      label: const Text('Choose from gallery'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  _ScanOverlayPainter({required this.progress}) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height) * 0.68;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.44),
      width: side,
      height: side,
    );
    const radius = 28.0;
    const arm = 36.0;

    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(radius)));
    canvas.drawPath(scrim, Paint()..color = const Color(0x99000000));

    final corner = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const r = Radius.circular(radius);
    final path = Path()
      ..moveTo(rect.left, rect.top + arm)
      ..lineTo(rect.left, rect.top + radius)
      ..arcToPoint(Offset(rect.left + radius, rect.top), radius: r)
      ..lineTo(rect.left + arm, rect.top)
      ..moveTo(rect.right - arm, rect.top)
      ..lineTo(rect.right - radius, rect.top)
      ..arcToPoint(Offset(rect.right, rect.top + radius), radius: r)
      ..lineTo(rect.right, rect.top + arm)
      ..moveTo(rect.right, rect.bottom - arm)
      ..lineTo(rect.right, rect.bottom - radius)
      ..arcToPoint(Offset(rect.right - radius, rect.bottom), radius: r)
      ..lineTo(rect.right - arm, rect.bottom)
      ..moveTo(rect.left + arm, rect.bottom)
      ..lineTo(rect.left + radius, rect.bottom)
      ..arcToPoint(Offset(rect.left, rect.bottom - radius), radius: r)
      ..lineTo(rect.left, rect.bottom - arm);
    canvas.drawPath(path, corner);

    final t = Curves.easeInOut.transform(progress.value);
    final y = rect.top + 24 + (rect.height - 48) * t;
    final start = Offset(rect.left + 24, y);
    final end = Offset(rect.right - 24, y);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = AppTheme.accent.withValues(alpha: 0.55)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = AppTheme.accent
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
