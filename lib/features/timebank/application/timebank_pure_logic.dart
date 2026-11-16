import '../../../core/models/app_models.dart';

/// النتيجة المترتبة على قرار إلغاء جلسة الضمان المالي
enum CancellationOutcome {
  fullRefundToLearner,
  compensationToTeacher,
}

/// موعد حقيقي متاح للحجز
class BookableSlot {
  final DateTime dateTime; // بتوقيت الجهاز المحلي (Africa/Cairo)
  final int durationMinutes; // 30 أو 60 دقيقة

  const BookableSlot({
    required this.dateTime,
    required this.durationMinutes,
  });

  DateTime get endDateTime => dateTime.add(Duration(minutes: durationMinutes));

  String get dateFormatted {
    final weekdayName = OfferTimeSlot.appWeekdayNames[(dateTime.weekday + 1) % 7] ?? '';
    return '$weekdayName ${dateTime.day}/${dateTime.month}';
  }

  String get timeFormatted {
    final startMin = dateTime.hour * 60 + dateTime.minute;
    final endMin = startMin + durationMinutes;
    return '${OfferTimeSlot.formatMinutes(startMin)} – ${OfferTimeSlot.formatMinutes(endMin)}';
  }
}

/// كائن يمثل تفاصيل قرار الإلغاء
class CancellationDecision {
  final CancellationOutcome outcome;
  final String newStatus;
  final String newEscrowStatus;
  final int refundedLearnerCoins;
  final int compensatedTeacherCoins;

  const CancellationDecision({
    required this.outcome,
    required this.newStatus,
    required this.newEscrowStatus,
    required this.refundedLearnerCoins,
    required this.compensatedTeacherCoins,
  });
}

/// نتيجة تجميع وتحديث تقييم المعلم
class RatingAggregationResult {
  final int newRatingSum;
  final int newRatingCount;
  final double averageRating;

  const RatingAggregationResult({
    required this.newRatingSum,
    required this.newRatingCount,
    required this.averageRating,
  });
}

/// المنطق الصافي الخالص (Pure Domain Logic) لنظام الضمان وبنك الوقت
/// دوال حتمية تماماً وقابلة للاختبار مع دعم حقن الساعة الزمنية (Injectable Clock)
class TimeBankPureLogic {
  /// دالة الساعة الافتراضية
  static DateTime defaultClock() => DateTime.now();

  /// 1. قرار إلغاء الجلسة مع إمكانية حقن الساعة (Injectable Clock)
  /// - إلغاء المعلم: استرداد كامل للعملة للمتعلم في أي وقت.
  /// - إلغاء المتعلم قبل قبول المعلم (حالة pending): استرداد كامل للمتعلم في أي وقت.
  /// - إلغاء المتعلم بعد التأكيد (confirmed) قبل الموعد بأكثر من ساعتين (> 2h): استرداد كامل للمتعلم.
  /// - إلغاء المتعلم بعد التأكيد (confirmed) قبل الموعد بساعتين أو أقل (<= 2h): تذهب العملة للمعلم كتعويض.
  static CancellationDecision decideCancellation({
    required String cancellingUserId,
    required String learnerId,
    required String teacherId,
    required DateTime scheduledAt,
    required int costCoins,
    String sessionStatus = 'confirmed',
    DateTime Function()? clock,
  }) {
    if (cancellingUserId != learnerId && cancellingUserId != teacherId) {
      throw ArgumentError('cancellingUserId must be either learnerId or teacherId');
    }

    final isTeacher = cancellingUserId == teacherId;
    if (isTeacher) {
      return CancellationDecision(
        outcome: CancellationOutcome.fullRefundToLearner,
        newStatus: 'cancelled_by_teacher',
        newEscrowStatus: 'refunded_to_learner',
        refundedLearnerCoins: costCoins,
        compensatedTeacherCoins: 0,
      );
    }

    // إذا كانت الجلسة معلقة قيد انتظار قبول الشارح (pending)، يحق للمتعلم الإلغاء في أي وقت باسترداد كامل
    if (sessionStatus == 'pending') {
      return CancellationDecision(
        outcome: CancellationOutcome.fullRefundToLearner,
        newStatus: 'cancelled_by_learner',
        newEscrowStatus: 'refunded_to_learner',
        refundedLearnerCoins: costCoins,
        compensatedTeacherCoins: 0,
      );
    }

    final now = (clock ?? defaultClock)();
    final difference = scheduledAt.difference(now);

    if (difference > const Duration(hours: 2)) {
      return CancellationDecision(
        outcome: CancellationOutcome.fullRefundToLearner,
        newStatus: 'cancelled_by_learner',
        newEscrowStatus: 'refunded_to_learner',
        refundedLearnerCoins: costCoins,
        compensatedTeacherCoins: 0,
      );
    } else {
      return CancellationDecision(
        outcome: CancellationOutcome.compensationToTeacher,
        newStatus: 'cancelled_by_learner',
        newEscrowStatus: 'released_to_teacher',
        refundedLearnerCoins: 0,
        compensatedTeacherCoins: costCoins,
      );
    }
  }

