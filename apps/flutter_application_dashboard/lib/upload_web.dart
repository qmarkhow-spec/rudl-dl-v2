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
  throw Exception('UPLOAD_FILE_NOT_SUPPORTED_ON_WEB');
}
