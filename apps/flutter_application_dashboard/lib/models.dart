import 'package:intl/intl.dart';

class AccountRecord {
  final String id;
  final String email;
  final String cookie;
  final String baseUrl;
  final DateTime createdAt;

  const AccountRecord({
    required this.id,
    required this.email,
    required this.cookie,
    required this.baseUrl,
    required this.createdAt,
  });

  AccountRecord copyWith({String? cookie}) {
    return AccountRecord(
      id: id,
      email: email,
      cookie: cookie ?? this.cookie,
      baseUrl: baseUrl,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'cookie': cookie,
        'baseUrl': baseUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AccountRecord.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['createdAt']?.toString() ?? '';
    final created = DateTime.tryParse(createdRaw) ?? DateTime.now();
    return AccountRecord(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      cookie: json['cookie']?.toString() ?? '',
      baseUrl: json['baseUrl']?.toString() ?? '',
      createdAt: created,
    );
  }
}

class DashboardPage {
  final int page;
  final int pageSize;
  final int total;
  final double balance;
  final List<DashboardLink> links;

  const DashboardPage({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.balance,
    required this.links,
  });

  factory DashboardPage.fromJson(Map<String, dynamic> json) {
    final links = (json['links'] as List<dynamic>? ?? [])
        .map((item) => DashboardLink.fromJson(item as Map<String, dynamic>))
        .toList();
    return DashboardPage(
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 10,
      total: (json['total'] as num?)?.toInt() ?? links.length,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      links: links,
    );
  }
}

class DashboardLink {
  final String id;
  final String code;
  final String title;
  final String bundleId;
  final String apkVersion;
  final String ipaVersion;
  final String platform;
  final bool isActive;
  final DateTime createdAt;
  final String language;
  final String networkArea;
  final int todayApkDl;
  final int todayIpaDl;
  final int todayTotalDl;
  final int totalApkDl;
  final int totalIpaDl;
  final int totalTotalDl;
  final List<DashboardFile> files;

  const DashboardLink({
    required this.id,
    required this.code,
    required this.title,
    required this.bundleId,
    required this.apkVersion,
    required this.ipaVersion,
    required this.platform,
    required this.isActive,
    required this.createdAt,
    required this.language,
    required this.networkArea,
    required this.todayApkDl,
    required this.todayIpaDl,
    required this.todayTotalDl,
    required this.totalApkDl,
    required this.totalIpaDl,
    required this.totalTotalDl,
    required this.files,
  });

