import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'file_cache_types.dart';

final Set<String> _cachedFiles = <String>{};

Future<CachedFileInfo?> cacheFileImpl(PlatformFile file) async {
  try {
    final originalPath = file.path;
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}upload_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final tempPath =
        '${cacheDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$safeName';
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
    _cachedFiles.add(output.path);
    return CachedFileInfo(path: output.path, size: size);
  } catch (_) {
    return null;
  }
}

Future<int> clearCachedFilesImpl(Set<String> excludePaths) async {
  final protected = Set<String>.from(excludePaths);
  final tempDir = await getTemporaryDirectory();
  final cacheDir = Directory('${tempDir.path}${Platform.pathSeparator}upload_cache');
  var removed = 0;

  if (await cacheDir.exists()) {
    await for (final entity in cacheDir.list(recursive: false, followLinks: false)) {
      if (entity is! File) continue;
      final path = entity.path;
      if (protected.contains(path)) continue;
      try {
        await entity.delete();
        removed += 1;
      } catch (_) {
        // Ignore delete errors.
      }
    }
  }

  _cachedFiles.removeWhere((path) => !protected.contains(path));
  return removed;
}
