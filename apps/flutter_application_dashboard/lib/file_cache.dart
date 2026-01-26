import 'package:file_picker/file_picker.dart';

import 'file_cache_types.dart';
import 'file_cache_stub.dart' if (dart.library.io) 'file_cache_io.dart';

Future<CachedFileInfo?> cacheFile(PlatformFile file) => cacheFileImpl(file);

Future<int> clearCachedFiles(Set<String> excludePaths) =>
    clearCachedFilesImpl(excludePaths);
