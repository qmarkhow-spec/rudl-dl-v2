import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get _enabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> init() async {
    if (!_enabled) return;
    if (_initialized) return;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  static Future<void> showUploadSuccess(String title) async {
    if (!_enabled) return;
    await _show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Upload completed',
      body: title,
    );
  }

  static Future<void> showUploadFailed(String title, String error) async {
    if (!_enabled) return;
    await _show(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Upload failed',
      body: '$title\n$error',
    );
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_enabled) return;
    const androidDetails = AndroidNotificationDetails(
      'upload_status',
      'Upload Status',
      channelDescription: 'Upload completion notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }
}
