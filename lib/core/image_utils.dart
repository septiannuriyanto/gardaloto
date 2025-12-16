import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

/// Compresses the image at [inputPath] to be under [maxSizeInBytes].
/// Returns the path to the compressed image (which might be the same as inputPath if overwritten).
Future<String> compressImage({
  required String inputPath,
  int maxSizeInBytes = 150 * 1024, // 150KB
}) async {
  final file = File(inputPath);
  if (!file.existsSync()) return inputPath;

  int fileSize = await file.length();
  if (fileSize <= maxSizeInBytes) return inputPath;

  // Read image
  final bytes = await file.readAsBytes();
  img.Image? image = img.decodeImage(bytes);

  if (image == null) return inputPath; // Failed to decode

  // Resize if too big (e.g. > 1280px width) to help compression
  if (image.width > 1280) {
    image = img.copyResize(image, width: 1280);
  }

  // Compress loop
  int quality = 85;
  List<int> compressedBytes = [];

  do {
    compressedBytes = img.encodeJpg(image, quality: quality);
    if (compressedBytes.length <= maxSizeInBytes) break;
    quality -= 10;
  } while (quality > 10);

  // Write back to file (overwrite or new file)
  // For simplicity, let's overwrite or create a temp file.
  // Since we want to upload this, overwriting the watermarked file is fine as it's a copy anyway usually.
  // But to be safe, let's create a new file.
  final dir = p.dirname(inputPath);
  final base = p.basenameWithoutExtension(inputPath);
  final outPath = p.join(dir, '${base}_compressed.jpg');

  await File(outPath).writeAsBytes(compressedBytes);
  return outPath;
}

/// Adds a watermark to [inputPath] and writes the result to a new PNG file.
/// Returns the path to the new watermarked file.
Future<String> addWatermarkToImage({
  required String inputPath,
  required String unitCode,
  required String nrp,
  required String gps,
  required DateTime timestamp,
  String? suffix = '_wm',
}) async {
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    throw Exception('Input image not found: $inputPath');
  }

  final bytes = await inputFile.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final srcImage = frame.image;
  final width = srcImage.width.toDouble();
  final height = srcImage.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // 1. Draw original image
  canvas.drawImage(srcImage, ui.Offset.zero, ui.Paint());

  // configuration
  final bottomPadding = height * 0.05; // 5% padding
  final sidePadding = width * 0.04;

  // Font sizes
  final bigFontSize = (height * 0.05).clamp(32.0, 120.0); // Limit size
  final smallFontSize = bigFontSize * 0.4; // 40% of big font

  // 2. Draw Vignette (Gradient bottom)
  final gradientHeight = height * 0.3; // Cover bottom 30%
  final gradientRect = ui.Rect.fromLTWH(
    0,
    height - gradientHeight,
    width,
    gradientHeight,
  );
  final gradientPaint =
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(0, height - gradientHeight),
          ui.Offset(0, height),
          [Colors.transparent, Colors.black.withOpacity(0.9)],
        );
  canvas.drawRect(gradientRect, gradientPaint);

  // 3. Prepare Text Painters

  // Helper to build paragraph
  ui.Paragraph buildText(String text, double fontSize, {bool isBold = false}) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.left,
        fontSize: fontSize,
        fontWeight: isBold ? ui.FontWeight.bold : ui.FontWeight.normal,
        maxLines: 1,
        ellipsis: '...',
      ),
    );
    builder.pushStyle(ui.TextStyle(color: Colors.white));
    builder.addText(text);
    return builder.build();
  }

  // Unit Code (Left Column)
  final unitPara = buildText(unitCode, bigFontSize, isBold: true);
  unitPara.layout(
    ui.ParagraphConstraints(width: width * 0.5),
  ); // Take half width

  // Details (Right Column)
  final timePara = buildText(
    'TIME: ${timestamp.toString().split('.')[0]}',
    smallFontSize,
  );
  timePara.layout(ui.ParagraphConstraints(width: width * 0.4));

  final gpsPara = buildText('GPS: $gps', smallFontSize);
  gpsPara.layout(ui.ParagraphConstraints(width: width * 0.4));

  final nrpPara = buildText('NRP: $nrp', smallFontSize);
  nrpPara.layout(ui.ParagraphConstraints(width: width * 0.4));

  // 4. Draw Layout
  // Calculate total height of details stack
  final detailsHeight =
      timePara.height +
      gpsPara.height +
      nrpPara.height +
      (smallFontSize * 0.2 * 2);
  // Anchor to bottom
  final bottomAnchor = height - bottomPadding;

  // Draw Unit Code (Bottom Left)
  // Align baseline of unit code roughly with bottom of details? Or just bottom align?
  // Let's bottom align the block.
  canvas.drawParagraph(
    unitPara,
    ui.Offset(sidePadding, bottomAnchor - unitPara.height),
  );

  // Draw Vertical Divider
  final dividerX = sidePadding + unitPara.maxIntrinsicWidth + (width * 0.04);
  final dividerHeight =
      detailsHeight > unitPara.height ? detailsHeight : unitPara.height;
  final dividerPaint = ui.Paint()..color = Colors.white.withOpacity(0.7);
  // canvas.drawRect(
  //   ui.Rect.fromLTWH(dividerX, bottomAnchor - dividerHeight, width * 0.002, dividerHeight),
  //   dividerPaint,
  // );
  // Actually, let's position divider after the text
  canvas.drawRect(
    ui.Rect.fromLTWH(
      dividerX,
      bottomAnchor - dividerHeight,
      width * 0.003,
      dividerHeight,
    ),
    dividerPaint,
  );

  // Draw Details (Bottom Right)
  final detailsX = dividerX + (width * 0.04);
  var currentY = bottomAnchor - detailsHeight;

  canvas.drawParagraph(timePara, ui.Offset(detailsX, currentY));
  currentY += timePara.height + (smallFontSize * 0.1);

  canvas.drawParagraph(gpsPara, ui.Offset(detailsX, currentY));
  currentY += gpsPara.height + (smallFontSize * 0.1);

  canvas.drawParagraph(nrpPara, ui.Offset(detailsX, currentY));

  // 5. Save
  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) throw Exception('Failed to encode image');

  final outBytes = byteData.buffer.asUint8List();
  final dir = p.dirname(inputPath);
  final base = p.basenameWithoutExtension(inputPath);
  final outPath = p.join(dir, '$base$suffix.png');

  final outFile = File(outPath);
  await outFile.writeAsBytes(outBytes);

  return outPath;
}
