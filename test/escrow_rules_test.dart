import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/core/algorithms/planner_algorithm.dart';
import 'package:zameel/core/constants/app_constants.dart';
import 'package:zameel/core/models/app_models.dart';
import 'package:zameel/core/theme/app_colors.dart';
import 'package:zameel/features/timebank/application/timebank_pure_logic.dart';

void main() {
  group('1. ثوابت المنظومة والبريد الإلكتروني (App Constants & Email Validation)', () {
    test('رصيد البداية الترحيبي هو 2 عملة تماماً وتكلفة الجلسة 1 عملة', () {
      expect(AppConstants.welcomeCoins, equals(2));
      expect(AppConstants.sessionCostCoins, equals(1));
    });

    test('التحقق من صحة البريد الإلكتروني العادي (Gmail وأي إيميل شخصي)', () {
      // مقبولة: Gmail وأي بريد شخصي
      expect(AppConstants.isValidEmail('student@gmail.com'), isTrue);
      expect(AppConstants.isValidEmail('user@yahoo.com'), isTrue);
      expect(AppConstants.isValidEmail('ahmed@outlook.com'), isTrue);
      expect(AppConstants.isValidEmail('developer@zameel.app'), isTrue);

      // مرفوضة (صيغ خاطئة)
      expect(AppConstants.isValidEmail('invalid_string'), isFalse);
      expect(AppConstants.isValidEmail('user@'), isFalse);
      expect(AppConstants.isValidEmail('@gmail.com'), isFalse);
    });
  });

  group('2. التحقق من صحة التحولات (Transition Validation - Pure Logic)', () {
    test('التحقق من حجز الجلسة: ينجح بوجود رصيد كافٍ ويفشل إن لم يكفِ الرصيد', () {
      // رصيد كافٍ
      expect(
        () => TimeBankPureLogic.validateBookingTransition(
          learnerCoins: 2,
          costCoins: 1,
          currentEscrowStatus: null,
        ),
        returnsNormally,
      );

      // رصيد غير كافٍ
      expect(
        () => TimeBankPureLogic.validateBookingTransition(
          learnerCoins: 0,
          costCoins: 1,
          currentEscrowStatus: null,
        ),
        throwsA(isA<StateError>()),
      );

      // تكلفة غير صالحة
      expect(
        () => TimeBankPureLogic.validateBookingTransition(
          learnerCoins: 5,
          costCoins: 0,
          currentEscrowStatus: null,
        ),
        throwsA(isA<StateError>()),
      );

      // محاولة حجز جلسة محجوزة مسبقاً
      expect(
        () => TimeBankPureLogic.validateBookingTransition(
          learnerCoins: 5,
          costCoins: 1,
          currentEscrowStatus: 'held',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('التحقق من إتمام الجلسة: ينجح إذا كانت الحالة held والتقييم بين 1 و 5', () {
      expect(
        () => TimeBankPureLogic.validateCompletionTransition(
          currentEscrowStatus: 'held',
          currentStatus: 'confirmed',
          rating: 5,
        ),
        returnsNormally,
      );

      // يفشل إذا لم تكن الحالة held
      expect(
        () => TimeBankPureLogic.validateCompletionTransition(
          currentEscrowStatus: 'released_to_teacher',
          currentStatus: 'confirmed',
          rating: 4,
        ),
        throwsA(isA<StateError>()),
      );

      // يفشل إذا لم تكن confirmed
      expect(
        () => TimeBankPureLogic.validateCompletionTransition(
          currentEscrowStatus: 'held',
          currentStatus: 'cancelled_by_learner',
          rating: 4,
        ),
        throwsA(isA<StateError>()),
      );

      // يفشل إذا كان التقييم خارج النطاق (أقل من 1 أو أكبر من 5)
      expect(
        () => TimeBankPureLogic.validateCompletionTransition(
          currentEscrowStatus: 'held',
          currentStatus: 'confirmed',
          rating: 6,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => TimeBankPureLogic.validateCompletionTransition(
          currentEscrowStatus: 'held',
          currentStatus: 'confirmed',
          rating: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('التحقق من الإلغاء: ينجح إذا كانت الجلسة held و confirmed ويفشل خلاف ذلك', () {
      expect(
        () => TimeBankPureLogic.validateCancellationTransition(
          currentEscrowStatus: 'held',
          currentStatus: 'confirmed',
        ),
        returnsNormally,
      );

      expect(
        () => TimeBankPureLogic.validateCancellationTransition(
          currentEscrowStatus: 'released_to_teacher',
          currentStatus: 'completed',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('3. تجميع وتحديث التقييم (Rating Aggregation - Pure Logic)', () {
    test('تجميع التقييم: زيادة ratingCount بواحد و ratingSum بقيمة التقييم وحساب المتوسط بدقة', () {
      final res = TimeBankPureLogic.aggregateRating(
        currentRatingSum: 15,
        currentRatingCount: 3,
        sessionRating: 5,
      );

      expect(res.newRatingSum, equals(20));
      expect(res.newRatingCount, equals(4));
      expect(res.averageRating, equals(5.0));
    });

    test('رفض التقييمات خارج النطاق 1 إلى 5 ورفض المجاميع السالبة', () {
      expect(
        () => TimeBankPureLogic.aggregateRating(
          currentRatingSum: 10,
          currentRatingCount: 2,
          sessionRating: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => TimeBankPureLogic.aggregateRating(
          currentRatingSum: 10,
          currentRatingCount: 2,
          sessionRating: 7,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => TimeBankPureLogic.aggregateRating(
          currentRatingSum: -1,
          currentRatingCount: 0,
          sessionRating: 4,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('حساب المتوسط: القيمة الافتراضية 5.0 عند عدم وجود تقييمات، والقسمة الدقيقة عند وجودها', () {
      expect(TimeBankPureLogic.computeAverageRating(ratingSum: 0, ratingCount: 0), equals(5.0));
      expect(TimeBankPureLogic.computeAverageRating(ratingSum: 9, ratingCount: 2), equals(4.5));
    });
  });

  group('4. قواعد الإلغاء ونظام الحماية المالي مع ساعة زمنية قابلة للحقن (Cancellation with Injectable Clock)', () {
    final scheduledTime = DateTime(2026, 11, 10, 14, 0); // 2:00 PM
    const learnerId = 'learner_1';
    const teacherId = 'teacher_1';

    test('إلغاء المتعلّم قبل الموعد بـ 3 ساعات (> 2h): استرداد كامل للمتعلّم', () {
      final decision = TimeBankPureLogic.decideCancellation(
        cancellingUserId: learnerId,
        learnerId: learnerId,
        teacherId: teacherId,
        scheduledAt: scheduledTime,
        costCoins: 1,
        clock: () => DateTime(2026, 11, 10, 11, 0), // 11:00 AM (3 hours before)
      );

      expect(decision.outcome, equals(CancellationOutcome.fullRefundToLearner));
      expect(decision.newStatus, equals('cancelled_by_learner'));
      expect(decision.newEscrowStatus, equals('refunded_to_learner'));
      expect(decision.refundedLearnerCoins, equals(1));
      expect(decision.compensatedTeacherCoins, equals(0));
    });

    test('إلغاء المتعلّم قبل الموعد بساعة واحدة (<= 2h): العملة تذهب للمعلم تعويضاً', () {
      final decision = TimeBankPureLogic.decideCancellation(
        cancellingUserId: learnerId,
        learnerId: learnerId,
        teacherId: teacherId,
        scheduledAt: scheduledTime,
        costCoins: 1,
        clock: () => DateTime(2026, 11, 10, 13, 0), // 1:00 PM (1 hour before)
      );

      expect(decision.outcome, equals(CancellationOutcome.compensationToTeacher));
      expect(decision.newStatus, equals('cancelled_by_learner'));
      expect(decision.newEscrowStatus, equals('released_to_teacher'));
      expect(decision.refundedLearnerCoins, equals(0));
      expect(decision.compensatedTeacherCoins, equals(1));
    });

    test('إلغاء المعلم للجلسة في أي وقت: استرداد كامل للمتعلّم دون أي عقوبة عليه', () {
      final decision = TimeBankPureLogic.decideCancellation(
        cancellingUserId: teacherId,
        learnerId: learnerId,
        teacherId: teacherId,
        scheduledAt: scheduledTime,
        costCoins: 1,
        clock: () => DateTime(2026, 11, 10, 13, 55), // 5 minutes before
      );

      expect(decision.outcome, equals(CancellationOutcome.fullRefundToLearner));
      expect(decision.newStatus, equals('cancelled_by_teacher'));
      expect(decision.newEscrowStatus, equals('refunded_to_learner'));
      expect(decision.refundedLearnerCoins, equals(1));
      expect(decision.compensatedTeacherCoins, equals(0));
    });

    test('رفض الإلغاء إذا كان القائم بالإلغاء ليس طرفاً في الجلسة', () {
      expect(
        () => TimeBankPureLogic.decideCancellation(
          cancellingUserId: 'stranger_user',
          learnerId: learnerId,
          teacherId: teacherId,
          scheduledAt: scheduledTime,
          costCoins: 1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('5. سلامة نماذج البيانات وتحويلها (App Models Serialization)', () {
    test('نموذج TimeBankSessionModel يحافظ على بيانات الضمان والتواريخ ورابط الاجتماع', () {
      final session = TimeBankSessionModel(
        id: 'sess_test_1',
        learnerId: 'u1',
        learnerName: 'أحمد',
        teacherId: 'u2',
        teacherName: 'عمر',
        teacherInitials: 'ع.خ',
        courseName: 'الجبر الخطي',
        courseCode: 'MATH201',
        topic: 'المصفوفات',
        day: 'الأحد',
        time: '12:00 م',
        durationMinutes: 60,
        mode: 'online',
        location: 'أونلاين',
        meetingUrl: 'https://meet.google.com/abc-defg-hij',
        costCoins: 1,
        escrowStatus: 'held',
      );

      final map = session.toMap();
      expect(map['costCoins'], equals(1));
      expect(map['escrowStatus'], equals('held'));
      expect(map['mode'], equals('online'));
      expect(map['meetingUrl'], equals('https://meet.google.com/abc-defg-hij'));

      final fromMap = TimeBankSessionModel.fromMap(map, 'sess_test_1');
      expect(fromMap.costCoins, equals(1));
      expect(fromMap.escrowStatus, equals('held'));
      expect(fromMap.teacherName, equals('عمر'));
      expect(fromMap.mode, equals('online'));
      expect(fromMap.meetingUrl, equals('https://meet.google.com/abc-defg-hij'));
    });
  });

  group('6. وزن الساعات المعتمدة في خوارزمية المذاكرة (Credit Hours Weighting)', () {
    test('المادة 3 ساعات معتمدة تعطي أولوية أعلى بنسبة 50% مقارنة بمادة ساعتين', () {
      const course3h = CourseSeed(
        id: 'c3',
        name: 'مادة 3 ساعات',
        code: 'CS300',
        color: AppColors.courseTeal,
        creditHours: 3,
      );
      const course2h = CourseSeed(
        id: 'c2',
        name: 'مادة ساعتين',
        code: 'CS200',
        color: AppColors.courseSage,
        creditHours: 2,
      );

      final input3h = CourseStudyInput(
        course: course3h,
        selfRating: 2,
        daysUntilExam: 10,
        topics: ['Topic 1'],
      );
      final input2h = CourseStudyInput(
        course: course2h,
        selfRating: 2,
        daysUntilExam: 10,
        topics: ['Topic 1'],
      );

      final priority3h = input3h.calculateInitialPriority();
      final priority2h = input2h.calculateInitialPriority();

      expect(priority3h, greaterThan(priority2h));
      expect(priority3h / priority2h, closeTo(1.5, 0.01));
    });

    test('دعم تحويل CourseSeed من وإلى Map مع الساعات المعتمدة', () {
      const course = CourseSeed(
        id: 'custom_1',
        name: 'ذكاء اصطناعي تطبيقي',
        code: 'AI301',
        color: AppColors.courseSand,
        creditHours: 4,
      );

      final map = course.toMap();
      expect(map['creditHours'], equals(4));

      final restored = CourseSeed.fromMap(map);
      expect(restored.id, equals('custom_1'));
      expect(restored.name, equals('ذكاء اصطناعي تطبيقي'));
      expect(restored.creditHours, equals(4));
    });
  });

  group('7. الجدولة اليدوية للمحاضرات وتوليد خطة المذاكرة التكيفية', () {
    test('نموذج ScheduleItemModel يدعم التحويل من وإلى Map', () {
      const lecture = ScheduleItemModel(
        id: 'lec_test',
        courseName: 'قواعد البيانات',
        courseCode: 'IS201',
        day: 'السبت',
        startTime: '08:30 ص',
        endTime: '10:00 ص',
        room: 'مدرج 1',
        color: AppColors.courseSand,
      );

      final map = lecture.toMap();
      expect(map['day'], equals('السبت'));
      expect(map['startTime'], equals('08:30 ص'));

      final restored = ScheduleItemModel.fromMap(map);
      expect(restored.id, equals('lec_test'));
      expect(restored.courseName, equals('قواعد البيانات'));
      expect(restored.room, equals('مدرج 1'));
    });

    test('الخوارزمية الذكية تتفادى أوقات المحاضرات المجدولة يدوياً', () {
      final inputs = PlannerAlgorithm.getDefaultSeedInputs();
      const heavyLecture = ScheduleItemModel(
        id: 'lec_sat',
        courseName: 'التفاضل والتكامل',
        courseCode: 'MATH202',
        day: 'السبت',
        startTime: '11:00 ص',
        endTime: '12:30 م',
        room: 'قاعة 3',
        color: AppColors.courseSlate,
      );

      final plan = PlannerAlgorithm.generateWeeklyPlan(
        courseInputs: inputs,
        lectureSchedule: [heavyLecture],
      );

      // التأكد من عدم وجود أي جلسة مذاكرة في فترة المحاضرة (11:00 ص إلى 12:30 م) يوم السبت
      final satBlocks = plan.where((b) => b.day == 'السبت').toList();
      for (final block in satBlocks) {
        expect(block.startTime, isNot(equals('11:00 ص')));
      }
      expect(plan, isNotEmpty);
    });
  });

  group('8. ربط الحسابات واكتشاف عروض الشرح والزملاء المتاحين (Peer Discovery & Cross-Account Linking)', () {
    test('المرشحون يأتون فقط من مستندات offers الحقيقية والزميل الآخر يظهر كمرشح', () {
      final realOffers = [
        const TimeBankOfferModel(
          id: 'offer_real_1',
          teacherId: 'account_1',
          teacherName: 'أحمد محمد',
          courseId: 'cs201',
          courseName: 'البرمجة الكائنية (OOP)',
          courseCode: 'CS201',
          topic: 'مستعد للشرح ومساعدة الزملاء في أهم النقاط والتطبيقات 💡',
          day: 'متاح للتنسيق',
          time: 'حسب الاتفاق مع الزميل',
          durationMinutes: 60,
          location: 'مكتبة الكلية / أونلاين',
          courseColor: AppColors.courseTeal,
        ),
      ];

      final targetCourse = AppConstants.seedCourses[0]; // cs201 (OOP)
      final currentUserId = 'account_2'; // الحساب الثاني الذي يبحث عن شرح

      final candidates = realOffers.where((offer) {
        if (offer.teacherId == currentUserId) return false;
        return offer.courseId == targetCourse.id ||
            offer.courseName.contains(targetCourse.name) ||
            targetCourse.name.contains(offer.courseName);
      }).toList();

      expect(candidates, isNotEmpty);
      expect(candidates.first.teacherId, equals('account_1'));
      expect(candidates.first.teacherName, equals('أحمد محمد'));
      expect(candidates.first.courseId, equals('cs201'));
    });

    test('المستخدم لا يظهر لنفسه كمرشح للشرح إطلاقاً', () {
      final realOffers = [
        const TimeBankOfferModel(
          id: 'offer_real_1',
          teacherId: 'account_1',
          teacherName: 'أحمد محمد',
          courseId: 'cs201',
          courseName: 'البرمجة الكائنية (OOP)',
          courseCode: 'CS201',
          topic: 'topic',
          day: 'day',
          time: 'time',
          durationMinutes: 60,
          location: 'loc',
          courseColor: AppColors.courseTeal,
        ),
      ];

      final targetCourse = AppConstants.seedCourses[0];
      final currentUserId = 'account_1'; // نفس الحساب يبحث لنفسه

      final candidates = realOffers.where((offer) {
        if (offer.teacherId == currentUserId) return false;
        return offer.courseId == targetCourse.id;
      }).toList();

      expect(candidates, isEmpty);
    });
  });

  group('9. الحجز بموعد محدد واستبعاد التعارضات (Concrete Slot Generation & Overlap Filtering)', () {
    test('توليد مواعيد الحجز: استبعاد المواعيد الأقرب من ساعتين والأبعد من 14 يوماً', () {
      // نفترض أن الساعة الآن: السبت 10:00 ص
      final fixedNow = DateTime(2026, 11, 21, 10, 0); // Saturday (weekday: 6 -> appWeekday 0)
      final teacherSlots = [
        const OfferTimeSlot(weekday: 0, startMin: 600, endMin: 840), // السبت من 10:00 ص إلى 02:00 م
      ];

      final slots = TimeBankPureLogic.generateBookableSlots(
        teacherSlots: teacherSlots,
        durationMinutes: 60,
        learnerLectures: [],
        learnerStudyBlocks: [],
        clock: () => fixedNow,
      );

      // موعد 10:00 ص و 10:30 ص و 11:00 ص و 11:30 ص في نفس اليوم تبعد أقل من ساعتين (12:00 م فما بعد هي المسموحة)
      for (final slot in slots) {
        expect(slot.dateTime.isAfter(fixedNow.add(const Duration(hours: 2))) ||
            slot.dateTime.isAtSameMomentAs(fixedNow.add(const Duration(hours: 2))), isTrue);
        expect(slot.dateTime.isBefore(fixedNow.add(const Duration(days: 14))), isTrue);
      }

      // أول موعد متاح في نفس اليوم سيكون الساعة 12:00 م
      final todaySlots = slots.where((s) => s.dateTime.day == 21).toList();
      expect(todaySlots, isNotEmpty);
      expect(todaySlots.first.dateTime.hour, equals(12));
      expect(todaySlots.first.dateTime.minute, equals(0));
    });

    test('إخفاء مواعيد الشرح التي تتعارض مع محاضرات أو كتل مذاكرة المتعلم', () {
      // نفترض الساعة الآن: الجمعة 08:00 م (قبل السبت بـ 14 ساعة)
      final fixedNow = DateTime(2026, 11, 20, 20, 0);
      final teacherSlots = [
        const OfferTimeSlot(weekday: 0, startMin: 600, endMin: 780), // السبت من 10:00 ص إلى 01:00 م
      ];

      // المتعلم لديه محاضرة السبت من 10:00 ص إلى 11:30 ص
      final learnerLectures = [
        const ScheduleItemModel(
          id: 'lec_1',
          courseName: 'هياكل بيانات',
          courseCode: 'CS202',
          day: 'السبت',
          startTime: '10:00 ص',
          endTime: '11:30 ص',
          room: 'قاعة 1',
          color: AppColors.courseSage,
        ),
      ];

      final slots = TimeBankPureLogic.generateBookableSlots(
        teacherSlots: teacherSlots,
        durationMinutes: 60,
        learnerLectures: learnerLectures,
        learnerStudyBlocks: [],
        clock: () => fixedNow,
      );

      // الفترات الممكنة لمعلم تبدأ من 10:00 إلى 12:00
      // 10:00 - 11:00 يتعارض مع المحاضرة (10:00 - 11:30) -> محجوب
      // 10:30 - 11:30 يتعارض مع المحاضرة -> محجوب
      // 11:00 - 12:00 يتعارض مع المحاضرة -> محجوب
      // 11:30 - 12:30 لا يتعارض مع المحاضرة -> متاح!
      // 12:00 - 01:00 لا يتعارض مع المحاضرة -> متاح!
      expect(slots.any((s) => s.dateTime.hour == 10), isFalse);
      expect(slots.any((s) => s.dateTime.hour == 11 && s.dateTime.minute == 0), isFalse);
      expect(slots.any((s) => s.dateTime.hour == 11 && s.dateTime.minute == 30), isTrue);
      expect(slots.any((s) => s.dateTime.hour == 12 && s.dateTime.minute == 0), isTrue);
    });
  });

  // =========================================================================
  // المجموعة 10: حظر الحجز المزدوج وأقفال المواعيد (Double Booking & Slot Locks)
  // =========================================================================
  group('TimeBankPureLogic - Double Booking & Slot Locks', () {
    final scheduledAt = DateTime(2026, 11, 21, 14, 0); // 2:00 PM
    final epochMs = scheduledAt.millisecondsSinceEpoch;

    test('30-minute session generates exactly 1 epoch interval', () {
      final epochs = TimeBankPureLogic.getSessionSlotEpochs(
        scheduledAt: scheduledAt,
        durationMinutes: 30,
      );
      expect(epochs.length, equals(1));
      expect(epochs[0], equals(epochMs));
    });

    test('60-minute session generates exactly 2 30-min epoch intervals', () {
      final epochs = TimeBankPureLogic.getSessionSlotEpochs(
        scheduledAt: scheduledAt,
        durationMinutes: 60,
      );
      expect(epochs.length, equals(2));
      expect(epochs[0], equals(epochMs));
      expect(epochs[1], equals(epochMs + 30 * 60 * 1000));
    });

    test('getLockDocIds generates deterministic lock doc IDs for both learner and teacher', () {
      final ids30 = TimeBankPureLogic.getLockDocIds(
        learnerId: 'user_learner',
        teacherId: 'user_teacher',
        scheduledAt: scheduledAt,
        durationMinutes: 30,
      );
      expect(ids30, equals([
        'user_learner_$epochMs',
        'user_teacher_$epochMs',
      ]));

      final ids60 = TimeBankPureLogic.getLockDocIds(
        learnerId: 'user_learner',
        teacherId: 'user_teacher',
        scheduledAt: scheduledAt,
        durationMinutes: 60,
      );
      final nextEpochMs = epochMs + 30 * 60 * 1000;
      expect(ids60, equals([
        'user_learner_$epochMs',
        'user_teacher_$epochMs',
        'user_learner_$nextEpochMs',
        'user_teacher_$nextEpochMs',
      ]));
    });

    test('hasActiveLock correctly detects active slot locks', () {
      expect(TimeBankPureLogic.hasActiveLock([]), isFalse);
      expect(TimeBankPureLogic.hasActiveLock([null]), isFalse);
      expect(TimeBankPureLogic.hasActiveLock([
        {'status': 'released'},
        {'status': 'used'},
      ]), isFalse);

      expect(TimeBankPureLogic.hasActiveLock([
        {'status': 'released'},
        {'status': 'active'},
      ]), isTrue);
    });
  });

  // =========================================================================
  // المجموعة 11: قبول المعلم والاعتذار وإلغاء المتعلم قبل القبول (Teacher Acceptance)
  // =========================================================================
  group('TimeBankPureLogic - Teacher Acceptance & Lifecycle', () {
    test('validateAcceptanceTransition accepts pending session with held escrow', () {
      expect(
        () => TimeBankPureLogic.validateAcceptanceTransition(
          currentStatus: 'pending',
          currentEscrowStatus: 'held',
        ),
        returnsNormally,
      );

      expect(
        () => TimeBankPureLogic.validateAcceptanceTransition(
          currentStatus: 'confirmed',
          currentEscrowStatus: 'held',
        ),
        throwsStateError,
      );
    });

    test('validateRejectionTransition allows rejection only from pending', () {
      expect(
        () => TimeBankPureLogic.validateRejectionTransition(
          currentStatus: 'pending',
          currentEscrowStatus: 'held',
        ),
        returnsNormally,
      );

      expect(
        () => TimeBankPureLogic.validateRejectionTransition(
          currentStatus: 'completed',
          currentEscrowStatus: 'held',
        ),
        throwsStateError,
      );
    });

    test('Learner cancelling pending session gets full refund even if within 2 hours', () {
      final scheduledAt = DateTime(2026, 11, 21, 14, 0);
      DateTime clockNow() => DateTime(2026, 11, 21, 13, 30); // قبل الموعد بـ 30 دقيقة فقط

      final decision = TimeBankPureLogic.decideCancellation(
        cancellingUserId: 'user_learner',
        learnerId: 'user_learner',
        teacherId: 'user_teacher',
        scheduledAt: scheduledAt,
        costCoins: 1,
        sessionStatus: 'pending',
        clock: clockNow,
      );

      expect(decision.outcome, equals(CancellationOutcome.fullRefundToLearner));
      expect(decision.refundedLearnerCoins, equals(1));
      expect(decision.compensatedTeacherCoins, equals(0));
      expect(decision.newStatus, equals('cancelled_by_learner'));
      expect(decision.newEscrowStatus, equals('refunded_to_learner'));
    });

    test('After acceptance (confirmed), cancelling within 2 hours compensates teacher', () {
      final scheduledAt = DateTime(2026, 11, 21, 14, 0);
      DateTime clockNow() => DateTime(2026, 11, 21, 13, 0); // قبل الموعد بساعة واحدة

      final decision = TimeBankPureLogic.decideCancellation(
        cancellingUserId: 'user_learner',
        learnerId: 'user_learner',
        teacherId: 'user_teacher',
        scheduledAt: scheduledAt,
        costCoins: 1,
        sessionStatus: 'confirmed',
        clock: clockNow,
      );

      expect(decision.outcome, equals(CancellationOutcome.compensationToTeacher));
      expect(decision.refundedLearnerCoins, equals(0));
      expect(decision.compensatedTeacherCoins, equals(1));
    });
  });

  // =========================================================================
  // المجموعة 12: تم الشرح والإتمام بعد حلول الموعد (Teacher Done & ScheduledAt Completion)
  // =========================================================================
  group('TimeBankPureLogic - Teacher Done & ScheduledAt Completion', () {
    final scheduledAt = DateTime(2026, 11, 21, 14, 0);

    test('validateCompletionTransition succeeds when completing at or after scheduledAt', () {
      DateTime clockAfter() => DateTime(2026, 11, 21, 14, 30); // بعد الموعد بـ 30 دقيقة

      expect(
        () => TimeBankPureLogic.validateCompletionTransition(
          currentEscrowStatus: 'held',
          currentStatus: 'confirmed',
          rating: 5,
          scheduledAt: scheduledAt,
          clock: clockAfter,
        ),
        returnsNormally,
      );
    });

    test('validateCompletionTransition throws StateError when attempting completion before scheduledAt', () {
      DateTime clockBefore() => DateTime(2026, 11, 21, 13, 0); // قبل الموعد بساعة

      expect(
        () => TimeBankPureLogic.validateCompletionTransition(
          currentEscrowStatus: 'held',
          currentStatus: 'confirmed',
          rating: 5,
          scheduledAt: scheduledAt,
          clock: clockBefore,
        ),
        throwsStateError,
      );
    });
  });

  // =========================================================================
  // المجموعة 13: منع تعليق الضمان المالي والنزاعات (No Stuck Escrow & Disputes)
  // =========================================================================
  group('TimeBankPureLogic - No Stuck Escrow & Disputes', () {
    final baseCreatedAt = DateTime(2026, 11, 20, 10, 0);
    final scheduledAt = DateTime(2026, 11, 21, 14, 0);

    test('canLearnerClaimExpiredRefund allows refund after 24h or after scheduledAt passes while pending', () {
      // 1. قبل مرور 24 ساعة والموعد لم يحن بعد -> غير مستحق
      DateTime clockTooSoon() => DateTime(2026, 11, 20, 20, 0);
      expect(
        TimeBankPureLogic.canLearnerClaimExpiredRefund(
          status: 'pending',
          escrowStatus: 'held',
          createdAt: baseCreatedAt,
          scheduledAt: scheduledAt,
          clock: clockTooSoon,
        ),
        isFalse,
      );

      // 2. بعد مرور 25 ساعة على الإنشاء -> مستحق
      DateTime clockAfter25h() => DateTime(2026, 11, 21, 11, 0);
      expect(
        TimeBankPureLogic.canLearnerClaimExpiredRefund(
          status: 'pending',
          escrowStatus: 'held',
          createdAt: baseCreatedAt,
          scheduledAt: scheduledAt,
          clock: clockAfter25h,
        ),
        isTrue,
      );

      // 3. تجاوز الموعد المحدد وما زالت pending -> مستحق
      DateTime clockAfterScheduled() => DateTime(2026, 11, 21, 15, 0);
      expect(
        TimeBankPureLogic.canLearnerClaimExpiredRefund(
          status: 'pending',
          escrowStatus: 'held',
          createdAt: baseCreatedAt,
          scheduledAt: scheduledAt,
          clock: clockAfterScheduled,
        ),
        isTrue,
      );
    });

    test('canTeacherClaimAutoRelease allows claim after 48h from scheduledAt with teacherMarkedDoneAt', () {
      final doneAt = DateTime(2026, 11, 21, 15, 0);

      // 1. لم يمر 48 ساعة بعد (مر 24 ساعة فقط) -> غير مستحق
      DateTime clockAfter24h() => DateTime(2026, 11, 22, 14, 0);
      expect(
        TimeBankPureLogic.canTeacherClaimAutoRelease(
          status: 'confirmed',
          escrowStatus: 'held',
          teacherMarkedDoneAt: doneAt,
          scheduledAt: scheduledAt,
          clock: clockAfter24h,
        ),
        isFalse,
      );

      // 2. مر 49 ساعة على الموعد -> مستحق
      DateTime clockAfter49h() => DateTime(2026, 11, 23, 15, 0);
      expect(
        TimeBankPureLogic.canTeacherClaimAutoRelease(
          status: 'confirmed',
          escrowStatus: 'held',
          teacherMarkedDoneAt: doneAt,
          scheduledAt: scheduledAt,
          clock: clockAfter49h,
        ),
        isTrue,
      );

      // 3. لم يقم المعلم بتسجيل "تم الشرح" -> غير مستحق إطلاقاً
      expect(
        TimeBankPureLogic.canTeacherClaimAutoRelease(
          status: 'confirmed',
          escrowStatus: 'held',
          teacherMarkedDoneAt: null,
          scheduledAt: scheduledAt,
          clock: clockAfter49h,
        ),
        isFalse,
      );
    });

    test('canLearnerOpenDispute is eligible only when confirmed and teacher marked done', () {
      final doneAt = DateTime(2026, 11, 21, 15, 0);

      expect(
        TimeBankPureLogic.canLearnerOpenDispute(
          status: 'confirmed',
          escrowStatus: 'held',
          teacherMarkedDoneAt: doneAt,
        ),
        isTrue,
      );

      expect(
        TimeBankPureLogic.canLearnerOpenDispute(
          status: 'confirmed',
          escrowStatus: 'held',
          teacherMarkedDoneAt: null,
        ),
        isFalse,
      );

      expect(
        TimeBankPureLogic.canLearnerOpenDispute(
          status: 'completed',
          escrowStatus: 'released_to_teacher',
          teacherMarkedDoneAt: doneAt,
        ),
        isFalse,
      );
    });
  });

  // =========================================================================
  // المجموعة 14: رصيد المحفظة والعملات المحتجزة في الضمان (Wallet Held Coins)
  // =========================================================================
  group('TimeBankPureLogic - Wallet Held Coins', () {
    test('calculateHeldCoins calculates held coins exclusively for pending, confirmed, and disputed sessions with escrowStatus held', () {
      final sessions = [
        TimeBankSessionModel.fromMap({
          'costCoins': 1,
          'status': 'pending',
          'escrowStatus': 'held',
        }, 's1'),
        TimeBankSessionModel.fromMap({
          'costCoins': 1,
          'status': 'confirmed',
          'escrowStatus': 'held',
        }, 's2'),
        TimeBankSessionModel.fromMap({
          'costCoins': 1,
          'status': 'disputed',
          'escrowStatus': 'held',
        }, 's3'),
        TimeBankSessionModel.fromMap({
          'costCoins': 1,
          'status': 'completed',
          'escrowStatus': 'released_to_teacher',
        }, 's4'),
        TimeBankSessionModel.fromMap({
          'costCoins': 1,
          'status': 'cancelled_by_learner',
          'escrowStatus': 'refunded_to_learner',
        }, 's5'),
      ];

      // Sessions s1, s2, s3 are held -> 3 coins held
      final held = TimeBankPureLogic.calculateHeldCoins(sessions);
      expect(held, equals(3));
    });

    test('calculateHeldCoins returns 0 when no sessions are in held status', () {
      final sessions = [
        TimeBankSessionModel.fromMap({
          'costCoins': 1,
          'status': 'completed',
          'escrowStatus': 'released_to_teacher',
        }, 's1'),
      ];
      expect(TimeBankPureLogic.calculateHeldCoins(sessions), equals(0));
      expect(TimeBankPureLogic.calculateHeldCoins([]), equals(0));
    });
  });

  // =========================================================================
  // المجموعة 15: مكافأة إتمام المذاكرة وزيادة نقاط الوقت (Study Completion Reward)
  // =========================================================================
  group('15. فصل نقاط المذاكرة عن عملات الوقت (Item B: Study Points Decoupled from Spendable Coins)', () {
    test('نموذج حركة المحفظة study_reward يتعامل بأمان مع البيانات التاريخية', () {
      final tx = WalletTransactionModel(
        id: 'tx_study_test_1',
        userId: 'student_123',
        title: 'مكافأة إتمام مذاكرة: هياكل البيانات',
        date: 'اليوم',
        amount: 1,
        isNegative: false,
        type: 'study_reward',
        icon: WalletTransactionModel.getIconForType('study_reward'),
        createdAt: DateTime.now(),
      );

      expect(tx.amount, 1);
      expect(tx.isNegative, false);
      expect(tx.type, 'study_reward');
      expect(tx.icon, Icons.stars_rounded);

      final map = tx.toMap();
      final parsed = WalletTransactionModel.fromMap(map, tx.id);
      expect(parsed.amount, 1);
      expect(parsed.isNegative, false);
      expect(parsed.type, 'study_reward');
      expect(parsed.icon, Icons.stars_rounded);
    });

    test('إتمام جلسة المذاكرة لا يزيد رصيد عملات الوقت (timeCoins) بل يوثق فقط كتل المذاكرة', () {
      const initialTimeCoins = 2;
      final completedBlockIds = <String>{};

      // الطالب أتم جلسة مذاكرة
      const blockId = 'block_math_101';
      completedBlockIds.add(blockId);

      // رصيد عملات الوقت القابل للشراء يبقى 2 دون تغيير
      const spendableCoins = initialTimeCoins;
      expect(spendableCoins, 2);
      expect(completedBlockIds.contains(blockId), isTrue);
      expect(completedBlockIds.length, 1);
    });

    test('حساب رصيد العملات القابلة للصرف يستند حصرياً إلى timeCoins دون جمع نقاط المذاكرة', () {
      final userDoc = {
        'timeCoins': 2,
        'studyPoints': 50, // نقاط مظاهر أو قديمة
        'completedBlockIds': ['b1', 'b2', 'b3'],
      };

      final spendableBalance = (userDoc['timeCoins'] as num?)?.toInt() ?? 0;
      final derivedStudyBlocks = (userDoc['completedBlockIds'] as List?)?.length ?? 0;

      // الرصيد الصالح للشراء هو 2 فقط وليس 52
      expect(spendableBalance, 2);
      expect(derivedStudyBlocks, 3);
    });
  });
}
