import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_service.dart';
import 'notification_service.dart';

/// ويدجت مستمع عام للإشعارات يحيط بالتطبيق لمتابعة الردود على الأسئلة
/// ورسائل جلسات الشات في الوقت الحقيقي وعرض الإشعارات الفورية
class GlobalNotificationListener extends ConsumerStatefulWidget {
  final Widget child;

  const GlobalNotificationListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<GlobalNotificationListener> createState() => _GlobalNotificationListenerState();
}

class _GlobalNotificationListenerState extends ConsumerState<GlobalNotificationListener> {
  StreamSubscription? _questionsSub;
  StreamSubscription? _learnerSessionsSub;
  StreamSubscription? _teacherSessionsSub;
  final Map<String, StreamSubscription> _sessionMessageSubs = {};

  final Map<String, int> _knownAnswersCount = {};
  final Map<String, String> _knownLastMessageIds = {};
  String? _currentListeningUserId;

  @override
  void initState() {
    super.initState();
    _setupNotificationClickHandler();
  }

  void _setupNotificationClickHandler() {
    NotificationService.onNotificationClick = (payload) {
      if (!mounted || payload == null) return;
      try {
        if (payload.startsWith('question:')) {
          context.go('/questions');
        } else if (payload.startsWith('session:')) {
          // التوجيه إلى شاشة بنك الوقت أو الجلسات
          context.push('/my-sessions');
        }
      } catch (e) {
        debugPrint('Navigation on notification click notice: $e');
      }
    };
  }

  @override
  void dispose() {
    _cancelAllSubscriptions();
    super.dispose();
  }

  void _cancelAllSubscriptions() {
    _questionsSub?.cancel();
    _questionsSub = null;
    _learnerSessionsSub?.cancel();
    _learnerSessionsSub = null;
    _teacherSessionsSub?.cancel();
    _teacherSessionsSub = null;

    for (final sub in _sessionMessageSubs.values) {
      sub.cancel();
    }
    _sessionMessageSubs.clear();
    _knownAnswersCount.clear();
    _knownLastMessageIds.clear();
    _currentListeningUserId = null;
  }

  void _startListening(String userId) {
    if (_currentListeningUserId == userId) return;
    _cancelAllSubscriptions();
    _currentListeningUserId = userId;

    // 1. الاستماع لأسئلة المستخدم وإشعاره عند وصول إجابات جديدة
    _questionsSub = FirebaseFirestore.instance
        .collection('questions')
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final qId = doc.id;
        final data = doc.data();
        final title = data['title'] as String? ?? 'سؤالك الأكاديمي';
        final count = (data['answersCount'] as num?)?.toInt() ?? 0;

        if (!_knownAnswersCount.containsKey(qId)) {
          // تسجيل الحالة المبدئية عند فتح التطبيق دون إرسال إشعارات قديمة
          _knownAnswersCount[qId] = count;
        } else if (count > (_knownAnswersCount[qId] ?? 0)) {
          _knownAnswersCount[qId] = count;
          // جلب أحدث إجابة لمعرفة اسم المجيب ونص رده
          doc.reference
              .collection('answers')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get()
              .then((answerSnap) {
            if (answerSnap.docs.isNotEmpty) {
              final aData = answerSnap.docs.first.data();
              final authorId = aData['authorId'] as String? ?? '';
              final authorName = aData['authorName'] as String? ?? 'زميل';
              final text = aData['text'] as String? ?? '';

              // التأكد أن الرد ليس من صاحب السؤال نفسه
              if (authorId != userId) {
                ref.read(notificationServiceProvider).showAnswerNotification(
                      authorName: authorName,
                      questionTitle: title,
                      answerText: text.isNotEmpty ? text : 'قام بإرفاق صورة للحل 📸',
                      questionId: qId,
                    );
              }
            }
          }).catchError((err) {
            debugPrint('Error fetching latest answer for notification: $err');
          });
        }
      }
    }, onError: (err) {
      debugPrint('Global questions notification stream error: $err');
    });

    // 2. الاستماع لجلسات المتعلم
    _learnerSessionsSub = FirebaseFirestore.instance
        .collection('sessions')
        .where('learnerId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _handleSessionsSnapshot(snapshot);
    }, onError: (err) {
      debugPrint('Global learner sessions stream error: $err');
    });

    // 3. الاستماع لجلسات المعلم
    _teacherSessionsSub = FirebaseFirestore.instance
        .collection('sessions')
        .where('teacherId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      _handleSessionsSnapshot(snapshot);
    }, onError: (err) {
      debugPrint('Global teacher sessions stream error: $err');
    });
  }

  void _handleSessionsSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final activeSessionIds = <String>{};
    for (final doc in snapshot.docs) {
      final status = doc.data()['status'] as String? ?? '';
      // متابعة رسائل الجلسات المؤكدة أو قيد الانتظار فقط
      if (status == 'confirmed' || status == 'pending') {
        activeSessionIds.add(doc.id);
        _subscribeToSessionMessages(doc.id);
      }
    }

    // إلغاء الاستماع للجلسات التي انتهت أو أُلغيت
    final removed = _sessionMessageSubs.keys.where((id) => !activeSessionIds.contains(id)).toList();
    for (final id in removed) {
      _sessionMessageSubs[id]?.cancel();
      _sessionMessageSubs.remove(id);
      _knownLastMessageIds.remove(id);
    }
  }

  void _subscribeToSessionMessages(String sessionId) {
    if (_sessionMessageSubs.containsKey(sessionId)) return;

    final sub = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((msgSnap) {
      if (msgSnap.docs.isEmpty) return;

      final latestDoc = msgSnap.docs.first;
      final msgId = latestDoc.id;
      final data = latestDoc.data();

      if (!_knownLastMessageIds.containsKey(sessionId)) {
        // تسجيل آخر رسالة موجودة عند بدء المراقبة
        _knownLastMessageIds[sessionId] = msgId;
      } else if (_knownLastMessageIds[sessionId] != msgId) {
        _knownLastMessageIds[sessionId] = msgId;

        final senderId = data['senderId'] as String? ?? '';
        final senderName = data['senderName'] as String? ?? 'زميل';
        final text = data['text'] as String? ?? '';

        if (senderId != _currentListeningUserId) {
          ref.read(notificationServiceProvider).showChatMessageNotification(
                senderName: senderName,
                messageText: text,
                sessionId: sessionId,
              );
        }
      }
    }, onError: (err) {
      debugPrint('Session $sessionId messages stream error: $err');
    });

    _sessionMessageSubs[sessionId] = sub;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value ?? ref.watch(authServiceProvider).currentUser;

    if (user != null) {
      _startListening(user.uid);
    } else {
      _cancelAllSubscriptions();
    }

    return widget.child;
  }
}
