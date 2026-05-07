import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Service for exporting the KTA digital card as PNG image or PDF document.
///
/// Uses [RepaintBoundary] capture for high-resolution PNG output, and the
/// `pdf` package to generate print-ready PDFs at standard credit card
/// dimensions (85.6mm x 53.98mm) centered on an A4 page.
class KtaExportService {
  KtaExportService._();

  // ---------------------------------------------------------------------------
  // PNG Capture
  // ---------------------------------------------------------------------------

  /// Captures a widget wrapped in a [RepaintBoundary] to a PNG image.
  ///
  /// [key] is the [GlobalKey] attached to the [RepaintBoundary].
  /// [pixelRatio] defaults to 3.0 for high-resolution output suitable for
  /// printing or sharing on high-DPI screens.
  ///
  /// Returns `null` when running on web or if the boundary cannot be resolved.
  static Future<Uint8List?> captureCardAsPng(
    GlobalKey key, {
    double pixelRatio = 3.0,
  }) async {
    // RepaintBoundary capture relies on dart:ui which is not available on web.
    if (kIsWeb) return null;

    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('KtaExportService.captureCardAsPng error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Share as PNG
  // ---------------------------------------------------------------------------

  /// Shares the captured PNG via the system share sheet.
  ///
  /// The file is written to a temporary directory with a timestamped filename
  /// so that multiple exports don't overwrite each other.
  static Future<void> shareAsPng(Uint8List bytes, String memberName) async {
    if (kIsWeb) return;

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedName = _sanitizeFilename(memberName);
    final filePath =
        '${tempDir.path}/KTA_Daddies_${sanitizedName}_$timestamp.png';

    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'KTA Digital Daddies - $memberName',
    );
  }

  // ---------------------------------------------------------------------------
  // Share as PDF
  // ---------------------------------------------------------------------------

  /// Creates an A4 PDF with the KTA card image centered at standard
  /// credit-card dimensions (85.6 mm x 53.98 mm) and shares it via the
  /// system share sheet.
  static Future<void> shareAsPdf(Uint8List pngBytes, String memberName) async {
    if (kIsWeb) return;

    // Standard credit card dimensions in millimeters.
    const cardWidthMm = 85.6;
    const cardHeightMm = 53.98;

    // Convert mm to PDF points (1 mm = 72 / 25.4 points).
    final cardWidthPt = cardWidthMm * PdfPageFormat.mm;
    final cardHeightPt = cardHeightMm * PdfPageFormat.mm;

    final pdf = pw.Document(
      title: 'KTA Daddies - $memberName',
      author: 'Daddies Padel Community',
    );

    final cardImage = pw.MemoryImage(pngBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.SizedBox(
              width: cardWidthPt,
              height: cardHeightPt,
              child: pw.Image(cardImage, fit: pw.BoxFit.contain),
            ),
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedName = _sanitizeFilename(memberName);
    final filePath =
        '${tempDir.path}/KTA_Daddies_${sanitizedName}_$timestamp.pdf';

    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'KTA Digital Daddies - $memberName',
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Removes characters that are unsafe for filenames.
  static String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(RegExp(r'\s+'), '_');
  }
}
