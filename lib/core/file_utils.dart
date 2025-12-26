import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Saves an image from a temporary source path to the application's persistent documents directory.
/// Returns the new persistent path.
Future<String> saveImageToPersistentStorage(String sourcePath) async {
  try {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Source file not found: $sourcePath');
    }

    final appDocDir = await getApplicationSupportDirectory();
    final imagesDir = Directory(p.join(appDocDir.path, 'loto_images'));

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = p.basename(sourcePath);
    // Use a timestamp to ensure uniqueness if needed, but basename from picker is usually unique enough for temp.
    // However, if we pick the same file twice, we might overwrite.
    // Let's prepend timestamp to be safe and avoid collisions.
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newFileName = '${timestamp}_$fileName';
    final newPath = p.join(imagesDir.path, newFileName);

    await sourceFile.copy(newPath);

    // We don't delete the source file immediately if it's from the picker/cache
    // as the picker might manage it, but copying ensures we own this version.

    return newPath;
  } catch (e) {
    print('Error saving image to persistent storage: $e');
    rethrow;
  }
}
