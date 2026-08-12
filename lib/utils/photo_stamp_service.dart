import 'dart:io';
import 'package:image/image.dart' as img;
import 'qatar_time.dart';

class PhotoStampService {
  /// Draws a Qatar-time date/time stamp onto the bottom-left corner of a
  /// captured photo (like an old-school camera timestamp), then overwrites
  /// the file in place so both the on-screen preview and the uploaded copy
  /// carry the stamp.
  static Future<void> stampPhotoInPlace(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return;

      final now = QatarTime.now();
      final text =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}  '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final bool isLarge = image.width > 1400;
      final img.BitmapFont font = isLarge ? img.arial48 : (image.width > 700 ? img.arial24 : img.arial14);

      // Fixed approximate sizing instead of reading font metrics directly
      // (avoids relying on properties the package doesn't expose the same
      // way across versions) — good enough for a readable stamp box.
      final int fontPixelHeight = isLarge ? 48 : (image.width > 700 ? 24 : 14);
      final int approxCharWidth = (fontPixelHeight * 0.6).round();
      final int padding = (image.width * 0.02).round().clamp(6, 30);

      final int boxWidth = (text.length * approxCharWidth) + padding * 2;
      final int boxHeight = fontPixelHeight + padding * 2;

      final int x = padding;
      final int y = (image.height - boxHeight - padding).clamp(0, image.height);

      // Semi-transparent dark background so the text stays legible on any photo.
      img.fillRect(
        image,
        x1: x,
        y1: y,
        x2: (x + boxWidth).clamp(0, image.width),
        y2: (y + boxHeight).clamp(0, image.height),
        color: img.ColorRgba8(0, 0, 0, 140),
      );

      img.drawString(
        image,
        text,
        font: font,
        x: x + padding,
        y: y + padding,
        color: img.ColorRgb8(255, 255, 255),
      );

      final restamped = img.encodeJpg(image, quality: 85);
      await File(filePath).writeAsBytes(restamped);
    } catch (_) {
      // If stamping fails for any reason, leave the original photo untouched
      // rather than blocking the delivery/failure flow.
    }
  }
}