  /// 2. تجميع وتحديث التقييم (Rating Aggregation)
  /// التقييم عبارة عن رقم صحيح بين 1 و 5.
  /// يتم زيادة عداد التقييمات بمقدار 1 ومجموع التقييمات بقيمة التقييم.
  static RatingAggregationResult aggregateRating({
    required int currentRatingSum,
    required int currentRatingCount,
    required int sessionRating,
  }) {
    if (sessionRating < 1 || sessionRating > 5) {
      throw ArgumentError.value(sessionRating, 'sessionRating', 'Rating must be an integer between 1 and 5');
    }
    if (currentRatingSum < 0 || currentRatingCount < 0) {
      throw ArgumentError('Rating sum and count must be non-negative');
    }

    final newSum = currentRatingSum + sessionRating;
    final newCount = currentRatingCount + 1;
    final average = newSum / newCount;

    return RatingAggregationResult(
      newRatingSum: newSum,
      newRatingCount: newCount,
      averageRating: average,
    );
  }

  /// حساب متوسط التقييم بناءً على المجموع والعدد (مع قيمة افتراضية 5.0 إن لم تكن هناك تقييمات)
  static double computeAverageRating({
    required int ratingSum,
    required int ratingCount,
    double defaultRating = 5.0,
  }) {
    if (ratingCount <= 0) return defaultRating;
    return ratingSum / ratingCount;
  }

  /// 3. التحقق من صحة التحولات بين حالات الجلسة (Transition Validation)
  /// التحقق من صلاحية الحجز
  static void validateBookingTransition({
    required int learnerCoins,
    required int costCoins,
    required String? currentEscrowStatus,
  }) {
    if (costCoins <= 0) {
      throw StateError('Cost coins must be positive');
    }
    if (learnerCoins < costCoins) {
      throw StateError('Insufficient balance to book session (required: $costCoins, available: $learnerCoins)');
    }
    if (currentEscrowStatus != null && currentEscrowStatus.isNotEmpty) {
      throw StateError('Cannot book a session that already has an escrow status: $currentEscrowStatus');
    }
  }

  /// التحقق من صلاحية إتمام الجلسة وإطلاق الضمان
  static void validateCompletionTransition({
    required String currentEscrowStatus,
    required String currentStatus,
    required int rating,
    DateTime? scheduledAt,
    DateTime Function()? clock,
  }) {
    if (currentEscrowStatus != 'held') {
      throw StateError('Cannot complete a session whose escrow status is not held (current: $currentEscrowStatus)');
    }
    if (currentStatus != 'confirmed') {
      throw StateError('Cannot complete a session that is not confirmed (current: $currentStatus)');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError.value(rating, 'rating', 'Completion rating must be an integer between 1 and 5');
    }
    if (scheduledAt != null) {
      final now = (clock ?? defaultClock)();
      if (now.isBefore(scheduledAt)) {
        throw StateError('Cannot complete a session before its scheduled time');
      }
    }
  }

  /// التحقق من صلاحية إلغاء الجلسة
  static void validateCancellationTransition({
    required String currentEscrowStatus,
    required String currentStatus,
  }) {
    if (currentEscrowStatus != 'held') {
      throw StateError('Cannot cancel a session whose escrow status is not held (current: $currentEscrowStatus)');
    }
    if (currentStatus != 'confirmed' && currentStatus != 'pending') {
      throw StateError('Cannot cancel a session that is neither confirmed nor pending (current: $currentStatus)');
    }
  }

  /// التحقق من صلاحية قبول المعلم للجلسة
  static void validateAcceptanceTransition({
    required String currentStatus,
    required String currentEscrowStatus,
  }) {
    if (currentEscrowStatus != 'held') {
      throw StateError('Cannot accept a session whose escrow status is not held (current: $currentEscrowStatus)');
    }
    if (currentStatus != 'pending') {
      throw StateError('Cannot accept a session that is not in pending status (current: $currentStatus)');
    }
  }