  factory DashboardLink.fromJson(Map<String, dynamic> json) {
    final createdSeconds = (json['createdAt'] as num?)?.toInt() ?? 0;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(createdSeconds * 1000, isUtc: true)
        .toLocal();
    return DashboardLink(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '-',
      bundleId: json['bundleId']?.toString() ?? '',
      apkVersion: json['apkVersion']?.toString() ?? '',
      ipaVersion: json['ipaVersion']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      isActive: json['isActive'] == true || json['isActive'] == 1,
      createdAt: createdAt,
      language: json['language']?.toString() ?? 'en',
      networkArea: json['networkArea']?.toString() ?? 'global',
      todayApkDl: (json['todayApkDl'] as num?)?.toInt() ?? 0,
      todayIpaDl: (json['todayIpaDl'] as num?)?.toInt() ?? 0,
      todayTotalDl: (json['todayTotalDl'] as num?)?.toInt() ?? 0,
      totalApkDl: (json['totalApkDl'] as num?)?.toInt() ?? 0,
      totalIpaDl: (json['totalIpaDl'] as num?)?.toInt() ?? 0,
      totalTotalDl: (json['totalTotalDl'] as num?)?.toInt() ?? 0,
      files: (json['files'] as List<dynamic>? ?? [])
          .map((item) => DashboardFile.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DashboardFile {
  final String id;
  final String platform;
  final String title;
  final String bundleId;
  final String version;
  final int size;
  final DateTime createdAt;

  const DashboardFile({
    required this.id,
    required this.platform,
    required this.title,
    required this.bundleId,
    required this.version,
    required this.size,
    required this.createdAt,
  });

  factory DashboardFile.fromJson(Map<String, dynamic> json) {
    final createdSeconds = (json['createdAt'] as num?)?.toInt() ?? 0;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(createdSeconds * 1000, isUtc: true)
        .toLocal();
    return DashboardFile(
      id: json['id']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      bundleId: json['bundleId']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
    );
  }
}

class StatsPoint {
  final DateTime bucket;
  final int apk;
  final int ipa;
  final int total;

  const StatsPoint({
    required this.bucket,
    required this.apk,
    required this.ipa,
    required this.total,
  });

  factory StatsPoint.fromJson(Map<String, dynamic> json) {
    final bucketRaw = json['bucket']?.toString() ?? '';
    final bucket = DateTime.tryParse(bucketRaw)?.toLocal() ?? DateTime.now();
    return StatsPoint(
      bucket: bucket,
      apk: (json['apk'] as num?)?.toInt() ?? 0,
      ipa: (json['ipa'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class StatsSummary {
  final int total;
  final int totalApk;
  final int totalIpa;
  final DateTime from;
  final DateTime to;

  const StatsSummary({
    required this.total,
    required this.totalApk,
    required this.totalIpa,
    required this.from,
    required this.to,
  });

  factory StatsSummary.fromJson(Map<String, dynamic> json) {
    final from = DateTime.tryParse(json['from']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    final to = DateTime.tryParse(json['to']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    return StatsSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalApk: (json['totalApk'] as num?)?.toInt() ?? 0,
      totalIpa: (json['totalIpa'] as num?)?.toInt() ?? 0,
      from: from,
      to: to,
    );
  }
}

class StatsResponse {
  final StatsSummary summary;
  final List<StatsPoint> points;

  const StatsResponse({required this.summary, required this.points});

  factory StatsResponse.fromJson(Map<String, dynamic> json) {
    final summary = StatsSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {});
    final points = (json['points'] as List<dynamic>? ?? [])
        .map((item) => StatsPoint.fromJson(item as Map<String, dynamic>))
        .toList();
    return StatsResponse(summary: summary, points: points);
  }
}

class UploadTicket {
  final String linkId;
  final String uploadUrl;
  final Map<String, String> uploadHeaders;
  final UploadPayload payload;

  const UploadTicket({
    required this.linkId,
    required this.uploadUrl,
    required this.uploadHeaders,
    required this.payload,
  });

  factory UploadTicket.fromJson(Map<String, dynamic> json) {
    final upload = json['upload'] as Map<String, dynamic>? ?? {};
    return UploadTicket(
      linkId: json['linkId']?.toString() ?? '',
      uploadUrl: json['uploadUrl']?.toString() ?? '',
      uploadHeaders: (json['uploadHeaders'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, value.toString())),
      payload: UploadPayload.fromJson(upload),
    );
  }
}

class UploadPayload {
  final String platform;
  final String key;
  final int size;
  final String? title;
  final String? bundleId;
  final String? version;
  final String? contentType;
  final String? sha256;

  const UploadPayload({
    required this.platform,
    required this.key,
    required this.size,
    required this.title,
    required this.bundleId,
    required this.version,
    required this.contentType,
    required this.sha256,
  });

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'key': key,
        'size': size,
        'title': title,
        'bundleId': bundleId,
        'version': version,
        'contentType': contentType,
        'sha256': sha256,
      };

  factory UploadPayload.fromJson(Map<String, dynamic> json) {
    return UploadPayload(
      platform: json['platform']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString(),
      bundleId: json['bundleId']?.toString(),
      version: json['version']?.toString(),
      contentType: json['contentType']?.toString(),
      sha256: json['sha256']?.toString(),
    );
  }
}

String formatSize(int size) {
  if (size <= 0) return '-';
  final mb = size / (1024 * 1024);
  return '${mb.toStringAsFixed(1)} MB';
}

String formatDateTime(DateTime date) {
  final formatter = DateFormat('yyyy/MM/dd HH:mm');
  return formatter.format(date);
}

String formatCount(int value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}
