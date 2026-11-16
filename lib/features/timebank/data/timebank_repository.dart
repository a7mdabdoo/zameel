// مطور 1
// مستودع بنك الوقت والتعاملات الذرية ونظام الضمان (Escrow & TimeBank Repository)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_models.dart';
import '../../auth/data/auth_service.dart';
import '../application/timebank_pure_logic.dart';

class TimeBankRepository {
  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (e) {
      debugPrint('TimeBankRepository: Failed to get FirebaseFirestore instance: $e');
    }
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
    final txId = '${session.id}_booking';
    final txDocRef = firestore.collection('transactions').doc(txId);

    await firestore.runTransaction((transaction) async {
      // 1. قراءة بيانات المتعلّم للتحقق من الرصيد
      final learnerSnap = await transaction.get(learnerDocRef);
      if (!learnerSnap.exists) {
        throw Exception('حساب المتعلّم غير موجود');
      }

      final currentCoins = (learnerSnap.data()?['timeCoins'] as num?)?.toInt() ?? 0;
      TimeBankPureLogic.validateBookingTransition(
        learnerCoins: currentCoins,
        costCoins: AppConstants.sessionCostCoins,
        currentEscrowStatus: null,
      );

      // 2. قراءة أقفال المواعيد المزدوجة (Slot Locks) للتحقق من خلوها
      final lockIds = session.scheduledAt != null
          ? TimeBankPureLogic.getLockDocIds(
              learnerId: session.learnerId,
              teacherId: session.teacherId,
              scheduledAt: session.scheduledAt!,
              durationMinutes: session.durationMinutes,
            )
          : <String>[];

      final lockSnaps = <DocumentSnapshot>[];
      for (final lockId in lockIds) {
        final lockRef = firestore.collection('slotLocks').doc(lockId);
        final snap = await transaction.get(lockRef);
        lockSnaps.add(snap);
      }

      if (TimeBankPureLogic.hasActiveLock(
        lockSnaps.where((s) => s.exists).map((s) => s.data() as Map<String, dynamic>?),
      )) {
        throw Exception('عفواً، هذا الموعد محجوز بالفعل أو يوجد تعارض في جدولك أو جدول المعلم');
      }

      // 3. خصم العملة وتحديث رصيد المتعلّم مع ربط الجلسة
      final updatedCoins = currentCoins - AppConstants.sessionCostCoins;
      transaction.update(learnerDocRef, {
        'timeCoins': updatedCoins,
        'lastSessionId': session.id,
      });

      // 4. إنشاء مستند الجلسة مع حالة ضمان معلّق (Escrow Held) وبانتظار موافقة الشارح (pending)
      final sessionData = session.toMap();
      sessionData['costCoins'] = AppConstants.sessionCostCoins;
      sessionData['escrowStatus'] = 'held';
      sessionData['status'] = 'pending';
      sessionData['createdAt'] = FieldValue.serverTimestamp();
      if (session.scheduledAt != null) {
        sessionData['scheduledAt'] = Timestamp.fromDate(session.scheduledAt!);
      }
      transaction.set(sessionDocRef, sessionData);

      // 5. تسجيل حركة المحفظة (خصم للضمان)
      final txData = WalletTransactionModel(
        id: txId,
        userId: session.learnerId,
        sessionId: session.id,
        title: 'حجز جلسة ${session.courseName} (في الضمان)',
        date: 'الآن',
        amount: AppConstants.sessionCostCoins,
        isNegative: true,
        type: 'booking',
        icon: Icons.lock_clock_outlined,
        createdAt: DateTime.now(),
      ).toMap();
      txData['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(txDocRef, txData);

      // 6. إنشاء أقفال المواعيد (Slot Locks)
      if (session.scheduledAt != null) {
        final slotEpochs = TimeBankPureLogic.getSessionSlotEpochs(
          scheduledAt: session.scheduledAt!,
          durationMinutes: session.durationMinutes,
        );
        for (final epoch in slotEpochs) {
          final learnerLockRef = firestore.collection('slotLocks').doc('${session.learnerId}_$epoch');
          final teacherLockRef = firestore.collection('slotLocks').doc('${session.teacherId}_$epoch');

          transaction.set(learnerLockRef, {
            'uid': session.learnerId,
            'slotEpochMs': epoch,
            'sessionId': session.id,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          });

          transaction.set(teacherLockRef, {
            'uid': session.teacherId,
            'slotEpochMs': epoch,
            'sessionId': session.id,
            'status': 'active',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });

    return session.copyWith(
      status: 'pending',
      escrowStatus: 'held',
    );
  }

  // =========================================================================
  // 1-أ. قبول المعلم للجلسة المحجوزة (Accept Session: pending -> confirmed)
  // =========================================================================
  Future<void> acceptSession({
    required String sessionId,
    required String teacherId,
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
      final snap = await transaction.get(sessionDocRef);
      if (!snap.exists) {
        throw Exception('الجلسة غير موجودة');
      }

      final data = snap.data()!;
      final currentTeacherId = data['teacherId'] as String? ?? '';
      final currentStatus = data['status'] as String? ?? '';
      final currentEscrow = data['escrowStatus'] as String? ?? '';

      if (currentTeacherId != teacherId) {
        throw Exception('الشارح صاحب الجلسة فقط هو المخول بقبول الطلب');
      }

      TimeBankPureLogic.validateAcceptanceTransition(
        currentStatus: currentStatus,
        currentEscrowStatus: currentEscrow,
      );

      transaction.update(sessionDocRef, {
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // =========================================================================
  // 1-ب. اعتذار/رفض المعلم للجلسة المحجوزة (Reject Session: pending -> rejected)
  // مع استرداد كامل للعملة في محفظة المتعلم
  // =========================================================================
  Future<void> rejectSession({
    required String sessionId,
    required String teacherId,
    required String reason,
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
      final sessionSnap = await transaction.get(sessionDocRef);
      if (!sessionSnap.exists) {
        throw Exception('الجلسة غير موجودة');
      }

      final sessionData = sessionSnap.data()!;
      final currentTeacherId = sessionData['teacherId'] as String? ?? '';
      final currentStatus = sessionData['status'] as String? ?? '';
      final currentEscrow = sessionData['escrowStatus'] as String? ?? '';

      if (currentTeacherId != teacherId) {
        throw Exception('الشارح صاحب الجلسة فقط هو المخول برفض الطلب');
      }

      TimeBankPureLogic.validateRejectionTransition(
        currentStatus: currentStatus,
        currentEscrowStatus: currentEscrow,
      );

      final learnerId = sessionData['learnerId'] as String? ?? '';
      final courseName = sessionData['courseName'] as String? ?? '';
      final costCoins = (sessionData['costCoins'] as num?)?.toInt() ?? AppConstants.sessionCostCoins;
      final durationMinutes = (sessionData['durationMinutes'] as num?)?.toInt() ?? 60;
      final scheduledAtRaw = sessionData['scheduledAt'];
      DateTime? scheduledAt;
      if (scheduledAtRaw is Timestamp) {
        scheduledAt = scheduledAtRaw.toDate();
      } else if (scheduledAtRaw is String) {
        scheduledAt = DateTime.tryParse(scheduledAtRaw);
      }

      final learnerDocRef = firestore.collection('users').doc(learnerId);
      final learnerSnap = await transaction.get(learnerDocRef);
      if (!learnerSnap.exists) {
        throw Exception('حساب المتعلم غير موجود');
      }
      final learnerCoins = (learnerSnap.data()?['timeCoins'] as num?)?.toInt() ?? 0;

      // قراءة أقفال المواعيد إن وجدت لإطلاقها
      final existingLockRefs = <DocumentReference>[];
      if (scheduledAt != null) {
        final lockIds = TimeBankPureLogic.getLockDocIds(
          learnerId: learnerId,
          teacherId: teacherId,
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
        );
        for (final id in lockIds) {
          final ref = firestore.collection('slotLocks').doc(id);
          final snap = await transaction.get(ref);
          if (snap.exists) {
            existingLockRefs.add(ref);
          }
        }
      }

      // 1. إعادة العملة للمتعلم
      transaction.update(learnerDocRef, {
        'timeCoins': learnerCoins + costCoins,
        'lastSessionId': sessionId,
      });

      // 2. تحديث الجلسة كمرفوضة ومستردة
      transaction.update(sessionDocRef, {
        'status': 'rejected',
        'escrowStatus': 'refunded_to_learner',
        'rejectionReason': reason.isEmpty ? 'اعتذار من قِبل الزميل الشارح' : reason,
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // 3. قيد حركة الاسترداد في سجل الحركات المحاسبي
      final txId = '${sessionId}_refund';
      final txDocRef = firestore.collection('transactions').doc(txId);
      final txData = WalletTransactionModel(
        id: txId,
        userId: learnerId,
        sessionId: sessionId,
        title: 'استرداد عملة: اعتذار الشارح عن جلسة $courseName',
        date: 'الآن',
        amount: costCoins,
        isNegative: false,
        type: 'refund',
        icon: Icons.undo_rounded,
        createdAt: DateTime.now(),
      ).toMap();
      txData['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(txDocRef, txData);

      // 4. إطلاق أقفال المواعيد (released)
      for (final ref in existingLockRefs) {
        transaction.update(ref, {
          'status': 'released',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // =========================================================================
  // 1-ج. تسجيل المعلم "تم الشرح" بعد حلول الموعد (teacherMarkedDoneAt)
  // =========================================================================
  Future<void> markSessionDoneByTeacher({
    required String sessionId,
    required String teacherId,
    DateTime? currentTime,
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
      final snap = await transaction.get(sessionDocRef);
      if (!snap.exists) throw Exception('الجلسة غير موجودة');

      final data = snap.data()!;
      if (data['teacherId'] != teacherId) {
        throw Exception('الشارح صاحب الجلسة فقط هو المخول بتأكيد تقديم الشرح');
      }
      if (data['status'] != 'confirmed') {
        throw Exception('يجب أن تكون الجلسة مؤكدة لتسجيل إتمام الشرح');
      }
      if (data['escrowStatus'] != 'held') {
        throw Exception('الضمان غير معلق لهذه الجلسة');
      }

      final scheduledAtRaw = data['scheduledAt'];
      DateTime? scheduledAt;
      if (scheduledAtRaw is Timestamp) {
        scheduledAt = scheduledAtRaw.toDate();
      } else if (scheduledAtRaw is String) {
        scheduledAt = DateTime.tryParse(scheduledAtRaw);
      }

      final now = currentTime ?? DateTime.now();
      if (scheduledAt != null && now.isBefore(scheduledAt)) {
        throw Exception('لا يمكنك تسجيل "تم الشرح" إلا بعد حلول موعد الجلسة المحدد');
      }

      transaction.update(sessionDocRef, {
        'teacherMarkedDoneAt': FieldValue.serverTimestamp(),
      });
    });
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

      final scheduledAtRaw = sessionData['scheduledAt'];
      DateTime? scheduledAt;
      if (scheduledAtRaw is Timestamp) {
        scheduledAt = scheduledAtRaw.toDate();
      } else if (scheduledAtRaw is String) {
        scheduledAt = DateTime.tryParse(scheduledAtRaw);
      }

      final currentStatus = sessionSnap.data()?['status'] as String? ?? 'confirmed';
      TimeBankPureLogic.validateCompletionTransition(
        currentEscrowStatus: currentEscrow,
        currentStatus: currentStatus,
        rating: rating,
        scheduledAt: scheduledAt,
      );

      // 2. قراءة بيانات المعلّم وإضافة العملة لرصيده
      final teacherDocRef = firestore.collection('users').doc(teacherId);
      final teacherSnap = await transaction.get(teacherDocRef);
      if (!teacherSnap.exists) {
        throw Exception('حساب المعلم غير موجود');
      }

      // قراءة أقفال المواعيد إن وجدت لتحديثها كـ used
      final existingLockRefs = <DocumentReference>[];
      final durationMinutes = (sessionData['durationMinutes'] as num?)?.toInt() ?? 60;
      if (scheduledAt != null) {
        final lockIds = TimeBankPureLogic.getLockDocIds(
          learnerId: sessionLearnerId,
          teacherId: teacherId,
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
        );
        for (final id in lockIds) {
          final ref = firestore.collection('slotLocks').doc(id);
          final snap = await transaction.get(ref);
          if (snap.exists) {
            existingLockRefs.add(ref);
          }
        }
      }

      final teacherData = teacherSnap.data()!;
      final teacherCoins = (teacherData['timeCoins'] as num?)?.toInt() ?? AppConstants.welcomeCoins;
      final completedSessions = (teacherData['completedSessions'] as num?)?.toInt() ?? 0;
      final currentRatingSum = (teacherData['ratingSum'] as num?)?.toInt() ?? 0;
      final currentRatingCount = (teacherData['ratingCount'] as num?)?.toInt() ?? 0;

      final ratingResult = TimeBankPureLogic.aggregateRating(
        currentRatingSum: currentRatingSum,
        currentRatingCount: currentRatingCount,
        sessionRating: rating,
      );

      transaction.update(teacherDocRef, {
        'timeCoins': teacherCoins + AppConstants.sessionCostCoins,
        'completedSessions': completedSessions + 1,
        'ratingSum': ratingResult.newRatingSum,
        'ratingCount': ratingResult.newRatingCount,
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
      final txId = '${sessionId}_release';
      final txDocRef = firestore.collection('transactions').doc(txId);
      final txData = WalletTransactionModel(
        id: txId,
        userId: teacherId,
        sessionId: sessionId,
        title: 'مكافأة شرح: $courseName',
        date: 'الآن',
        amount: AppConstants.sessionCostCoins,
        isNegative: false,
        type: 'release',
        icon: Icons.volunteer_activism_outlined,
        createdAt: DateTime.now(),
      ).toMap();
      txData['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(txDocRef, txData);

      // 5. تحديث أقفال المواعيد إلى used
      for (final ref in existingLockRefs) {
        transaction.update(ref, {
          'status': 'used',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // =========================================================================
  // 2-أ. تحديث رابط الاجتماع للجلسة من قِبل المعلم (Update Meeting URL)
  // =========================================================================
  Future<void> updateSessionMeetingUrl({
    required String sessionId,
    required String teacherId,
    required String meetingUrl,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw FirebaseException(
        plugin: 'firestore',
        message: 'Firebase Firestore is not initialized',
      );
    }

    final trimmed = meetingUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != 'https') {
      throw Exception('رابط الاجتماع يجب أن يبدأ بـ https://');
    }
    final host = uri.host.toLowerCase();
    final allowed = host == 'meet.google.com' ||
        host == 'zoom.us' ||
        host.endsWith('.zoom.us') ||
        host == 'teams.microsoft.com';
    if (!allowed) {
      throw Exception('رابط الاجتماع يجب أن يكون من Google Meet أو Zoom أو Microsoft Teams');
    }

    await firestore.collection('sessions').doc(sessionId).update({
      'meetingUrl': trimmed,
      'meetingUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // =========================================================================
  // 2-ب. استرداد المتعلم عند انتهاء مهلة الرد (Expired Session Refund)
  // =========================================================================
  Future<void> claimExpiredSessionRefund({
    required String sessionId,
    required String learnerId,
    DateTime? currentTime,
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
      final sessionSnap = await transaction.get(sessionDocRef);
      if (!sessionSnap.exists) throw Exception('الجلسة غير موجودة');

      final sessionData = sessionSnap.data()!;
      final currentLearnerId = sessionData['learnerId'] as String? ?? '';
      final currentStatus = sessionData['status'] as String? ?? '';
      final currentEscrow = sessionData['escrowStatus'] as String? ?? '';
      final courseName = sessionData['courseName'] as String? ?? '';
      final costCoins = (sessionData['costCoins'] as num?)?.toInt() ?? AppConstants.sessionCostCoins;
      final teacherId = sessionData['teacherId'] as String? ?? '';
      final durationMinutes = (sessionData['durationMinutes'] as num?)?.toInt() ?? 60;

      if (currentLearnerId != learnerId) {
        throw Exception('المتعلم صاحب الجلسة فقط هو المخول بالمطالبة بالاسترداد');
      }

      DateTime? createdAt;
      final createdAtRaw = sessionData['createdAt'];
      if (createdAtRaw is Timestamp) {
        createdAt = createdAtRaw.toDate();
      } else if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw);
      }

      DateTime? scheduledAt;
      final scheduledAtRaw = sessionData['scheduledAt'];
      if (scheduledAtRaw is Timestamp) {
        scheduledAt = scheduledAtRaw.toDate();
      } else if (scheduledAtRaw is String) {
        scheduledAt = DateTime.tryParse(scheduledAtRaw);
      }

      final now = currentTime ?? DateTime.now();
      final isEligible = TimeBankPureLogic.canLearnerClaimExpiredRefund(
        status: currentStatus,
        escrowStatus: currentEscrow,
        createdAt: createdAt ?? now,
        scheduledAt: scheduledAt,
        clock: () => now,
      );

      if (!isEligible) {
        throw Exception('شروط استرداد العملة غير مستوفاة بعد (يجب مرور 24 ساعة على الطلب أو حلول موعد الجلسة)');
      }

      final learnerDocRef = firestore.collection('users').doc(learnerId);
      final learnerSnap = await transaction.get(learnerDocRef);
      final learnerCoins = (learnerSnap.data()?['timeCoins'] as num?)?.toInt() ?? 0;

      // قراءة الأقفال
      final existingLockRefs = <DocumentReference>[];
      if (scheduledAt != null) {
        final lockIds = TimeBankPureLogic.getLockDocIds(
          learnerId: learnerId,
          teacherId: teacherId,
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
        );
        for (final id in lockIds) {
          final ref = firestore.collection('slotLocks').doc(id);
          final snap = await transaction.get(ref);
          if (snap.exists) existingLockRefs.add(ref);
        }
      }

      // رد العملة للمتعلم
      transaction.update(learnerDocRef, {
        'timeCoins': learnerCoins + costCoins,
        'lastSessionId': sessionId,
      });

      // تحديث الجلسة
      transaction.update(sessionDocRef, {
        'status': 'expired',
        'escrowStatus': 'refunded_to_learner',
        'expiredAt': FieldValue.serverTimestamp(),
      });

      // قيد الاسترداد في سجل الحركات
      final txId = '${sessionId}_refund';
      final txDocRef = firestore.collection('transactions').doc(txId);
      final txData = WalletTransactionModel(
        id: txId,
        userId: learnerId,
        sessionId: sessionId,
        title: 'استرداد عملة: انتهاء مهلة الرد على طلب $courseName',
        date: 'الآن',
        amount: costCoins,
        isNegative: false,
        type: 'refund',
        icon: Icons.undo_rounded,
        createdAt: now,
      ).toMap();
      txData['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(txDocRef, txData);

      // إطلاق الأقفال
      for (final ref in existingLockRefs) {
        transaction.update(ref, {
          'status': 'released',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // =========================================================================
  // 2-ج. مطالبة المعلم التلقائية بالعملة بعد 48 ساعة وصمت المتعلم (Auto Release)
  // =========================================================================
  Future<void> claimTeacherAutoRelease({
    required String sessionId,
    required String teacherId,
    DateTime? currentTime,
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
      final sessionSnap = await transaction.get(sessionDocRef);
      if (!sessionSnap.exists) throw Exception('الجلسة غير موجودة');

      final sessionData = sessionSnap.data()!;
      final currentTeacherId = sessionData['teacherId'] as String? ?? '';
      final currentStatus = sessionData['status'] as String? ?? '';
      final currentEscrow = sessionData['escrowStatus'] as String? ?? '';
      final courseName = sessionData['courseName'] as String? ?? '';
      final learnerId = sessionData['learnerId'] as String? ?? '';
      final durationMinutes = (sessionData['durationMinutes'] as num?)?.toInt() ?? 60;

      if (currentTeacherId != teacherId) {
        throw Exception('الشارح صاحب الجلسة فقط هو المخول بالمطالبة بالعملة');
      }

      DateTime? scheduledAt;
      final scheduledAtRaw = sessionData['scheduledAt'];
      if (scheduledAtRaw is Timestamp) {
        scheduledAt = scheduledAtRaw.toDate();
      } else if (scheduledAtRaw is String) {
        scheduledAt = DateTime.tryParse(scheduledAtRaw);
      }

      DateTime? teacherMarkedDoneAt;
      final doneRaw = sessionData['teacherMarkedDoneAt'];
      if (doneRaw is Timestamp) {
        teacherMarkedDoneAt = doneRaw.toDate();
      } else if (doneRaw is String) {
        teacherMarkedDoneAt = DateTime.tryParse(doneRaw);
      }

      final now = currentTime ?? DateTime.now();
      final isEligible = TimeBankPureLogic.canTeacherClaimAutoRelease(
        status: currentStatus,
        escrowStatus: currentEscrow,
        teacherMarkedDoneAt: teacherMarkedDoneAt,
        scheduledAt: scheduledAt,
        clock: () => now,
      );

      if (!isEligible) {
        throw Exception('شروط التحرير التلقائي غير مستوفاة (يجب تسجيل "تم الشرح" ومرور 48 ساعة على موعد الجلسة دون نزاع)');
      }

      final teacherDocRef = firestore.collection('users').doc(teacherId);
      final teacherSnap = await transaction.get(teacherDocRef);
      final teacherCoins = (teacherSnap.data()?['timeCoins'] as num?)?.toInt() ?? 0;
      final completedSessions = (teacherSnap.data()?['completedSessions'] as num?)?.toInt() ?? 0;

      // قراءة الأقفال
      final existingLockRefs = <DocumentReference>[];
      if (scheduledAt != null) {
        final lockIds = TimeBankPureLogic.getLockDocIds(
          learnerId: learnerId,
          teacherId: teacherId,
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
        );
        for (final id in lockIds) {
          final ref = firestore.collection('slotLocks').doc(id);
          final snap = await transaction.get(ref);
          if (snap.exists) existingLockRefs.add(ref);
        }
      }

      // تحرير العملة للمعلم (بدون تعديل التقييم)
      transaction.update(teacherDocRef, {
        'timeCoins': teacherCoins + AppConstants.sessionCostCoins,
        'completedSessions': completedSessions + 1,
        'lastSessionId': sessionId,
      });

      // تحديث الجلسة كـ completed_auto
      transaction.update(sessionDocRef, {
        'status': 'completed_auto',
        'escrowStatus': 'released_to_teacher',
        'autoReleasedAt': FieldValue.serverTimestamp(),
      });

      // قيد حركة المحفظة للمعلم
      final txId = '${sessionId}_release';
      final txDocRef = firestore.collection('transactions').doc(txId);
      final txData = WalletTransactionModel(
        id: txId,
        userId: teacherId,
        sessionId: sessionId,
        title: 'تحرير تلقائي لمكافأة شرح: $courseName (بعد 48 ساعة)',
        date: 'الآن',
        amount: AppConstants.sessionCostCoins,
        isNegative: false,
        type: 'release',
        icon: Icons.volunteer_activism_outlined,
        createdAt: now,
      ).toMap();
      txData['createdAt'] = FieldValue.serverTimestamp();
      transaction.set(txDocRef, txData);

      // تحديث الأقفال كـ used
      for (final ref in existingLockRefs) {
        transaction.update(ref, {
          'status': 'used',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // =========================================================================
  // 2-د. فتح نزاع من قِبل المتعلم بعد قيام المعلم بتسجيل "تم الشرح" (Dispute)
  // =========================================================================
  Future<void> openSessionDispute({
    required String sessionId,
    required String learnerId,
    required String reason,
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
      final snap = await transaction.get(sessionDocRef);
      if (!snap.exists) throw Exception('الجلسة غير موجودة');

      final data = snap.data()!;
      final currentLearnerId = data['learnerId'] as String? ?? '';
      final currentStatus = data['status'] as String? ?? '';
      final currentEscrow = data['escrowStatus'] as String? ?? '';
      final doneRaw = data['teacherMarkedDoneAt'];

      if (currentLearnerId != learnerId) {
        throw Exception('المتعلم صاحب الجلسة فقط هو المخول بفتح نزاع');
      }

      DateTime? teacherMarkedDoneAt;
      if (doneRaw is Timestamp) {
        teacherMarkedDoneAt = doneRaw.toDate();
      } else if (doneRaw is String) {
        teacherMarkedDoneAt = DateTime.tryParse(doneRaw);
      }

      final isEligible = TimeBankPureLogic.canLearnerOpenDispute(
        status: currentStatus,
        escrowStatus: currentEscrow,
        teacherMarkedDoneAt: teacherMarkedDoneAt,
      );

      if (!isEligible) {
        throw Exception('لا يمكن فتح نزاع إلا بعد تسجيل المعلم "تم الشرح" في جلسة مؤكدة');
      }

      transaction.update(sessionDocRef, {
        'status': 'disputed',
        'disputeReason': reason.isEmpty ? 'اعتراض على تقديم الشرح' : reason,
        'disputedAt': FieldValue.serverTimestamp(),
      });
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

      final currentStatus = sessionData['status'] as String? ?? 'confirmed';
      TimeBankPureLogic.validateCancellationTransition(
        currentEscrowStatus: currentEscrow,
        currentStatus: currentStatus,
      );

      final decision = TimeBankPureLogic.decideCancellation(
        cancellingUserId: cancellingUserId,
        learnerId: learnerId,
        teacherId: teacherId,
        scheduledAt: scheduledAt ?? now.add(const Duration(hours: 3)),
        costCoins: AppConstants.sessionCostCoins,
        sessionStatus: currentStatus,
        clock: () => now,
      );

      final learnerDocRef = firestore.collection('users').doc(learnerId);
      final teacherDocRef = firestore.collection('users').doc(teacherId);

      // قراءة أقفال المواعيد إن وجدت لتحديثها كـ released أو used
      final existingLockRefs = <DocumentReference>[];
      final durationMinutes = (sessionData['durationMinutes'] as num?)?.toInt() ?? 60;
      if (scheduledAt != null) {
        final lockIds = TimeBankPureLogic.getLockDocIds(
          learnerId: learnerId,
          teacherId: teacherId,
          scheduledAt: scheduledAt,
          durationMinutes: durationMinutes,
        );
        for (final id in lockIds) {
          final ref = firestore.collection('slotLocks').doc(id);
          final snap = await transaction.get(ref);
          if (snap.exists) {
            existingLockRefs.add(ref);
          }
        }
      }

      if (decision.outcome == CancellationOutcome.fullRefundToLearner) {
        final learnerSnap = await transaction.get(learnerDocRef);
        final learnerCoins = (learnerSnap.data()?['timeCoins'] as num?)?.toInt() ?? 0;

        transaction.update(learnerDocRef, {
          'timeCoins': learnerCoins + decision.refundedLearnerCoins,
          'lastSessionId': sessionId,
        });

        transaction.update(sessionDocRef, {
          'status': decision.newStatus,
          'escrowStatus': decision.newEscrowStatus,
          'cancellationReason': reason,
          'cancelledBy': cancellingUserId,
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        final txId = '${sessionId}_refund';
        final txDocRef = firestore.collection('transactions').doc(txId);
        final txData = WalletTransactionModel(
          id: txId,
          userId: learnerId,
          sessionId: sessionId,
          title: cancellingUserId == teacherId
              ? 'استرداد عملة: إلغاء المعلم لجلسة $courseName'
              : 'استرداد عملة: إلغاء مبكر لجلسة $courseName',
          date: 'الآن',
          amount: decision.refundedLearnerCoins,
          isNegative: false,
          type: 'refund',
          icon: Icons.undo_rounded,
          createdAt: now,
        ).toMap();
        txData['createdAt'] = FieldValue.serverTimestamp();
        transaction.set(txDocRef, txData);

        // إطلاق أقفال المواعيد لتصبح متاحة مجدداً (released)
        for (final ref in existingLockRefs) {
          transaction.update(ref, {
            'status': 'released',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // إلغاء متأخر (أقل من ساعتين أو تخلف): العملة تذهب للمعلم تعويضاً عن وقته المحجوز
        final teacherSnap = await transaction.get(teacherDocRef);
        final teacherCoins = (teacherSnap.data()?['timeCoins'] as num?)?.toInt() ?? 0;

        transaction.update(teacherDocRef, {
          'timeCoins': teacherCoins + decision.compensatedTeacherCoins,
          'lastSessionId': sessionId,
        });

        transaction.update(sessionDocRef, {
          'status': decision.newStatus,
          'escrowStatus': decision.newEscrowStatus,
          'cancellationReason': reason.isEmpty ? 'إلغاء متأخر (أقل من ساعتين)' : reason,
          'cancelledBy': cancellingUserId,
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        final txId = '${sessionId}_compensation';
        final txDocRef = firestore.collection('transactions').doc(txId);
        final txData = WalletTransactionModel(
          id: txId,
          userId: teacherId,
          sessionId: sessionId,
          title: 'تعويض إلغاء متأخر: $courseName',
          date: 'الآن',
          amount: decision.compensatedTeacherCoins,
          isNegative: false,
          type: 'compensation',
          icon: Icons.shield_outlined,
          createdAt: now,
        ).toMap();
        txData['createdAt'] = FieldValue.serverTimestamp();
        transaction.set(txDocRef, txData);

        // تثبيت أقفال المواعيد كـ used
        for (final ref in existingLockRefs) {
          transaction.update(ref, {
            'status': 'used',
            'updatedAt': FieldValue.serverTimestamp(),
          });
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
      final list = <TimeBankOfferModel>[];
      for (final doc in snapshot.docs) {
        final offer = TimeBankOfferModel.fromMapSafe(doc.data(), doc.id);
        if (offer != null) {
          list.add(offer);
        }
      }
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
      final list = <TimeBankOfferModel>[];
      for (final doc in snapshot.docs) {
        final offer = TimeBankOfferModel.fromMapSafe(doc.data(), doc.id);
        if (offer != null) {
          list.add(offer);
        }
      }
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

  Stream<List<SessionMessageModel>> streamSessionMessages(String sessionId) {
    final firestore = _firestore;
    if (firestore == null || sessionId.isEmpty) {
      return Stream.value([]);
    }
    return firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SessionMessageModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  Future<void> sendSessionMessage(String sessionId, SessionMessageModel message) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw FirebaseException(
        plugin: 'firestore',
        message: 'Firebase Firestore is not initialized',
      );
    }
    if (sessionId.isEmpty) {
      throw ArgumentError('sessionId cannot be empty');
    }

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
    if (firestore == null || offerId.isEmpty) {
      throw FirebaseException(
        plugin: 'firestore',
        message: 'Firebase Firestore is not initialized or invalid offerId',
      );
    }
    try {
      await firestore.collection('offers').doc(offerId).delete();
    } catch (e) {
      debugPrint('Delete offer error: $e');
      rethrow;
    }
  }

  // =========================================================================
  // حفظ إتمام جلسة مذاكرة في قائمة الكتل المكتملة للمستخدم
  // ملاحظة: نقاط وساعات المذاكرة تشتق من completedBlockIds ولا تُكتب كعملات ولا كمعاملات
  // =========================================================================
  Future<bool> awardStudyPoint({
    required String userId,
    required String title,
    String? blockId,
    int points = 1,
  }) async {
    final firestore = _firestore;
    if (firestore == null || userId.isEmpty) return false;
    try {
      if (blockId != null && blockId.isNotEmpty) {
        final userDocRef = firestore.collection('users').doc(userId);
        await userDocRef.update({
          'completedBlockIds': FieldValue.arrayUnion([blockId]),
        });
      }
      return true;
    } catch (e) {
      debugPrint('awardStudyPoint error: $e');
      return false;
    }
  }

  // =========================================================================
  // التراجع عن إتمام جلسة مذاكرة وإلغاء تحديدها من completedBlockIds
  // =========================================================================
  Future<bool> revertStudyPoint({
    required String userId,
    required String blockId,
    int points = 1,
  }) async {
    final firestore = _firestore;
    if (firestore == null || userId.isEmpty) return false;
    try {
      final userDocRef = firestore.collection('users').doc(userId);
      await userDocRef.update({
        'completedBlockIds': FieldValue.arrayRemove([blockId]),
      });
      return true;
    } catch (e) {
      debugPrint('revertStudyPoint error: $e');
      return false;
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
