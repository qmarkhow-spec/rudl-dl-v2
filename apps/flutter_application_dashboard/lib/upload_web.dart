import 'package:http/http.dart' as http;

Future<void> uploadFileStream({
  required http.Client client,
  required String uploadUrl,
  required Map<String, String> uploadHeaders,
  required String path,
  required int length,
}) async {
  throw Exception('UPLOAD_FILE_NOT_SUPPORTED_ON_WEB');
}
