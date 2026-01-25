import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_client.dart' if (dart.library.html) 'http_client_web.dart';
import 'models.dart';
import 'upload_io.dart' if (dart.library.html) 'upload_web.dart';

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

class DashboardApi {
  final String baseUrl;
  final String cookie;
  final http.Client _client;

  DashboardApi({
    required this.baseUrl,
    required this.cookie,
    http.Client? client,
  }) : _client = client ?? createHttpClient();

  Uri _uri(String path, [Map<String, String>? query]) {
    final sanitized = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final uri = Uri.parse('$sanitized$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept': 'application/json',
    };
    if (cookie.isNotEmpty && !kIsWebClient) {
      headers['cookie'] = cookie;
    }
    return headers;
  }

  static String? extractUidCookie(Map<String, String> headers) {
    final raw = headers['set-cookie'] ?? headers['Set-Cookie'] ?? headers['set-cookie'.toLowerCase()];
    if (raw == null) return null;
    final match = RegExp(r'uid=([^;]+)').firstMatch(raw);
    if (match == null) return null;
    return 'uid=${match.group(1)}';
  }

  Future<({String userId, String cookie})> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/api/auth/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final payload = _decodeJson(response.body);
    if (response.statusCode != 200 || payload['ok'] != true) {
      throw ApiException(payload['error']?.toString() ?? 'LOGIN_FAILED');
    }
    final cookie = extractUidCookie(response.headers);
    if (cookie == null && !kIsWebClient) {
      throw ApiException('LOGIN_COOKIE_MISSING');
    }
    final userId = payload['user_id']?.toString() ?? '';
    return (userId: userId, cookie: cookie ?? '');
  }

  Future<DashboardPage> fetchDashboard({
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _client.get(
      _uri('/api/dashboard/links', {
        'page': page.toString(),
        'pageSize': pageSize.toString(),
      }),
      headers: _headers,
    );
    final payload = _decodeJson(response.body);
    if (response.statusCode != 200 || payload['ok'] != true) {
      throw ApiException(payload['error']?.toString() ?? 'FETCH_FAILED');
    }
    return DashboardPage.fromJson(payload);
  }

  Future<StatsResponse> fetchStats({
    required String linkId,
    String frequency = 'day',
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{'frequency': frequency};
    if (from != null) {
      query['from'] = from.toUtc().toIso8601String();
    }
    if (to != null) {
      query['to'] = to.toUtc().toIso8601String();
    }
    final response = await _client.get(
      _uri('/api/distributions/$linkId/stats', query),
      headers: _headers,
    );
    final payload = _decodeJson(response.body);
    if (response.statusCode != 200 || payload['ok'] != true) {
      throw ApiException(payload['error']?.toString() ?? 'STATS_FAILED');
    }
    return StatsResponse.fromJson(payload);
  }

  Future<void> deleteDistribution(String linkId) async {
    final response = await _client.delete(
      _uri('/api/distributions/$linkId'),
      headers: _headers,
    );
    final payload = _decodeJson(response.body);
    if (response.statusCode != 200 || payload['ok'] != true) {
      throw ApiException(payload['error']?.toString() ?? 'DELETE_FAILED');
    }
  }

  Future<UploadTicket> requestUpload({
    required String platform,
    required String fileName,
    required int size,
    required String contentType,
    String? title,
    String? bundleId,
    String? version,
    String? linkId,
    String? networkArea,
  }) async {
    final response = await _client.post(
      _uri('/api/distributions/upload'),
      headers: _headers,
      body: jsonEncode({
        'platform': platform,
        'fileName': fileName,
        'size': size,
        'contentType': contentType,
        'title': title,
        'bundleId': bundleId,
        'version': version,
        'linkId': linkId,
        'networkArea': networkArea,
      }),
    );
    final payload = _decodeJson(response.body);
    if (response.statusCode != 200 || payload['ok'] != true) {
      throw ApiException(payload['error']?.toString() ?? 'UPLOAD_REQUEST_FAILED');
    }
    return UploadTicket.fromJson(payload);
  }

  Future<void> uploadBytes({
    required String uploadUrl,
    required Map<String, String> uploadHeaders,
    required List<int> bytes,
  }) async {
    final response = await _client.put(
      Uri.parse(uploadUrl),
      headers: uploadHeaders,
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('UPLOAD_FAILED_${response.statusCode}');
    }
  }

  Future<void> uploadFile({
    required String uploadUrl,
    required Map<String, String> uploadHeaders,
    required String path,
    required int length,
  }) async {
    await uploadFileStream(
      client: _client,
      uploadUrl: uploadUrl,
      uploadHeaders: uploadHeaders,
      path: path,
      length: length,
    );
  }

  Future<void> createDistribution({
    required String linkId,
    required String title,
    required String bundleId,
    required String apkVersion,
    required String ipaVersion,
    required bool autofill,
    required String lang,
    required List<UploadPayload> uploads,
    required bool isActive,
    required String networkArea,
  }) async {
    final response = await _client.post(
      _uri('/api/distributions'),
      headers: _headers,
      body: jsonEncode({
        'linkId': linkId,
        'title': title,
        'bundleId': bundleId,
        'apkVersion': apkVersion,
        'ipaVersion': ipaVersion,
        'autofill': autofill,
        'lang': lang,
        'uploads': uploads.map((item) => item.toJson()).toList(),
        'isActive': isActive,
        'networkArea': networkArea,
      }),
    );
    final payload = _decodeJson(response.body);
    if (response.statusCode != 200 || payload['ok'] != true) {
      throw ApiException(payload['error']?.toString() ?? 'CREATE_FAILED');
    }
  }

  Future<void> updateDistribution({
    required String linkId,
    required String title,
    required String bundleId,
    required String apkVersion,
    required String ipaVersion,
    required bool autofill,
    required String lang,
    required List<UploadPayload> uploads,
    required bool isActive,
    required String networkArea,
  }) async {
    final response = await _client.patch(
      _uri('/api/distributions/$linkId'),
      headers: _headers,
      body: jsonEncode({
        'title': title,
        'bundleId': bundleId,
        'apkVersion': apkVersion,
        'ipaVersion': ipaVersion,
        'autofill': autofill,
        'lang': lang,
        'uploads': uploads.map((item) => item.toJson()).toList(),
        'isActive': isActive,
        'networkArea': networkArea,
      }),
    );
    final payload = _decodeJson(response.body);
    if (response.statusCode != 200 || payload['ok'] != true) {
      throw ApiException(payload['error']?.toString() ?? 'UPDATE_FAILED');
    }
  }

  Map<String, dynamic> _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'ok': false, 'error': 'INVALID_RESPONSE'};
    } catch (_) {
      return {'ok': false, 'error': 'INVALID_RESPONSE'};
    }
  }
}
