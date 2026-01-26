import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'http_client.dart' if (dart.library.html) 'http_client_web.dart';
import 'models.dart';
import 'foreground_service.dart';
import 'notification_service.dart';
import 'file_cache.dart' as cache;

enum UploadJobStatus { queued, uploading, success, failed }

enum UploadEventType { success, failed }

class UploadEvent {
  final UploadEventType type;
  final UploadJob job;

  const UploadEvent({required this.type, required this.job});
}

class UploadFile {
  final String platform;
  final String fileName;
  final int size;
  final List<int>? bytes;
  final String? path;
  final Stream<List<int>>? stream;
  final String? metaTitle;
  final String? metaBundleId;
  final String? metaVersion;

  double progress = 0;
  String? error;

  UploadFile({
    required this.platform,
    required this.fileName,
    required this.size,
    required this.bytes,
    required this.path,
    required this.stream,
    required this.metaTitle,
    required this.metaBundleId,
    required this.metaVersion,
  });
}

class UploadJob {
  final String id;
  final AccountRecord account;
  final bool isEdit;
  final String? linkId;
  final String title;
  final String bundleId;
  final String apkVersion;
  final String ipaVersion;
  final bool autofill;
  final String lang;
  final bool isActive;
  final String networkArea;
  final List<UploadFile> files;

  UploadJobStatus status = UploadJobStatus.queued;
  double progress = 0;
  String? error;

  UploadJob({
    required this.id,
    required this.account,
    required this.isEdit,
    required this.linkId,
    required this.title,
    required this.bundleId,
    required this.apkVersion,
    required this.ipaVersion,
    required this.autofill,
    required this.lang,
    required this.isActive,
    required this.networkArea,
    required this.files,
  });
}

class UploadManager extends ChangeNotifier {
  final List<UploadJob> _queue = [];
  final List<UploadJob> _history = [];
  UploadJob? _current;
  bool _processing = false;
  final StreamController<UploadEvent> _events = StreamController.broadcast();

  List<UploadJob> get queue => List.unmodifiable(_queue);
  List<UploadJob> get history => List.unmodifiable(_history);
  UploadJob? get current => _current;
  bool get isBusy => _processing;
  Stream<UploadEvent> get events => _events.stream;

