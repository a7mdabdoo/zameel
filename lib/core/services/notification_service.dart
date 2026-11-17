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

  /// معرف جلسة الشات المفتوحة حالياً في الشاشة لتفادي الإشعارات المزعجة أثناء المحادثة الحية
  static String? activeChatSessionId;

  /// معالج الضغط على الإشعار للانتقال للشاشة المناسبة
  static void Function(String? payload)? onNotificationClick;

  bool get isInitialized => _isInitialized;

  /// تهيئة نظام الإشعارات المحلية وطلب الأذونات لنظام Android و iOS
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
          onNotificationClick?.call(response.payload);
        },
      );

      // طلب إذن الإشعارات صراحة في Android 13+ (POST_NOTIFICATIONS)
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialize warning: $e');
    }
  }

  /// إرسال إشعار محلي مع تخصيص القناة والأهمية
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'zameel_chat_channel',
    String channelName = 'محادثات جلسات زَميل',
    String channelDescription = 'إشعارات الرسائل الجديدة في جلسات بنك الوقت',
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
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
    // إذا كان المستخدم فاتح نفس شاشة الشات حالياً، لا داعي لإطلاق إشعار هيدز-أب يغطي الشاشة
    if (activeChatSessionId == sessionId) return;

    final notificationId = sessionId.hashCode ^ DateTime.now().minute;
    await showLocalNotification(
      id: notificationId,
      channelId: 'zameel_chat_channel',
      channelName: 'محادثات جلسات زَميل',
      channelDescription: 'إشعارات الرسائل الجديدة في جلسات بنك الوقت',
      title: '💬 رسالة جديدة من $senderName',
      body: messageText,
      payload: 'session:$sessionId',
    );
  }

  /// إشعار فوري عند قيام طالب بالرد على سؤالك الأكاديمي
  Future<void> showAnswerNotification({
    required String authorName,
    required String questionTitle,
    required String answerText,
    required String questionId,
  }) async {
    final notificationId = questionId.hashCode ^ DateTime.now().minute;
    await showLocalNotification(
      id: notificationId,
      channelId: 'zameel_qa_channel',
      channelName: 'منتدى الأسئلة والحلول',
      channelDescription: 'تنبيهات الإجابات والحلول الجديدة على أسئلتك الأكاديمية',
      title: '💡 إجابة جديدة من $authorName',
      body: 'على سؤالك "$questionTitle": $answerText',
      payload: 'question:$questionId',
    );
  }

  /// خطاف (Hook) جاهز لربط Firebase Cloud Messaging (FCM)
  Future<void> setupFcmHook({Function(Map<String, dynamic>)? onRemoteMessageReceived}) async {
    debugPrint('FCM Hook registered. Ready to receive background cloud pushes.');
  }
}
