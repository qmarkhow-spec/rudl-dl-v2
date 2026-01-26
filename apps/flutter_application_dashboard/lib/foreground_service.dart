import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_EmptyTaskHandler());
}

class _EmptyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class ForegroundService {
  static bool _initialized = false;

  static bool get _enabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> init() async {
    if (!_enabled) return;
    if (_initialized) return;
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'upload_foreground',
          channelName: 'Upload Service',
          channelDescription: 'Keep uploads running in background',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          autoRunOnBoot: false,
          autoRunOnMyPackageReplaced: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  static Future<void> start(String title, String text) async {
    if (!_enabled) return;
    if (await FlutterForegroundTask.isRunningService) return;
    try {
      await FlutterForegroundTask.startService(
        notificationTitle: title,
        notificationText: text,
        callback: startCallback,
      );
    } catch (_) {
      // Ignore unsupported platforms.
    }
  }

  static Future<void> update(String title, String text) async {
    if (!_enabled) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    } catch (_) {
      // Ignore unsupported platforms.
    }
  }

  static Future<void> stop() async {
    if (!_enabled) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {
      // Ignore unsupported platforms.
    }
  }
}