  void enqueue(UploadJob job) {
    _queue.add(job);
    notifyListeners();
    _process();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  Future<int> clearCachedFiles() async {
    final exclude = <String>{};
    for (final job in _queue) {
      for (final file in job.files) {
        final path = file.path;
        if (path != null && path.isNotEmpty) {
          exclude.add(path);
        }
      }
    }
    final active = _current;
    if (active != null) {
      for (final file in active.files) {
        final path = file.path;
        if (path != null && path.isNotEmpty) {
          exclude.add(path);
        }
      }
    }
    return cache.clearCachedFiles(exclude);
  }

  Future<void> _process() async {
    if (_processing) return;
    _processing = true;
    notifyListeners();
    try {
      await NotificationService.init();
      while (_queue.isNotEmpty) {
        final job = _queue.removeAt(0);
        _current = job;
        notifyListeners();
        try {
          await ForegroundService.start(
            'Uploading',
            job.title.isEmpty ? 'Uploading files' : job.title,
          );
          await _runJob(job);
        } catch (error) {
          job.status = UploadJobStatus.failed;
          job.error = error.toString();
          _events.add(UploadEvent(type: UploadEventType.failed, job: job));
        } finally {
          _history.insert(0, job);
          _current = null;
          notifyListeners();
        }
      }
    } finally {
      _processing = false;
      await ForegroundService.stop();
      notifyListeners();
    }
  }

  Future<void> _runJob(UploadJob job) async {
    job.status = UploadJobStatus.uploading;
    job.progress = 0;
    job.error = null;
    notifyListeners();

    final totalBytes =
        job.files.isEmpty ? 1 : job.files.fold<int>(0, (sum, file) => sum + file.size);
    int sentBytes = 0;

    final api = DashboardApi(baseUrl: job.account.baseUrl, cookie: job.account.cookie);
    final uploads = <UploadPayload>[];

    try {
      String? linkId = job.linkId;
      for (final file in job.files) {
        final contentType = file.platform == 'apk'
            ? 'application/vnd.android.package-archive'
            : 'application/octet-stream';
        final metaTitle = (file.metaTitle ?? '').trim();
        final metaBundleId = (file.metaBundleId ?? '').trim();
        final metaVersion = (file.metaVersion ?? '').trim();
        if (file.platform == 'ipa' &&
            (metaBundleId.isEmpty || metaVersion.isEmpty)) {
          throw ApiException('IPA_METADATA_MISSING');
        }
        final ticket = await api.requestUpload(
          platform: file.platform,
          fileName: file.fileName,
          size: file.size,
          contentType: contentType,
          title: metaTitle.isNotEmpty
              ? metaTitle
              : file.platform == 'ipa'
                  ? null
                  : (job.title.isEmpty ? null : job.title),
          bundleId: metaBundleId.isNotEmpty
              ? metaBundleId
              : file.platform == 'ipa'
                  ? null
                  : (job.bundleId.isEmpty ? null : job.bundleId),
          version: metaVersion.isNotEmpty
              ? metaVersion
              : file.platform == 'ipa'
                  ? null
                  : file.platform == 'apk'
                      ? (job.apkVersion.isEmpty ? null : job.apkVersion)
                      : (job.ipaVersion.isEmpty ? null : job.ipaVersion),
          linkId: linkId,
          networkArea: job.networkArea,
        );
        linkId = ticket.linkId;

        if (kIsWebClient) {
          final bytes = file.bytes;
          if (bytes == null) {
            throw ApiException('FILE_BYTES_MISSING');
          }
          await api.uploadBytes(
            uploadUrl: ticket.uploadUrl,
            uploadHeaders: ticket.uploadHeaders,
            bytes: bytes,
          );
          sentBytes += file.size;
          file.progress = 1;
          job.progress = sentBytes / totalBytes;
          await ForegroundService.update(
            'Uploading',
            '${(job.progress * 100).toStringAsFixed(0)}% ${job.title.isEmpty ? file.fileName : job.title}',
          );
          notifyListeners();
        } else {
          final path = file.path;
          final hasStream = file.stream != null;
          if ((path == null || path.isEmpty) && !hasStream) {
            throw ApiException('FILE_PATH_MISSING');
          }
          await api.uploadFile(
            uploadUrl: ticket.uploadUrl,
            uploadHeaders: ticket.uploadHeaders,
            path: path,
            stream: file.stream,
            length: file.size,
            onProgress: (sent, total) {
              final current = sentBytes + sent;
              file.progress = total == 0 ? 0 : sent / total;
              job.progress = totalBytes == 0 ? 0 : current / totalBytes;
              ForegroundService.update(
                'Uploading',
                '${(job.progress * 100).toStringAsFixed(0)}% ${job.title.isEmpty ? file.fileName : job.title}',
              );
              notifyListeners();
            },
          );
          sentBytes += file.size;
          file.progress = 1;
          job.progress = sentBytes / totalBytes;
          notifyListeners();
        }

        uploads.add(ticket.payload);
      }

      if (linkId == null || linkId.isEmpty) {
        throw ApiException('LINK_ID_MISSING');
      }

      if (job.isEdit) {
        await api.updateDistribution(
          linkId: linkId,
          title: job.title,
          bundleId: job.bundleId,
          apkVersion: job.apkVersion,
          ipaVersion: job.ipaVersion,
          autofill: job.autofill,
          lang: job.lang,
          uploads: uploads,
          isActive: job.isActive,
          networkArea: job.networkArea,
        );
      } else {
        await api.createDistribution(
          linkId: linkId,
          title: job.title,
          bundleId: job.bundleId,
          apkVersion: job.apkVersion,
          ipaVersion: job.ipaVersion,
          autofill: job.autofill,
          lang: job.lang,
          uploads: uploads,
          isActive: job.isActive,
          networkArea: job.networkArea,
        );
      }

      job.status = UploadJobStatus.success;
      job.progress = 1;
      await ForegroundService.update('Upload completed', job.title.isEmpty ? 'Done' : job.title);
      await NotificationService.showUploadSuccess(
        job.title.isEmpty ? 'Distribution updated' : job.title,
      );
      _events.add(UploadEvent(type: UploadEventType.success, job: job));
    } catch (error) {
      job.status = UploadJobStatus.failed;
      job.error = error.toString();
      await ForegroundService.update('Upload failed', job.title.isEmpty ? 'Error' : job.title);
      await NotificationService.showUploadFailed(
        job.title.isEmpty ? 'Distribution update failed' : job.title,
        job.error ?? 'Unknown error',
      );
      _events.add(UploadEvent(type: UploadEventType.failed, job: job));
    } finally {
      notifyListeners();
    }
  }
}