  /// التحقق من صلاحية رفض المعلم للجلسة
  static void validateRejectionTransition({
    required String currentStatus,
    required String currentEscrowStatus,
  }) {
    if (currentEscrowStatus != 'held') {
      throw StateError('Cannot reject a session whose escrow status is not held (current: $currentEscrowStatus)');
    }
    if (currentStatus != 'pending') {
      throw StateError('Cannot reject a session that is not in pending status (current: $currentStatus)');
    }
  }

  /// 3-أ. قرار أحقية المتعلم في استرداد العملة لانتهاء مهلة الرد (Expired Refund Decision)
  static bool canLearnerClaimExpiredRefund({
    required String status,
    required String escrowStatus,
    required DateTime createdAt,
    DateTime? scheduledAt,
    DateTime Function()? clock,
  }) {
    if (status != 'pending' || escrowStatus != 'held') return false;
    final now = (clock ?? defaultClock)();
    final isAfter24h = now.difference(createdAt) > const Duration(hours: 24);
    final isPastScheduled = scheduledAt != null && now.isAfter(scheduledAt);
    return isAfter24h || isPastScheduled;
  }

  /// 3-ب. قرار أحقية المعلم في المطالبة التلقائية بالعملة بعد 48 ساعة من الموعد (Auto Release Decision)
  static bool canTeacherClaimAutoRelease({
    required String status,
    required String escrowStatus,
    required DateTime? teacherMarkedDoneAt,
    required DateTime? scheduledAt,
    DateTime Function()? clock,
  }) {
    if (status != 'confirmed' || escrowStatus != 'held') return false;
    if (teacherMarkedDoneAt == null || scheduledAt == null) return false;
    final now = (clock ?? defaultClock)();
    return now.difference(scheduledAt) > const Duration(hours: 48);
  }

  /// 3-ج. قرار إمكانية فتح نزاع من قِبل المتعلم (Dispute Eligibility)
  static bool canLearnerOpenDispute({
    required String status,
    required String escrowStatus,
    required DateTime? teacherMarkedDoneAt,
  }) {
    return status == 'confirmed' && escrowStatus == 'held' && teacherMarkedDoneAt != null;
  }

