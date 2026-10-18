import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Outcome of picking an image from the gallery and decoding a QR code in it.
class GalleryQrResult {
  const GalleryQrResult._({this.value, required this.cancelled});
  const GalleryQrResult.cancelled() : this._(cancelled: true);
  const GalleryQrResult.found(String value)
      : this._(value: value, cancelled: false);
  const GalleryQrResult.notFound() : this._(cancelled: false);

  final String? value;
  final bool cancelled;

  bool get found => value != null;
}

class QrGalleryPicker {
  QrGalleryPicker._();

  /// Lets the user pick an image and decodes the first QR code found in it.
  /// If [controller] is null a temporary one is created and disposed.
  static Future<GalleryQrResult> pickAndDecode({
    MobileScannerController? controller,
  }) async {
    final ownsController = controller == null;
    final scanner = controller ?? MobileScannerController(autoStart: false);
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.image);
      final files = picked?.files;
      if (files == null || files.isEmpty) {
        return const GalleryQrResult.cancelled();
      }
      final path = files.first.path;
      if (path == null) {
        return const GalleryQrResult.notFound();
      }
      final capture = await scanner.analyzeImage(path);
      if (capture == null) {
        return const GalleryQrResult.notFound();
      }
      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue;
        if (raw != null && raw.isNotEmpty) {
          return GalleryQrResult.found(raw);
        }
      }
      return const GalleryQrResult.notFound();
    } catch (_) {
      return const GalleryQrResult.notFound();
    } finally {
      if (ownsController) {
        await scanner.dispose();
      }
    }
  }
}
