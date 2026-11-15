// مطور 1
// مستودع بنك الوقت والتعاملات الذرية ونظام الضمان (Escrow & TimeBank Repository)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_models.dart';
import '../../auth/data/auth_service.dart';

class TimeBankRepository {
  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  // =========================================================================
  // 1. حجز جلسة مع حجز العملة في الضمان (Escrow Hold Transaction)
  // =========================================================================
  Future<TimeBankSessionModel> bookSessionWithEscrow({
    required TimeBankSessionModel session,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw FirebaseException(
        plugin: 'firestore',
        message: 'Firebase Firestore is not initialized',
      );
    }

    final learnerDocRef = firestore.collection('users').doc(session.learnerId);
    final sessionDocRef = firestore.collection('sessions').doc(session.id);
    final txId = 'tx_${DateTime.now().millisecondsSinceEpoch}_${session.id}';
    final txDocRef = firestore.collection('transactions').doc(txId);

    // التأكد التلقائي من وجود مستند المتعلّم برصيد الترحيب 2 عملة
    try {
      final checkSnap = await learnerDocRef.get();
      if (!checkSnap.exists) {
        await learnerDocRef.set({
          'uid': session.learnerId,
          'name': session.learnerName,
          'email': '',
          'timeCoins': AppConstants.welcomeCoins,
          'faculty': AppConstants.faculty,
          'year': AppConstants.academicYear,
          'department': 'عام (General)',
          'selectedCourses': <String>[],
          'courseRatings': <String, dynamic>{},
          'completedSessions': 0,
          'ratingSum': 0,
          'ratingCount': 0,
          'lastSessionId': null,
          'onboardingCompleted': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}

    await firestore.runTransaction((transaction) async {
      // 1. قراءة بيانات المتعلّم للتحقق من الرصيد
      final learnerSnap = await transaction.get(learnerDocRef);
      if (!learnerSnap.exists) {
        throw Exception('حساب المتعلّم غير موجود');
      }

      final currentCoins = (learnerSnap.data()?['timeCoins'] as num?)?.toInt() ?? 0;
      if (currentCoins < AppConstants.sessionCostCoins) {
        throw Exception('رصيدك لا يكفي لحجز الجلسة (المطلوب: ${AppConstants.sessionCostCoins} عملة، المتوفر: $currentCoins)');
      }

      // 2. خصم العملة وتحديث رصيد المتعلّم مع ربط الجلسة
      final updatedCoins = currentCoins - AppConstants.sessionCostCoins;
      transaction.update(learnerDocRef, {
        'timeCoins': updatedCoins,
        'lastSessionId': session.id,
      });

      // 3. إنشاء مستند الجلسة مع حالة ضمان معلّق (Escrow Held)
      final sessionData = session.toMap();
      sessionData['costCoins'] = AppConstants.sessionCostCoins;
      sessionData['escrowStatus'] = 'held';
      sessionData['status'] = 'confirmed';
      sessionData['createdAt'] = FieldValue.serverTimestamp();
      if (session.scheduledAt != null) {
        sessionData['scheduledAt'] = Timestamp.fromDate(session.scheduledAt!);
      }
      transaction.set(sessionDocRef, sessionData);

      // 4. تسجيل حركة المحفظة (خصم للضمان)
      final txData = WalletTransactionModel(
        id: txId,
        userId: session.learnerId,
        sessionId: session.id,
        title: 'حجز جلسة ${session.courseName} (في الضمان)',
        date: 'الآن',
        amount: AppConstants.sessionCostCoins,
        isNegative: true,
        type: 'session_booking',
        icon: Icons.lock_clock_outlined,
        createdAt: DateTime.now(),
      ).toMap();
      txData['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(txDocRef, txData);
    });

    return session.copyWith(
      status: 'confirmed',
      escrowStatus: 'held',
    );
  }

  // =========================================================================
  // 2. إتمام الجلسة وإطلاق العملة للمعلم (Complete & Release Escrow)
  // =========================================================================
  Future<void> completeSessionAndReleaseEscrow({
    required String sessionId,
    required String learnerId,
    required int rating,
    required String reviewComment,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw FirebaseException(
        plugin: 'firestore',
        message: 'Firebase Firestore is not initialized',
      );
    }

    final sessionDocRef = firestore.collection('sessions').doc(sessionId);

    await firestore.runTransaction((transaction) async {
      // 1. قراءة بيانات الجلسة والتحقق من حالة الضمان
      final sessionSnap = await transaction.get(sessionDocRef);
      if (!sessionSnap.exists) {
        throw Exception('الجلسة غير موجودة');
      }

      final sessionData = sessionSnap.data()!;
      final currentEscrow = sessionData['escrowStatus'] as String? ?? '';
      final sessionLearnerId = sessionData['learnerId'] as String? ?? '';
      final teacherId = sessionData['teacherId'] as String? ?? '';
      final courseName = sessionData['courseName'] as String? ?? '';

      if (sessionLearnerId != learnerId) {
        throw Exception('المتعلّم صاحب الجلسة فقط هو المخوّل بتأكيد الإتمام');
      }

      if (currentEscrow != 'held') {
        throw Exception('تمت معالجة ضمان هذه الجلسة مسبقاً (الحالة: $currentEscrow)');
      }

      // 2. قراءة بيانات المعلّم وإضافة العملة لرصيده
      final teacherDocRef = firestore.collection('users').doc(teacherId);
      final teacherSnap = await transaction.get(teacherDocRef);
      if (!teacherSnap.exists) {
        throw Exception('حساب المعلم غير موجود');
      }

      final teacherData = teacherSnap.data()!;
      final teacherCoins = (teacherData['timeCoins'] as num?)?.toInt() ?? AppConstants.welcomeCoins;
      final completedSessions = (teacherData['completedSessions'] as num?)?.toInt() ?? 0;
      final currentRatingSum = (teacherData['ratingSum'] as num?)?.toInt() ?? 0;
      final currentRatingCount = (teacherData['ratingCount'] as num?)?.toInt() ?? 0;

      transaction.update(teacherDocRef, {
        'timeCoins': teacherCoins + AppConstants.sessionCostCoins,
        'completedSessions': completedSessions + 1,
        'ratingSum': currentRatingSum + rating,
        'ratingCount': currentRatingCount + 1,
        'lastSessionId': sessionId,
      });

      // 3. تحديث الجلسة كمنتهية ومحررة
      transaction.update(sessionDocRef, {
        'status': 'completed',
        'escrowStatus': 'released_to_teacher',
        'rating': rating,
        'reviewComment': reviewComment,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // 4. تسجيل حركة المحفظة للمعلم (+1 عملة)
      final txId = 'tx_${DateTime.now().millisecondsSinceEpoch}_release';
      final txDocRef = firestore.collection('transactions').doc(txId);
      final txData = WalletTransactionModel(
        id: txId,
        userId: teacherId,
        sessionId: sessionId,
        title: 'مكافأة شرح: $courseName',
        date: 'الآن',
        amount: AppConstants.sessionCostCoins,
        isNegative: false,
        type: 'session_earning',
        icon: Icons.volunteer_activism_outlined,
        createdAt: DateTime.now(),
      ).toMap();
      txData['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(txDocRef, txData);
    });
  }

  // =========================================================================
  // 3. إلغاء الجلسة وحسم مصير العملة وفقاً لقواعد الوقت (Cancellation Rules)
  // =========================================================================
  /// القواعد المعتمدة:
  /// - إذا ألغى المتعلّم قبل الموعد بـ > 2 ساعة: استرداد كامل للمتعلّم.
  /// - إذا ألغى المتعلّم قبل الموعد بـ <= 2 ساعة أو لم يحضر: تحوّل العملة للمعلم كتعويض.
  /// - إذا ألغى المعلم في أي وقت: استرداد كامل للمتعلّم.
  Future<void> cancelSessionWithEscrow({
    required String sessionId,
    required String cancellingUserId,
    required String reason,
    DateTime? currentTime,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw FirebaseException(
        plugin: 'firestore',
        message: 'Firebase Firestore is not initialized',
      );
    }

    final now = currentTime ?? DateTime.now();
    final sessionDocRef = firestore.collection('sessions').doc(sessionId);

    await firestore.runTransaction((transaction) async {
      final sessionSnap = await transaction.get(sessionDocRef);
      if (!sessionSnap.exists) {
        throw Exception('الجلسة غير موجودة');
      }

      final sessionData = sessionSnap.data()!;
      final currentEscrow = sessionData['escrowStatus'] as String? ?? '';
      final learnerId = sessionData['learnerId'] as String? ?? '';
      final teacherId = sessionData['teacherId'] as String? ?? '';
      final courseName = sessionData['courseName'] as String? ?? '';
      final scheduledAtRaw = sessionData['scheduledAt'];
      DateTime? scheduledAt;
      if (scheduledAtRaw is Timestamp) {
        scheduledAt = scheduledAtRaw.toDate();
      } else if (scheduledAtRaw is String) {
        scheduledAt = DateTime.tryParse(scheduledAtRaw);
      }

      if (currentEscrow != 'held') {
        throw Exception('تمت تسوية ضمان هذه الجلسة مسبقاً (الحالة: $currentEscrow)');
      }

      final isCancelledByTeacher = cancellingUserId == teacherId;
      final isCancelledByLearner = cancellingUserId == learnerId;

      if (!isCancelledByTeacher && !isCancelledByLearner) {
        throw Exception('أنت لست طرفاً في هذه الجلسة لإلغائها');
      }

      final learnerDocRef = firestore.collection('users').doc(learnerId);
      final teacherDocRef = firestore.collection('users').doc(teacherId);

      if (isCancelledByTeacher) {
        // --- 1. المعلم ألغى: استرداد كامل للمتعلّم ---
        final learnerSnap = await transaction.get(learnerDocRef);
        final learnerCoins = (learnerSnap.data()?['timeCoins'] as num?)?.toInt() ?? 0;

        transaction.update(learnerDocRef, {
          'timeCoins': learnerCoins + AppConstants.sessionCostCoins,
          'lastSessionId': sessionId,
        });

        transaction.update(sessionDocRef, {
          'status': 'cancelled_by_teacher',
          'escrowStatus': 'refunded_to_learner',
          'cancellationReason': reason,
          'cancelledBy': cancellingUserId,
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        final txId = 'tx_${now.millisecondsSinceEpoch}_refund';
        final txDocRef = firestore.collection('transactions').doc(txId);
        final txData = WalletTransactionModel(
          id: txId,
          userId: learnerId,
          sessionId: sessionId,
          title: 'استرداد عملة: إلغاء المعلم لجلسة $courseName',
          date: 'الآن',
          amount: AppConstants.sessionCostCoins,
          isNegative: false,
          type: 'cancellation_refund',
          icon: Icons.undo_rounded,
          createdAt: now,
        ).toMap();
        txData['createdAt'] = FieldValue.serverTimestamp();
        transaction.set(txDocRef, txData);
      } else {
        // --- 2. المتعلّم ألغى: فحص فارق الساعتين ---
        bool isMoreThan2Hours = true;
        if (scheduledAt != null) {
          final diffMinutes = scheduledAt.difference(now).inMinutes;
          isMoreThan2Hours = diffMinutes > 120;
        }

        if (isMoreThan2Hours) {
          // استرداد كامل للمتعلّم لإلغائه قبل أكثر من ساعتين
          final learnerSnap = await transaction.get(learnerDocRef);
          final learnerCoins = (learnerSnap.data()?['timeCoins'] as num?)?.toInt() ?? 0;

          transaction.update(learnerDocRef, {
            'timeCoins': learnerCoins + AppConstants.sessionCostCoins,
            'lastSessionId': sessionId,
          });

          transaction.update(sessionDocRef, {
            'status': 'cancelled_by_learner',
            'escrowStatus': 'refunded_to_learner',
            'cancellationReason': reason,
            'cancelledBy': cancellingUserId,
            'cancelledAt': FieldValue.serverTimestamp(),
          });

          final txId = 'tx_${now.millisecondsSinceEpoch}_refund';
          final txDocRef = firestore.collection('transactions').doc(txId);
          final txData = WalletTransactionModel(
            id: txId,
            userId: learnerId,
            sessionId: sessionId,
            title: 'استرداد عملة: إلغاء مبكر لجلسة $courseName',
            date: 'الآن',
            amount: AppConstants.sessionCostCoins,
            isNegative: false,
            type: 'cancellation_refund',
            icon: Icons.undo_rounded,
            createdAt: now,
          ).toMap();
          txData['createdAt'] = FieldValue.serverTimestamp();
          transaction.set(txDocRef, txData);
        } else {
          // إلغاء متأخر (أقل من ساعتين أو تخلف): العملة تذهب للمعلم تعويضاً عن وقته المحجوز
          final teacherSnap = await transaction.get(teacherDocRef);
          final teacherCoins = (teacherSnap.data()?['timeCoins'] as num?)?.toInt() ?? 0;

          transaction.update(teacherDocRef, {
            'timeCoins': teacherCoins + AppConstants.sessionCostCoins,
            'lastSessionId': sessionId,
          });

          transaction.update(sessionDocRef, {
            'status': 'cancelled_by_learner',
            'escrowStatus': 'released_to_teacher',
            'cancellationReason': reason.isEmpty ? 'إلغاء متأخر (أقل من ساعتين)' : reason,
            'cancelledBy': cancellingUserId,
            'cancelledAt': FieldValue.serverTimestamp(),
          });

          final txId = 'tx_${now.millisecondsSinceEpoch}_compensation';
          final txDocRef = firestore.collection('transactions').doc(txId);
          final txData = WalletTransactionModel(
            id: txId,
            userId: teacherId,
            sessionId: sessionId,
            title: 'تعويض إلغاء متأخر: $courseName',
            date: 'الآن',
            amount: AppConstants.sessionCostCoins,
            isNegative: false,
            type: 'late_compensation',
            icon: Icons.shield_outlined,
            createdAt: now,
          ).toMap();
          txData['createdAt'] = FieldValue.serverTimestamp();
          transaction.set(txDocRef, txData);
        }
      }
    });
  }

  // =========================================================================
  // 4. البث المباشر (Firestore Streams)
  // =========================================================================
  Stream<List<TimeBankSessionModel>> streamLearnerSessions(String userId) {
    final firestore = _firestore;
    if (firestore == null || userId.isEmpty) {
      return Stream.value([]);
    }

    return firestore
        .collection('sessions')
        .where('learnerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TimeBankSessionModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  Stream<List<TimeBankSessionModel>> streamTeacherSessions(String userId) {
    final firestore = _firestore;
    if (firestore == null || userId.isEmpty) {
      return Stream.value([]);
    }

    return firestore
        .collection('sessions')
        .where('teacherId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TimeBankSessionModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  Stream<List<TimeBankSessionModel>> streamUserSessions(String userId) {
    return streamLearnerSessions(userId);
  }

  Stream<List<TimeBankOfferModel>> streamUserOffers(String userId) {
    final firestore = _firestore;
    if (firestore == null || userId.isEmpty) {
      return Stream.value([]);
    }

    return firestore
        .collection('offers')
        .where('teacherId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TimeBankOfferModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  Stream<List<TimeBankOfferModel>> streamAvailableOffers() {
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.value([]);
    }

    return firestore
        .collection('offers')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TimeBankOfferModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  Stream<List<WalletTransactionModel>> streamUserTransactions(String userId) {
    final firestore = _firestore;
    if (firestore == null || userId.isEmpty) {
      return Stream.value([]);
    }

    return firestore
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => WalletTransactionModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  Future<void> createOffer(TimeBankOfferModel offer) async {
    final firestore = _firestore;
    if (firestore == null) return;
    await firestore.collection('offers').doc(offer.id).set(offer.toMap());
  }

  final Map<String, List<SessionMessageModel>> _localMessages = {};

  Stream<List<SessionMessageModel>> streamSessionMessages(String sessionId) {
    final firestore = _firestore;
    final cached = _localMessages[sessionId] ?? [];
    if (firestore == null || sessionId.isEmpty) {
      return Stream.value(cached);
    }
    return firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
      final remoteList = snapshot.docs
          .map((doc) => SessionMessageModel.fromMap(doc.data(), doc.id))
          .toList();
      final idSet = remoteList.map((m) => m.id).toSet();
      final merged = [...remoteList];
      for (final localMsg in (_localMessages[sessionId] ?? [])) {
        if (!idSet.contains(localMsg.id)) {
          merged.add(localMsg);
        }
      }
      merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return merged;
    }).handleError((error) {
      debugPrint('Firestore messages stream error (falling back to local): $error');
      return _localMessages[sessionId] ?? [];
    });
  }

  Future<void> sendSessionMessage(String sessionId, SessionMessageModel message) async {
    // 1. إضافة الرسالة فوراً في الذاكرة المحلية لتظهر في واجهة المستخدم لحظياً
    _localMessages.putIfAbsent(sessionId, () => []).add(message);

    final firestore = _firestore;
    if (firestore == null || sessionId.isEmpty) return;

    // 2. محاولة الحفظ في فايربيس
    try {
      await firestore
          .collection('sessions')
          .doc(sessionId)
          .collection('messages')
          .doc(message.id)
          .set(message.toMap());
    } catch (e) {
      debugPrint('Send session message error: $e');
      rethrow;
    }
  }

  Future<void> deleteOffer(String offerId) async {
    final firestore = _firestore;
    if (firestore == null || offerId.isEmpty) return;
    try {
      await firestore.collection('offers').doc(offerId).delete();
    } catch (e) {
      debugPrint('Delete offer error: $e');
    }
  }
}

final timeBankRepositoryProvider = Provider<TimeBankRepository>((ref) {
  return TimeBankRepository();
});

final learnerSessionsStreamProvider =
    StreamProvider.family<List<TimeBankSessionModel>, String>((ref, userId) {
  final repo = ref.watch(timeBankRepositoryProvider);
  return repo.streamLearnerSessions(userId);
});

final teacherSessionsStreamProvider =
    StreamProvider.family<List<TimeBankSessionModel>, String>((ref, userId) {
  final repo = ref.watch(timeBankRepositoryProvider);
  return repo.streamTeacherSessions(userId);
});

final userOffersStreamProvider =
    StreamProvider.family<List<TimeBankOfferModel>, String>((ref, userId) {
  final repo = ref.watch(timeBankRepositoryProvider);
  return repo.streamUserOffers(userId);
});

final availableOffersStreamProvider =
    StreamProvider<List<TimeBankOfferModel>>((ref) {
  final repo = ref.watch(timeBankRepositoryProvider);
  return repo.streamAvailableOffers();
});

final userTransactionsStreamProvider =
    StreamProvider.family<List<WalletTransactionModel>, String>((ref, userId) {
  final repo = ref.watch(timeBankRepositoryProvider);
  return repo.streamUserTransactions(userId);
});

final sessionMessagesStreamProvider =
    StreamProvider.family<List<SessionMessageModel>, String>((ref, sessionId) {
  final repo = ref.watch(timeBankRepositoryProvider);
  return repo.streamSessionMessages(sessionId);
});

final peerCandidatesProvider =
    Provider.family<List<TimeBankOfferModel>, CourseSeed?>((ref, targetCourse) {
  final user = ref.watch(authServiceProvider).currentUser;
  final currentUserId = user?.uid ?? '';

  final offersAsync = ref.watch(availableOffersStreamProvider);
  final rawOffers = offersAsync.value ?? [];

  // تصفية العروض المتاحة من مستندات offers الحقيقية فقط واستبعاد عروض المستخدم نفسه
  final directOffers = rawOffers.where((offer) {
    if (offer.teacherId == currentUserId) return false;
    if (targetCourse != null) {
      return offer.courseId == targetCourse.id ||
          offer.courseName.contains(targetCourse.name) ||
          targetCourse.name.contains(offer.courseName);
    }
    return true;
  }).toList();

  return directOffers;
});
