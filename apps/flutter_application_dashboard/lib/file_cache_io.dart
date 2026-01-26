import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'file_cache_types.dart';

Future<CachedFileInfo?> cacheFileImpl(PlatformFile file) async {
  try {
    final originalPath = file.path;
    if (originalPath != null &&
        originalPath.isNotEmpty &&
        !originalPath.startsWith('content://')) {
      final original = File(originalPath);
      if (await original.exists()) {
        final size = await original.length();
        return CachedFileInfo(path: original.path, size: size);
      }
    }

    final tempDir = await getTemporaryDirectory();
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final tempPath =
        '${tempDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final output = File(tempPath);
    final sink = output.openWrite();
    try {
      if (file.readStream != null) {
        await file.readStream!.pipe(sink);
      } else if (file.bytes != null) {
        sink.add(file.bytes!);
      } else if (originalPath != null && originalPath.isNotEmpty) {
        await File(originalPath).openRead().pipe(sink);
      } else {
        return null;
      }
    } finally {
      await sink.close();
    }
    final size = await output.length();
    return CachedFileInfo(path: output.path, size: size);
  } catch (_) {
    return null;
  }
}
