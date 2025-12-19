import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;


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
}) async {
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    throw Exception('Input image not found: $inputPath');
  }

  final bytes = await inputFile.readAsBytes();
  // Native decoding + resizing in one step. Much faster than 'image' package.
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
  final frame = await codec.getNextFrame();
  final srcImage = frame.image;
  final width = srcImage.width.toDouble();
  final height = srcImage.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  // 1. Draw original image
  canvas.drawImage(srcImage, ui.Offset.zero, ui.Paint());

  // Configuration - using WIDTH percentages for consistency across aspect ratios
  final bottomPadding = height * 0.02; 
  final sidePadding = width * 0.04;

  // Font sizes: Proportional to width
  // Example: On 1080px width, bigFontSize ~ 54px.
  final bigFontSize = width * 0.06; 
  final smallFontSize = width * 0.025;
  final logoSize = width * 0.08; // Logo width approx same as big font height + bit more

  // 2. Draw Vignette (Gradient bottom)
  final gradientHeight = height * 0.25; // Cover bottom 25%
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

  // Helper to build paragraph
  ui.Paragraph buildText(String text, double fontSize, {bool isBold = false, Color? titleColor, bool hasShadow = false}) {
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
       builder.pushStyle(ui.TextStyle(
          color: titleColor ?? Colors.white,
          shadows: [
             ui.Shadow(
               offset: const ui.Offset(2, 2),
               blurRadius: 4.0,
               color: Colors.black.withValues(alpha: 0.5),
             ),
          ],
       ));
    } else {
        builder.pushStyle(ui.TextStyle(color: titleColor ?? Colors.white));
    }
    
    builder.addText(text);
    return builder.build();
  }

  // Unit Code (Left Column)
  final unitPara = buildText(unitCode, bigFontSize, isBold: true, titleColor: Colors.amber);
  unitPara.layout(
    ui.ParagraphConstraints(width: width * 0.45),
  ); 

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
  
  // Anchor y for bottom content
  final contentBottomY = height - bottomPadding;
  
  // Unit Code Y
  final unitY = contentBottomY - unitPara.height;
  
  // Divider Calculation
  // We want the divider to be as tall as the tallest column
  final dividerHeight = detailsTotalHeight > unitPara.height ? detailsTotalHeight : unitPara.height;
  
  // Draw Unit Code
  canvas.drawParagraph(
    unitPara,
    ui.Offset(sidePadding, unitY),
  );

  // Draw Vertical Divider
  final dividerX = sidePadding + unitPara.maxIntrinsicWidth + (width * 0.03);
  final dividerPaint = ui.Paint()..color = Colors.white.withValues(alpha: 0.7);
  
  // Align divider bottom with content bottom
  canvas.drawRect(
    ui.Rect.fromLTWH(
      dividerX,
      contentBottomY - dividerHeight,
      width * 0.002, // Thin line relative to width
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
  
  // Load Logo
  try {
    final logoBytes = await rootBundle.load('assets/logo.png');
    final logoCodec = await ui.instantiateImageCodec(logoBytes.buffer.asUint8List());
    final logoFrame = await logoCodec.getNextFrame();
    final logoImage = logoFrame.image;
    
    // Calculate logo dimensions to maintain aspect ratio
    final logoAspectRatio = logoImage.width / logoImage.height;
    final logoDrawWidth = logoSize;
    final logoDrawHeight = logoSize / logoAspectRatio;

    // "Garda LOTO" Text
    final brandFontSize = smallFontSize * 1.0; 
    final brandPara = buildText("Garda LOTO", brandFontSize, isBold: false, hasShadow: true);
    brandPara.layout(ui.ParagraphConstraints(width: width * 0.3));
    
    final topPadding = height * 0.03;
    final rightPadding = width * 0.04;
    
    // Draw Logo (Top Right most)
    final logoX = width - rightPadding - logoDrawWidth;
    final logoY = topPadding;
    
    // Draw Text (Left of Logo)
    final textX = logoX - brandPara.maxIntrinsicWidth - (width * 0.015);
    // Center text vertically relative to logo
    final textY = logoY + (logoDrawHeight - brandPara.height) / 2;

    // Draw shadow text first? Paragraph builder handles shadows now.
    canvas.drawParagraph(brandPara, ui.Offset(textX, textY));
    
    // Draw Logo Image
    paintImage(
       canvas: canvas,
       rect: Rect.fromLTWH(logoX, logoY, logoDrawWidth, logoDrawHeight),
       image: logoImage,
       fit: BoxFit.contain,
    );

  } catch (e) {
    print('Error loading/drawing logo: $e');
    // Continue without logo if fails
  }

  // 6. Save
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
