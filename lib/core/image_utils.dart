import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img_lib;

/// Compresses the image at [inputPath] to be under [maxSizeInBytes].
/// Returns the path to the compressed image (which might be the same as inputPath if overwritten).

/// Adds a watermark to [inputPath] and writes the result to a new PNG file.
/// Returns the path to the new watermarked file.
///
/// [targetWidth] allows resizing the image during decoding. Default is 1280.
Future<String> addWatermarkToImage({
  required String inputPath,
  required String unitCode,
  required String nrp,
  required String gps,
  required DateTime timestamp,
  String? suffix = '_wm',
  int targetWidth = 1280,
  int maxSizeBytes = 150 * 1024, // 150KB
}) async {
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    throw Exception('Input image not found: $inputPath');
  }

  // Optimize: Use `flutter_image_compress` early if input is HEIC or huge?
  // But we need to watermark first.

  final bytes = await inputFile.readAsBytes();

  // Use pure dart decoding via 'image' package? NO, typical Flutter way is simpler for drawing.
  // We use ui.instantiateImageCodec.

  final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
  final frame = await codec.getNextFrame();
  final srcImage = frame.image;
  final width = srcImage.width.toDouble();
  final height = srcImage.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // 1. Draw original image
  canvas.drawImage(srcImage, ui.Offset.zero, ui.Paint());

  // Configuration - using WIDTH percentages
  final bottomPadding = height * 0.02;
  final sidePadding = width * 0.04;

  final bigFontSize = width * 0.06;
  final smallFontSize = width * 0.025;
  final logoSize = width * 0.08;

  // 2. Draw Vignette (Gradient bottom)
  final gradientHeight = height * 0.25;
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
          [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
        );
  canvas.drawRect(gradientRect, gradientPaint);

  // 3. Prepare Text Painters
  ui.Paragraph buildText(
    String text,
    double fontSize, {
    bool isBold = false,
    Color? titleColor,
    bool hasShadow = false,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: ui.TextAlign.left,
        fontSize: fontSize,
        fontWeight: isBold ? ui.FontWeight.bold : ui.FontWeight.normal,
        maxLines: 1,
        ellipsis: '...',
      ),
    );
    if (hasShadow) {
      builder.pushStyle(
        ui.TextStyle(
          color: titleColor ?? Colors.white,
          shadows: [
            ui.Shadow(
              offset: const ui.Offset(2, 2),
              blurRadius: 4.0,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ],
        ),
      );
    } else {
      builder.pushStyle(ui.TextStyle(color: titleColor ?? Colors.white));
    }

    builder.addText(text);
    return builder.build();
  }

  // Unit Code (Left Column)
  final unitPara = buildText(
    unitCode,
    bigFontSize,
    isBold: true,
    titleColor: Colors.amber,
  );
  unitPara.layout(ui.ParagraphConstraints(width: width * 0.45));

  // Details (Right Column)
  final timePara = buildText(
    'TIME: ${timestamp.toString().split('.')[0]}',
    smallFontSize,
  );
  timePara.layout(ui.ParagraphConstraints(width: width * 0.45));

  final gpsPara = buildText('GPS: $gps', smallFontSize);
  gpsPara.layout(ui.ParagraphConstraints(width: width * 0.45));

  final nrpPara = buildText('NRP: $nrp', smallFontSize);
  nrpPara.layout(ui.ParagraphConstraints(width: width * 0.45));

  // 4. Draw Layout (Bottom)

  // Calculate heights
  final detailsTotalHeight =
      timePara.height +
      gpsPara.height +
      nrpPara.height +
      (smallFontSize * 0.2 * 2); // Spacing

  final contentBottomY = height - bottomPadding;
  final unitY = contentBottomY - unitPara.height;

  final dividerHeight =
      detailsTotalHeight > unitPara.height
          ? detailsTotalHeight
          : unitPara.height;

  // Draw Unit Code
  canvas.drawParagraph(unitPara, ui.Offset(sidePadding, unitY));

  // Draw Vertical Divider
  final dividerX = sidePadding + unitPara.maxIntrinsicWidth + (width * 0.03);
  final dividerPaint = ui.Paint()..color = Colors.white.withValues(alpha: 0.7);

  canvas.drawRect(
    ui.Rect.fromLTWH(
      dividerX,
      contentBottomY - dividerHeight,
      width * 0.002,
      dividerHeight,
    ),
    dividerPaint,
  );

  // Draw Details
  final detailsX = dividerX + (width * 0.03);
  var currentY = contentBottomY - detailsTotalHeight;

  canvas.drawParagraph(timePara, ui.Offset(detailsX, currentY));
  currentY += timePara.height + (smallFontSize * 0.1);

  canvas.drawParagraph(gpsPara, ui.Offset(detailsX, currentY));
  currentY += gpsPara.height + (smallFontSize * 0.1);

  canvas.drawParagraph(nrpPara, ui.Offset(detailsX, currentY));

  // 5. Draw "Garda LOTO" Branding & Logo (Top Right)
  try {
    final logoBytes = await rootBundle.load('assets/logo.png');
    final logoCodec = await ui.instantiateImageCodec(
      logoBytes.buffer.asUint8List(),
    );
    final logoFrame = await logoCodec.getNextFrame();
    final logoImage = logoFrame.image;

    final logoAspectRatio = logoImage.width / logoImage.height;
    final logoDrawWidth = logoSize;
    final logoDrawHeight = logoSize / logoAspectRatio;

    final brandFontSize = smallFontSize * 1.0;
    final brandPara = buildText(
      "Garda LOTO",
      brandFontSize,
      isBold: false,
      hasShadow: true,
    );
    brandPara.layout(ui.ParagraphConstraints(width: width * 0.3));

    final topPadding = height * 0.03;
    final rightPadding = width * 0.04;

    final logoX = width - rightPadding - logoDrawWidth;
    final logoY = topPadding;

    final textX = logoX - brandPara.maxIntrinsicWidth - (width * 0.015);
    final textY = logoY + (logoDrawHeight - brandPara.height) / 2;

    canvas.drawParagraph(brandPara, ui.Offset(textX, textY));

    paintImage(
      canvas: canvas,
      rect: Rect.fromLTWH(logoX, logoY, logoDrawWidth, logoDrawHeight),
      image: logoImage,
      fit: BoxFit.contain,
    );
  } catch (e) {
    print('Error loading/drawing logo: $e');
  }

  // 6. Save
  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());

  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) throw Exception('Failed to encode image');

  final pngBytes = byteData.buffer.asUint8List();

  final dir = p.dirname(inputPath);
  final base = p.basenameWithoutExtension(inputPath);
  final outPath = p.join(dir, '$base$suffix.jpg');

  int quality = 85;
  List<int> resultBytes = [];

  try {
    // Attempt fast native compression
    var compressed = await FlutterImageCompress.compressWithList(
      pngBytes,
      minHeight: height.toInt(),
      minWidth: width.toInt(),
      quality: quality,
      format: CompressFormat.jpeg,
    );
    while (compressed.length > maxSizeBytes && quality > 10) {
      quality -= 10;
      print(
        '⚠️ Image size ${compressed.length} > $maxSizeBytes. Reducing quality to $quality...',
      );
      compressed = await FlutterImageCompress.compressWithList(
        pngBytes,
        minHeight: height.toInt(),
        minWidth: width.toInt(),
        quality: quality,
        format: CompressFormat.jpeg,
      );
    }
    resultBytes = compressed;
    print('✅ Native compression success.');
  } catch (e) {
    print('⚠️ Native compression failed ($e). Using Pure Dart fallback...');
    // FALLBACK: Pure Dart "image" package
    // 1. Decode PNG (since we have pngBytes)
    final decoded = img_lib.decodePng(pngBytes);
    if (decoded == null) throw Exception('Fallback: Failed to decode PNG data');

    // 2. Encode to JPG with quality loop
    var jpgBytes = img_lib.encodeJpg(decoded, quality: quality);

    while (jpgBytes.length > maxSizeBytes && quality > 10) {
      quality -= 10;
      print(
        '⚠️ [Fallback] Image size ${jpgBytes.length} > $maxSizeBytes. Reducing quality to $quality...',
      );
      jpgBytes = img_lib.encodeJpg(decoded, quality: quality);
    }
    resultBytes = jpgBytes;
    print('✅ Fallback compression success.');
  }

  final outFile = File(outPath);
  await outFile.writeAsBytes(resultBytes);

  return outPath;
}
