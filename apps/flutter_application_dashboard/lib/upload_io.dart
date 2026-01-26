import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> uploadFileStream({
  required http.Client client,
  required String uploadUrl,
  required Map<String, String> uploadHeaders,
  String? path,
  Stream<List<int>>? stream,
  required int length,
  void Function(int sent, int total)? onProgress,
}) async {
  if (stream == null) {
    if (path == null || path.isEmpty) {
      throw Exception('FILE_PATH_MISSING');
    }
    stream = File(path).openRead();
  }

  final uri = Uri.parse(uploadUrl);
  final ioClient = HttpClient();
  ioClient.connectionTimeout = const Duration(minutes: 5);
  final request = await ioClient.openUrl('PUT', uri);
  request.bufferOutput = false;
  request.contentLength = length;
  uploadHeaders.forEach((key, value) {
    request.headers.set(key, value);
  });

  int sent = 0;
  await stream.forEach((chunk) {
    sent += chunk.length;
    if (onProgress != null) {
      onProgress(sent, length);
    }
    request.add(chunk);
  });

  final response = await request.close();
  ioClient.close(force: true);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('UPLOAD_FAILED_${response.statusCode}');
  }
}
