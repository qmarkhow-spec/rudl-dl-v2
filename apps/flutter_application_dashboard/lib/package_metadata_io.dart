import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:plist_parser/plist_parser.dart';

import 'package_metadata_types.dart';

class ApkMetadataReader {
  static const MethodChannel _channel = MethodChannel('apk_metadata');

  static Future<PackageMetadata?> read(String path) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getApkMetadata',
        {'path': path},
      );
      if (result == null) return null;
      return PackageMetadata(
        title: result['title']?.toString(),
        bundleId: result['bundleId']?.toString(),
        version: result['version']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

Future<PackageMetadata?> readIpaMetadata(String path) async {
  if (!path.toLowerCase().endsWith('.ipa')) return null;
  try {
    final input = InputFileStream(path);
    final archive = ZipDecoder().decodeBuffer(input, verify: true);
    ArchiveFile? plistFile;
    final matcher = RegExp(r'Payload/[^/]+\.app/Info\.plist$', caseSensitive: false);
    for (final file in archive) {
      if (matcher.hasMatch(file.name)) {
        plistFile = file;
        break;
      }
    }
    if (plistFile == null) return null;
    final data = plistFile.content as List<int>;
    final tempDir = await getTemporaryDirectory();
    final tempPath =
        '${tempDir.path}${Platform.pathSeparator}ipa_info_${DateTime.now().millisecondsSinceEpoch}.plist';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(data, flush: true);
    Map<String, dynamic>? parsed;
    try {
      final result = PlistParser().parseFileSync(tempPath);
      if (result is Map) {
        parsed = result.map((key, value) => MapEntry(key.toString(), value));
      }
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
    if (parsed == null) return null;
    final title = (parsed['CFBundleDisplayName'] ??
            parsed['CFBundleName'] ??
            parsed['CFBundleExecutable'])
        ?.toString();
    final bundleId = parsed['CFBundleIdentifier']?.toString();
    final version =
        (parsed['CFBundleShortVersionString'] ?? parsed['CFBundleVersion'])?.toString();

    if ((title ?? '').isEmpty && (bundleId ?? '').isEmpty && (version ?? '').isEmpty) {
      return null;
    }
    return PackageMetadata(title: title, bundleId: bundleId, version: version);
  } catch (_) {
    return null;
  }
}
