import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.initialize();
  return service;
});

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// تهيئة نظام الإشعارات المحلية
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kIsWeb) {
        _isInitialized = true;
        return;
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialize warning: $e');
    }
  }

  /// إرسال إشعار محلي
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'zameel_chat_channel',
        'محادثات جلسات زَميل',
        channelDescription: 'إشعارات الرسائل الجديدة في جلسات بنك الوقت',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// إشعار خاص برسائل الشات الأكاديمي
  Future<void> showChatMessageNotification({
    required String senderName,
    required String messageText,
    required String sessionId,
  }) async {
    final notificationId = sessionId.hashCode ^ DateTime.now().minute;
    await showLocalNotification(
      id: notificationId,
      title: '💬 رسالة جديدة من $senderName',
      body: messageText,
      payload: sessionId,
    );
  }

  /// خطاف (Hook) جاهز لربط Firebase Cloud Messaging (FCM)
  /// يُستدعى مستقبلاً عند ربط رسائل السحاب في الخلفية
  Future<void> setupFcmHook({Function(Map<String, dynamic>)? onRemoteMessageReceived}) async {
    debugPrint('FCM Hook registered. Ready to receive background cloud pushes.');
  }
}
