import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_mvp/services/download_cancel_token.dart';
import 'package:flutter_mvp/services/ocr/ocr_service.dart';
import 'package:flutter_mvp/services/ocr/text_cleanup.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';

class PdfOcrProgress {
  final int page;
  final int pageCount;

  const PdfOcrProgress({required this.page, required this.pageCount});
}

class PdfOcrService {
  /// OCRs a PDF by rendering each page to an image and running ML Kit text recognition.
  ///
  /// Yields [PdfOcrProgress] updates (1-based page numbers).
  Stream<PdfOcrProgress> ocrPdfWithProgress({
    required String pdfPath,
    required void Function(String partialText) onPageText,
    DownloadCancelToken? cancelToken,
    int dpi = 200,
  }) async* {
    final doc = await PdfDocument.openFile(pdfPath);
    final ocr = OcrService();
    final tmpDir = await getTemporaryDirectory();

    try {
      final pageCount = doc.pageCount;
      for (var pageNum = 1; pageNum <= pageCount; pageNum++) {
        if (cancelToken?.isCancelled == true) throw DownloadCancelled();

        final page = await doc.getPage(pageNum);
        try {
          final scale = dpi / 72.0;
          final fullWidth = (page.width * scale).toInt();
          final fullHeight = (page.height * scale).toInt();
          final pageImage = await page.render(
            x: 0,
            y: 0,
            width: fullWidth,
            height: fullHeight,
            fullWidth: page.width * scale,
            fullHeight: page.height * scale,
            backgroundFill: true,
          );

          try {
            final uiImage = await pageImage.createImageIfNotAvailable();
            final bytes = await uiImage.toByteData(format: ui.ImageByteFormat.png);
            if (bytes == null) throw StateError('Failed to encode page to PNG');

            final file = File('${tmpDir.path}/ocr_page_$pageNum.png');
            await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

            final text = await ocr.recognizeFilePath(file.path);
            onPageText(cleanOcrText(text));

            // Cleanup to save storage.
            try {
              await file.delete();
            } catch (_) {}
          } finally {
            pageImage.dispose();
          }
        } finally {
          // PdfPage has no dispose/close; document.dispose() owns lifecycle.
        }

        yield PdfOcrProgress(page: pageNum, pageCount: pageCount);
      }
    } finally {
      await ocr.close();
      await doc.dispose();
    }
  }
}

