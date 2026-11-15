/// النتيجة المترتبة على قرار إلغاء جلسة الضمان المالي
enum CancellationOutcome {
  fullRefundToLearner,
  compensationToTeacher,
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
  /// - إلغاء المتعلم قبل الموعد بأكثر من ساعتين (> 2h): استرداد كامل للمتعلم.
  /// - إلغاء المتعلم قبل الموعد بساعتين أو أقل (<= 2h): تذهب العملة للمعلم كتعويض.
  static CancellationDecision decideCancellation({
    required String cancellingUserId,
    required String learnerId,
    required String teacherId,
    required DateTime scheduledAt,
    required int costCoins,
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
  }

  /// التحقق من صلاحية إلغاء الجلسة
  static void validateCancellationTransition({
    required String currentEscrowStatus,
    required String currentStatus,
  }) {
    if (currentEscrowStatus != 'held') {
      throw StateError('Cannot cancel a session whose escrow status is not held (current: $currentEscrowStatus)');
    }
    if (currentStatus != 'confirmed') {
      throw StateError('Cannot cancel a session that is not confirmed (current: $currentStatus)');
    }
  }
}