  /// 4. دوال مطابقة المواعيد وحساب التعارض (Slot Generation & Collision Filtering)
  /// تحويل صيغة الوقت النصية (مثل "09:00 ص" أو "01:30 م") إلى دقائق من منتصف الليل
  static int parseTimeToMinutes(String timeStr) {
    try {
      final clean = timeStr.trim().replaceAll('–', '-').replaceAll('—', '-');
      final isPM = clean.contains('م') || clean.toUpperCase().contains('PM');
      final digits = clean.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = digits.split(':');
      if (parts.isEmpty) return 540;
      var hour = int.tryParse(parts[0]) ?? 9;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      if (isPM && hour < 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      return hour * 60 + minute;
    } catch (_) {
      return 540;
    }
  }

  /// فحص التصادم بين فترتين زمنيتين في نفس اليوم
  static bool hasTimeCollision({
    required int start1,
    required int end1,
    required int start2,
    required int end2,
  }) {
    return start1 < end2 && end1 > start2;
  }

  /// فحص تعارض فترة محددة مع محاضرات أو جلسات مذاكرة الطالب المتعلم
  static bool isSlotConflictingWithLearner({
    required String dayName,
    required int slotStartMin,
    required int slotEndMin,
    required List<ScheduleItemModel> learnerLectures,
    required List<StudyBlockModel> learnerStudyBlocks,
  }) {
    // 1. فحص التعارض مع المحاضرات
    for (final lec in learnerLectures) {
      if (lec.day == dayName) {
        final lStart = parseTimeToMinutes(lec.startTime);
        final lEnd = parseTimeToMinutes(lec.endTime);
        if (hasTimeCollision(start1: slotStartMin, end1: slotEndMin, start2: lStart, end2: lEnd)) {
          return true;
        }
      }
    }

    // 2. فحص التعارض مع كتل المذاكرة
    for (final block in learnerStudyBlocks) {
      if (block.day == dayName) {
        final bStart = parseTimeToMinutes(block.startTime);
        final bEnd = parseTimeToMinutes(block.endTime);
        if (hasTimeCollision(start1: slotStartMin, end1: slotEndMin, start2: bStart, end2: bEnd)) {
          return true;
        }
      }
    }

    return false;
  }

  /// توليد المواعيد الحقيقية المتاحة للحجز (Concrete Bookable Slots)
  /// بين ساعتين و 14 يوماً من الآن مع استبعاد أي تعارض مع جدول المتعلم
  static List<BookableSlot> generateBookableSlots({
    required List<OfferTimeSlot> teacherSlots,
    required int durationMinutes,
    required List<ScheduleItemModel> learnerLectures,
    required List<StudyBlockModel> learnerStudyBlocks,
    DateTime Function()? clock,
  }) {
    final List<BookableSlot> slots = [];
    if (teacherSlots.isEmpty) return slots;

    final now = (clock ?? defaultClock)();
    final minTime = now.add(const Duration(hours: 2));
    final maxTime = now.add(const Duration(days: 14));

    // فحص الأيام من اليوم وحتى 14 يوماً
    for (int dayOffset = 0; dayOffset <= 14; dayOffset++) {
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: dayOffset));
      final appWeekday = (date.weekday + 1) % 7;
      final dayName = OfferTimeSlot.appWeekdayNames[appWeekday] ?? '';

      final matchingTeacherSlots = teacherSlots.where((s) => s.weekday == appWeekday);

      for (final tSlot in matchingTeacherSlots) {
        // خطوات كل 30 دقيقة
        for (int m = tSlot.startMin; m + durationMinutes <= tSlot.endMin; m += 30) {
          final slotStart = DateTime(date.year, date.month, date.day, m ~/ 60, m % 60);
          final slotEnd = slotStart.add(Duration(minutes: durationMinutes));

          // التحقق من نافذة الوقت: بين 2 ساعة و 14 يوماً
          if (slotStart.isBefore(minTime) || slotEnd.isAfter(maxTime)) {
            continue;
          }

          // التحقق من عدم التعارض مع محاضرات وكتل مذاكرة المتعلم
          final hasConflict = isSlotConflictingWithLearner(
            dayName: dayName,
            slotStartMin: m,
            slotEndMin: m + durationMinutes,
            learnerLectures: learnerLectures,
            learnerStudyBlocks: learnerStudyBlocks,
          );

          if (!hasConflict) {
            slots.add(BookableSlot(
              dateTime: slotStart,
              durationMinutes: durationMinutes,
            ));
          }
        }
      }
    }

    // ترتيب المواعيد تصاعدياً
    slots.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return slots;
  }

  /// 7. حساب البدايات الزمنية (Epoch Milliseconds) لكل شريحة 30 دقيقة تغطيها الجلسة
  static List<int> getSessionSlotEpochs({
    required DateTime scheduledAt,
    required int durationMinutes,
  }) {
    final baseMs = scheduledAt.millisecondsSinceEpoch;
    final numSlots = (durationMinutes / 30).ceil();
    final epochs = <int>[];
    for (var i = 0; i < numSlots; i++) {
      epochs.add(baseMs + (i * 30 * 60 * 1000));
    }
    return epochs;
  }

  /// 8. توليد معرفات أقفال المواعيد (Slot Locks IDs) للطرفين (المتعلم والمعلم)
  /// بصيغة حتمية: {uid}_{startEpochMs}
  static List<String> getLockDocIds({
    required String learnerId,
    required String teacherId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) {
    final epochs = getSessionSlotEpochs(
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
    );
    final ids = <String>[];
    for (final epoch in epochs) {
      ids.add('${learnerId}_$epoch');
      ids.add('${teacherId}_$epoch');
    }
    return ids;
  }

  /// 9. التحقق مما إذا كان أي من مستندات الأقفال نشطاً (status == 'active')
  static bool hasActiveLock(Iterable<Map<String, dynamic>?> lockDataList) {
    for (final data in lockDataList) {
      if (data != null && data['status'] == 'active') {
        return true;
      }
    }
    return false;
  }

  /// 10. حساب العملات المحتجزة في الضمان للمتعلم (Held Coins)
  /// للجلسات ذات الحالة 'pending' أو 'confirmed' أو 'disputed' مع حالة ضمان 'held'
  static int calculateHeldCoins(List<TimeBankSessionModel> learnerSessions) {
    return learnerSessions
        .where((s) =>
            s.escrowStatus == 'held' &&
            (s.status == 'pending' || s.status == 'confirmed' || s.status == 'disputed'))
        .fold<int>(0, (sum, s) => sum + s.costCoins);
  }
}
