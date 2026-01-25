import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> uploadFileStream({
  required http.Client client,
  required String uploadUrl,
  required Map<String, String> uploadHeaders,
  required String path,
  required int length,
}) async {
  final file = File(path);
  final request = http.StreamedRequest('PUT', Uri.parse(uploadUrl));
  request.headers.addAll(uploadHeaders);
  request.contentLength = length;
  final stream = file.openRead();
  stream.listen(
    request.sink.add,
    onDone: request.sink.close,
    onError: request.sink.addError,
    cancelOnError: true,
  );
  final response = await client.send(request);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('UPLOAD_FAILED_${response.statusCode}');
  }
}
