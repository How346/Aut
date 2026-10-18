import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../data/qr_gallery_picker.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;
  bool _busy = false;

  @override
  void dispose() {
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan QR code', style: TextStyle(color: Colors.white)),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final unavailable = state.torchState == TorchState.unavailable;
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: 'Torch',
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
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
            icon: const Icon(Icons.cameraswitch),
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
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
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
                    const Text(
                      'Point the camera at the QR code',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
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
