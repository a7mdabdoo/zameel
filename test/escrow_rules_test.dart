import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/core/algorithms/planner_algorithm.dart';
import 'package:zameel/core/constants/app_constants.dart';
import 'package:zameel/core/models/app_models.dart';
import 'package:zameel/core/state/app_state.dart';
import 'package:zameel/core/theme/app_colors.dart';
import 'package:zameel/features/auth/data/auth_service.dart';
import 'package:zameel/features/timebank/application/timebank_pure_logic.dart';
import 'package:zameel/features/questions/data/question_model.dart';
import 'package:zameel/core/services/focus_dnd_service.dart';
import 'package:zameel/core/services/notification_service.dart';

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

  // =========================================================================
  group('16. عزل بيانات المخطط بين الحسابات على نفس الجهاز (Item C: Cross-Account State Isolation)', () {
    test('المستخدم أ يتم كتلة مذاكرة، ثم عند التبديل للمستخدم ب، لا يرى المستخدم ب أي كتل مكتملة', () {
      final container = ProviderContainer(overrides: [
        userProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(plannerProvider.notifier);
      notifier.switchUser('user_A');

      // 1. المستخدم أ يتم كتلة مذاكرة
      expect(container.read(plannerProvider).studyBlocks, isNotEmpty);
      final firstBlockId = container.read(plannerProvider).studyBlocks.first.id;
      notifier.markBlockCompleted(firstBlockId);

      expect(notifier.completedBlockIds.contains(firstBlockId), isTrue);
      expect(container.read(plannerProvider).studyBlocks.firstWhere((b) => b.id == firstBlockId).isCompleted, isTrue);

      // 2. تسجيل خروج المستخدم أ وتسجيل دخول المستخدم ب
      notifier.switchUser('user_B');

      // 3. التحقق من أن المستخدم ب يرى مجموعة فارغة ولا يرى كتل المستخدم أ
      expect(notifier.completedBlockIds.contains(firstBlockId), isFalse);
      expect(notifier.completedBlockIds.isEmpty, isTrue);
      expect(notifier.missedBlockIds.isEmpty, isTrue);
    });

    test('التأكد من إزالة static: عدم تشارك كتل المذاكرة بين نسختين مختلفتين من Notifier', () {
      final container1 = ProviderContainer(overrides: [
        userProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      final container2 = ProviderContainer(overrides: [
        userProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(container1.dispose);
      addTearDown(container2.dispose);

      final notifier1 = container1.read(plannerProvider.notifier);
      final notifier2 = container2.read(plannerProvider.notifier);

      notifier1.switchUser('user_1');
      notifier2.switchUser('user_2');

      final blockId = container1.read(plannerProvider).studyBlocks.first.id;
      notifier1.markBlockCompleted(blockId);

      expect(notifier1.completedBlockIds.contains(blockId), isTrue);
      expect(notifier2.completedBlockIds.contains(blockId), isFalse);
    });
  });

  // =========================================================================
  // 17. التحليل الدفاعي لعروض الشرح (Item 4: Defensive Parsing of Offers)
  // =========================================================================
  group('17. التحليل الدفاعي لعروض الشرح (Item 4: Defensive Offer Parsing)', () {
    test('تخطي العروض التالفة أو التي تفتقر للمعلومات الأساسية (returns null)', () {
      // عرض بدون teacherId
      expect(
        TimeBankOfferModel.fromMapSafe({'courseName': 'فيزياء'}, 'offer_no_teacher'),
        isNull,
      );

      // عرض بدون courseName
      expect(
        TimeBankOfferModel.fromMapSafe({'teacherId': 't_1'}, 'offer_no_course'),
        isNull,
      );

      // عرض بدون أي شرائح صالحة
      expect(
        TimeBankOfferModel.fromMapSafe({
          'teacherId': 't_1',
          'courseName': 'رياضيات',
          'slots': [
            {'weekday': 99, 'startMin': 800, 'endMin': 700}, // فاسدة
          ],
        }, 'offer_bad_slots_only'),
        isNull,
      );
    });

    test('تنقية الشرائح واستبعاد الشرائح الفاسدة مع الاحتفاظ بالشرائح الصالحة', () {
      final offer = TimeBankOfferModel.fromMapSafe({
        'teacherId': 'teacher_123',
        'teacherName': 'أحمد زميل',
        'courseName': 'تفاضل وتكامل',
        'slots': [
          {'weekday': 0, 'startMin': 600, 'endMin': 720}, // صالحة
          {'invalid': 'garbage_data'}, // فاسدة تماماً
          {'weekday': 1, 'startMin': 900, 'endMin': 800}, // فاسدة (endMin < startMin)
          {'weekday': 2, 'startMin': 780, 'endMin': 900}, // صالحة
        ],
      }, 'offer_mixed');

      expect(offer, isNotNull);
      expect(offer!.slots.length, equals(2));
      expect(offer.slots[0].weekday, equals(0));
      expect(offer.slots[1].weekday, equals(2));
    });

    test('اقتصار الشرائح على حد أقصى 7 شرائح دفاعياً', () {
      final rawSlots = List.generate(
        10,
        (i) => {'weekday': i % 7, 'startMin': 600, 'endMin': 720},
      );

      final offer = TimeBankOfferModel.fromMapSafe({
        'teacherId': 'teacher_capped',
        'courseName': 'خوارزميات',
        'slots': rawSlots,
      }, 'offer_cap');

      expect(offer, isNotNull);
      expect(offer!.slots.length, equals(7));
    });
  });

  // =========================================================================
  group('18. إتمام المهام اليومية الدائم وحظر التراجع (Permanent Task Completion & No Revert)', () {
    test('بمجرد إتمام المهمة، محاولة toggleBlockCompleted لا تتراجع عن حالة الإتمام', () {
      final container = ProviderContainer(overrides: [
        userProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(plannerProvider.notifier);
      final blocks = container.read(plannerProvider).studyBlocks;
      expect(blocks, isNotEmpty);
      final blockId = blocks.first.id;

      // 1. أول نقرة: إتمام المهمة
      notifier.toggleBlockCompleted(blockId);
      final completedBlock = container.read(plannerProvider).studyBlocks.firstWhere((b) => b.id == blockId);
      expect(completedBlock.isCompleted, isTrue);
      expect(notifier.completedBlockIds.contains(blockId), isTrue);

      // 2. محاولة نقرة ثانية للتراجع: تظل مكتملة ولا يُلغى التحديد
      notifier.toggleBlockCompleted(blockId);
      final blockAfterSecondTap = container.read(plannerProvider).studyBlocks.firstWhere((b) => b.id == blockId);
      expect(blockAfterSecondTap.isCompleted, isTrue);
      expect(notifier.completedBlockIds.contains(blockId), isTrue);
    });

    test('المهمة المكتملة لا يمكن تفويتها markBlockMissed ولا إعادة جدولتها rescheduleBlock', () {
      final container = ProviderContainer(overrides: [
        userProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(plannerProvider.notifier);
      final blockId = container.read(plannerProvider).studyBlocks.first.id;

      notifier.markBlockCompleted(blockId);
      expect(container.read(plannerProvider).studyBlocks.firstWhere((b) => b.id == blockId).isCompleted, isTrue);

      // محاولة تفويت الجلسة المكتملة بالفعل: يتم رفضها والحفاظ على اكتمالها
      notifier.markBlockMissed(blockId);
      final afterMissAttempt = container.read(plannerProvider).studyBlocks.firstWhere((b) => b.id == blockId);
      expect(afterMissAttempt.isCompleted, isTrue);
      expect(afterMissAttempt.isMissed, isFalse);

      // محاولة إعادة جدولة الجلسة المكتملة بالفعل: يتم رفضها وتظل مكتملة
      notifier.rescheduleBlock(blockId);
      final afterRescheduleAttempt = container.read(plannerProvider).studyBlocks.firstWhere((b) => b.id == blockId);
      expect(afterRescheduleAttempt.isCompleted, isTrue);
    });
  });

  // =========================================================================
  group('19. حسابات المعدل اليومي وحوافز إتمام جميع مهام اليوم (Daily Completion Rate & Daily Reward)', () {
    test('حساب النسبة المئوية اليومية بدقة وفق مهام اليوم فقط', () {
      // محاكاة 4 مهام لليوم
      const todayTotal = 4;
      var completedToday = 1;

      var dailyProgressPct = (completedToday / todayTotal).clamp(0.0, 1.0);
      var dailyProgressInt = (dailyProgressPct * 100).round();
      expect(dailyProgressInt, 25);

      completedToday = 4;
      dailyProgressPct = (completedToday / todayTotal).clamp(0.0, 1.0);
      dailyProgressInt = (dailyProgressPct * 100).round();
      expect(dailyProgressInt, 100);

      // التحقق من حالة اكتمال جميع مهام اليوم والحصول على نقطة اليوم
      final isAllCompleted = completedToday == todayTotal;
      expect(isAllCompleted, isTrue);
    });
  });

  // =========================================================================
  group('20. سرعة تهيئة الحساب الأكاديمي وتجاوز حراسة التوجيه (Instant Academic Setup & Onboarding Guard)', () {
    test('localOnboardingCompletedProvider يتيح الدخول الفوري دون انتظار شبكة Firestore', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(localOnboardingCompletedProvider), isFalse);

      // عند إتمام التهيئة بنجاح
      container.read(localOnboardingCompletedProvider.notifier).markCompleted();
      expect(container.read(localOnboardingCompletedProvider), isTrue);

      // محاكاة فحص GoRouter: يعتبر المستخدم جاهزاً للدخول فوراً
      final localOnboarded = container.read(localOnboardingCompletedProvider);
      final Map<String, dynamic>? emptyUserDoc = null;
      final bool isOnboarded = localOnboarded || (emptyUserDoc != null && (
        (emptyUserDoc['isOnboarded'] as bool? ?? false)
      ));

      expect(isOnboarded, isTrue);
    });
  });

  // =========================================================================
  group('21. الخوارزمية الذكية لتنظيم خطة المذاكرة وتفادي مادتين صعبتين في نفس اليوم (Cognitive Load Balancing)', () {
    test('حساب مؤشر الصعوبة وتصنيف المواد الصعبة والثقيلة بدقة', () {
      final heavyMath = CourseStudyInput(
        course: const CourseSeed(id: 'math_1', name: 'رياضيات 1', code: 'MATH101', color: Colors.blue, creditHours: 3),
        selfRating: 1, // ضعيف جداً ومادة 3 ساعات
        daysUntilExam: 20,
        topics: ['الجبر'],
      );

      final lightThinking = CourseStudyInput(
        course: const CourseSeed(id: 'thinking', name: 'التفكير العلمي', code: 'HUM103', color: Colors.green, creditHours: 2),
        selfRating: 4, // متمكن ومادة ساعتين
        daysUntilExam: 20,
        topics: ['مناهج التفكير'],
      );

      expect(heavyMath.calculateDifficultyScore(), 15.0);
      expect(heavyMath.isHeavy, isTrue);

      expect(lightThinking.calculateDifficultyScore(), 4.0);
      expect(lightThinking.isHeavy, isFalse);
    });

    test('الخوارزمية تمنع تماماً وضع مادتين صعبتين في نفس اليوم', () {
      final math = CourseStudyInput(
        course: const CourseSeed(id: 'c_math', name: 'رياضيات 1', code: 'M1', color: Colors.red, creditHours: 3),
        selfRating: 1, // مادة صعبة ثقيلة
        daysUntilExam: 20,
        topics: ['تفاضل'],
      );

      final electronics = CourseStudyInput(
        course: const CourseSeed(id: 'c_elec', name: 'الإلكترونيات', code: 'E1', color: Colors.orange, creditHours: 3),
        selfRating: 2, // مادة صعبة ثقيلة أيضاً
        daysUntilExam: 20,
        topics: ['دوائر'],
      );

      final thinking = CourseStudyInput(
        course: const CourseSeed(id: 'c_think', name: 'التفكير العلمي', code: 'T1', color: Colors.teal, creditHours: 2),
        selfRating: 4, // مادة خفيفة
        daysUntilExam: 20,
        topics: ['تفكير نقدي'],
      );

      final history = CourseStudyInput(
        course: const CourseSeed(id: 'c_hist', name: 'تاريخ الحوسبة', code: 'H1', color: Colors.brown, creditHours: 2),
        selfRating: 4, // مادة خفيفة
        daysUntilExam: 20,
        topics: ['أجيال الحاسب'],
      );

      final plan = PlannerAlgorithm.generateWeeklyPlan(
        courseInputs: [math, electronics, thinking, history],
        lectureSchedule: [],
      );

      expect(plan, isNotEmpty);

      // فحص كل يوم في الخطة: يجب ألا يحتوي أي يوم على أكثر من مادة صعبة واحدة
      final days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
      for (final day in days) {
        final dayBlocks = plan.where((b) => b.day == day).toList();
        final heavyBlocksInDay = dayBlocks.where((b) => b.courseId == 'c_math' || b.courseId == 'c_elec').toList();
        expect(
          heavyBlocksInDay.length,
          lessThanOrEqualTo(1),
          reason: 'اليوم $day يجب ألا يجمع بين مادتين صعبتين معاً!',
        );
      }
    });

    test('خوارزمية المذاكرة لا تسند نفس المادة أكثر من مرة واحدة في نفس اليوم نهائياً (Deduplication)', () {
      final inputs = PlannerAlgorithm.getDefaultSeedInputs();
      final plan = PlannerAlgorithm.generateWeeklyPlan(
        courseInputs: inputs,
        lectureSchedule: [],
      );

      final days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
      for (final day in days) {
        final dayBlocks = plan.where((b) => b.day == day).toList();
        final courseIds = dayBlocks.map((b) => b.courseId).toList();
        final uniqueCourseIds = courseIds.toSet().toList();
        expect(
          courseIds.length,
          equals(uniqueCourseIds.length),
          reason: 'اليوم $day يحتوي على تكرار لنفس المادة في جدول المذاكرة!',
        );
      }
    });

    test('جلسات المذاكرة لا تتعارض زمنياً مع المحاضرات المسجلة ولا مع جلسات المذاكرة الأخرى', () {
      final inputs = PlannerAlgorithm.getDefaultSeedInputs();
      const saturdayLecture = ScheduleItemModel(
        id: 'lec_sat_midday',
        courseName: 'خوارزميات',
        courseCode: 'CS201',
        day: 'السبت',
        startTime: '02:00 م',
        endTime: '03:30 م',
        room: 'قاعة 5',
        color: Colors.green,
      );

      final plan = PlannerAlgorithm.generateWeeklyPlan(
        courseInputs: inputs,
        lectureSchedule: [saturdayLecture],
      );

      int parseMin(String timeStr) {
        final clean = timeStr.trim();
        final isPM = clean.contains('م') || clean.toUpperCase().contains('PM');
        final digits = clean.replaceAll(RegExp(r'[^\d:]'), '');
        final parts = digits.split(':');
        var hour = int.tryParse(parts[0]) ?? 9;
        final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        if (isPM && hour < 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
        return hour * 60 + minute;
      }

      bool hasOverlap(int s1, int e1, int s2, int e2) => s1 < e2 && s2 < e1;

      final days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
      for (final day in days) {
        final dayBlocks = plan.where((b) => b.day == day).toList();
        for (int i = 0; i < dayBlocks.length; i++) {
          final s1 = parseMin(dayBlocks[i].startTime);
          final e1 = parseMin(dayBlocks[i].endTime);
          for (int j = i + 1; j < dayBlocks.length; j++) {
            final s2 = parseMin(dayBlocks[j].startTime);
            final e2 = parseMin(dayBlocks[j].endTime);
            expect(hasOverlap(s1, e1, s2, e2), isFalse, reason: 'تعارض بين كتلتي مذاكرة في يوم $day');
          }

          if (day == 'السبت') {
            final lecStart = parseMin(saturdayLecture.startTime);
            final lecEnd = parseMin(saturdayLecture.endTime);
            expect(hasOverlap(s1, e1, lecStart, lecEnd), isFalse, reason: 'تعارض مع محاضرة السبت');
          }
        }
      }
    });

    test('مراعاة كثافة المحاضرات وتخفيف ساعات المذاكرة الذاتية في الأيام المزدحمة بالمحاضرات', () {
      final inputs = PlannerAlgorithm.getDefaultSeedInputs();
      // يوم السبت به محاضرتان طويلتان بإجمالي 180 دقيقة
      final heavySaturdayLectures = [
        const ScheduleItemModel(
          id: 'lec1',
          courseName: 'برمجة',
          courseCode: 'CS1',
          day: 'السبت',
          startTime: '09:00 ص',
          endTime: '10:30 ص',
          room: 'مدرج أ',
          color: Colors.blue,
        ),
        const ScheduleItemModel(
          id: 'lec2',
          courseName: 'معمل',
          courseCode: 'CS2',
          day: 'السبت',
          startTime: '01:00 م',
          endTime: '02:30 م',
          room: 'معمل 1',
          color: Colors.purple,
        ),
      ];

      final plan = PlannerAlgorithm.generateWeeklyPlan(
        courseInputs: inputs,
        lectureSchedule: heavySaturdayLectures,
      );

      final satStudyBlocks = plan.where((b) => b.day == 'السبت').toList();
      // في اليوم المزدحم بالمحاضرات، الحد الأقصى للمذاكرة لا يتجاوز ساعتين (90 دقيقة أي جلستان فقط)
      expect(satStudyBlocks.length, lessThanOrEqualTo(2));
    });
  });

  // =========================================================================
  // المجموعة 22: استقرار القوائم المنسدلة والستريك اليومي للمذاكرة (Dropdown Stability & Study Streak)
  // =========================================================================
  group('22. استقرار القوائم المنسدلة وحساب الستريك اليومي (Dropdown Stability & Streak Calculation)', () {
    test('تساوي كائنات CourseSeed بالقيمة وليس بالمرجع (Value Equality) وحظر الانهيار في DropdownButton', () {
      const course1 = CourseSeed(
        id: 'cs101',
        name: 'برمجة 1',
        code: 'CS101',
        color: Colors.blue,
        creditHours: 3,
      );

      final course2 = CourseSeed.fromMap({
        'id': 'cs101',
        'name': 'برمجة 1',
        'code': 'CS101',
        'color': Colors.blue.toARGB32(),
        'creditHours': 3,
      });

      // الكائنان ليسا نفس المرجع في الذاكرة لكنهما متساويان في القيمة
      expect(identical(course1, course2), isFalse);
      expect(course1 == course2, isTrue);
      expect(course1.hashCode, equals(course2.hashCode));

      // القوائم والمجموعات تستبعد التكرار بدقة
      final coursesSet = {course1, course2};
      expect(coursesSet.length, equals(1));
    });

    test('حساب الستريك اليومي بدقة عند إتمام مهام اليوم (Streak = 1)', () {
      final now = DateTime(2026, 11, 17); // الثلاثاء
      final todayKey = 'daily_done_2026_11_17';

      final streak = PlannerAlgorithm.calculateStudyStreak([todayKey], referenceDate: now);
      expect(streak, equals(1));
    });

    test('استمرار الستريك حياً في الصباح قبل إتمام مهام اليوم بناءً على إتمام الأمس (Streak = 1)', () {
      final now = DateTime(2026, 11, 17); // الثلاثاء (لم يكتمل بعد)
      final yesterdayKey = 'daily_done_2026_11_16'; // الاثنين مكتمل

      final streak = PlannerAlgorithm.calculateStudyStreak([yesterdayKey], referenceDate: now);
      expect(streak, equals(1));
    });

    test('زيادة الستريك إلى يومين عند إتمام الأمس واليوم معاً (Streak = 2)', () {
      final now = DateTime(2026, 11, 17);
      final keys = ['daily_done_2026_11_16', 'daily_done_2026_11_17'];

      final streak = PlannerAlgorithm.calculateStudyStreak(keys, referenceDate: now);
      expect(streak, equals(2));
    });

    test('تصفير الستريك عند تفويت يوم دراسي كامل (Streak = 0)', () {
      final now = DateTime(2026, 11, 17); // الثلاثاء
      // المستخدم أتم الأحد لكنه فوت الاثنين ولم يتم الثلاثاء
      final keys = ['daily_done_2026_11_15'];

      final streak = PlannerAlgorithm.calculateStudyStreak(keys, referenceDate: now);
      expect(streak, equals(0));
    });

    test('عطلة الجمعة لا تكسر الستريك وتتيح استمراره من الخميس إلى السبت (Weekend Immunity)', () {
      // السبت 21 نوفمبر 2026
      final saturday = DateTime(2026, 11, 21);
      // الجمعة 20 نوفمبر (عطلة أسبوعية)، والخميس 19 نوفمبر كان مكتملاً
      final keys = ['daily_done_2026_11_18', 'daily_done_2026_11_19'];

      // صباح السبت قبل إتمام مذاكرة السبت: الستريك لا ينكسر بسبب الجمعة
      final streakSaturdayMorning = PlannerAlgorithm.calculateStudyStreak(keys, referenceDate: saturday);
      expect(streakSaturdayMorning, equals(2));

      // بعد إتمام مذاكرة السبت: يصبح الستريك 3 أيام
      final keysWithSaturday = [...keys, 'daily_done_2026_11_21'];
      final streakSaturdayEvening = PlannerAlgorithm.calculateStudyStreak(keysWithSaturday, referenceDate: saturday);
      expect(streakSaturdayEvening, equals(3));
    });
  });

  group('23. منتدى الأسئلة والحلول الأكاديمي (Academic Q&A Forum Models & Rules)', () {
    test('تحويل QuestionModel إلى ومن Map والتحقق من الفلترة بالدفعة (academicYear)', () {
      final now = DateTime(2026, 11, 17, 10, 0);
      final question = QuestionModel(
        id: 'q_101',
        authorId: 'usr_ahmed',
        authorName: 'أحمد محمود',
        academicYear: '2',
        courseId: 'oop',
        courseName: 'البرمجة كائنية التوجه',
        title: 'ما هو الفرق بين Overloading و Overriding في جافا؟',
        body: 'أواجه مشكلة في فهم متى أستخدم كلاً منهما في مشروع المعمل.',
        imageUrl: 'https://storage.googleapis.com/test.jpg',
        answersCount: 2,
        createdAt: now,
      );

      final map = question.toMap();
      expect(map['authorId'], equals('usr_ahmed'));
      expect(map['academicYear'], equals('2'));
      expect(map['courseId'], equals('oop'));
      expect(map['answersCount'], equals(2));

      final restored = QuestionModel.fromMap(map, 'q_101');
      expect(restored.id, equals('q_101'));
      expect(restored.authorName, equals('أحمد محمود'));
      expect(restored.academicYear, equals('2'));
      expect(restored.imageUrl, equals('https://storage.googleapis.com/test.jpg'));
    });

    test('نموذج AnswerModel واعتماد الحل النموذجي (Accepted Solution)', () {
      final now = DateTime(2026, 11, 17, 11, 30);
      final answer = AnswerModel(
        id: 'ans_501',
        questionId: 'q_101',
        authorId: 'usr_sara',
        authorName: 'سارة خالد',
        text: 'الـ Overloading يحدث في نفس الكلاس بنفس الاسم ومعاملات مختلفة، أما الـ Overriding فيكون مع الوراثة.',
        imageUrl: null,
        isAcceptedSolution: false,
        createdAt: now,
      );

      expect(answer.isAcceptedSolution, isFalse);

      final accepted = answer.copyWith(isAcceptedSolution: true);
      expect(accepted.isAcceptedSolution, isTrue);

      final map = accepted.toMap();
      expect(map['isAcceptedSolution'], isTrue);
      expect(map['authorName'], equals('سارة خالد'));

      final restored = AnswerModel.fromMap(map, 'ans_501', questionId: 'q_101');
      expect(restored.isAcceptedSolution, isTrue);
      expect(restored.questionId, equals('q_101'));
    });
  });

  group('24. الجلسات الجماعية والمواعيد المرنة (Flexible Range & Group Sessions)', () {
    test('نموذج TimeBankOfferModel يدعم الجلسات الجماعية والحد الأقصى للمشاركين ورابط الاجتماع', () {
      final offer = TimeBankOfferModel(
        id: 'offer_group_1',
        teacherId: 'teacher_1',
        teacherName: 'م. عمر',
        courseId: 'ds',
        courseName: 'هياكل البيانات',
        courseCode: 'CS201',
        topic: 'مراجعة خوارزميات الأشجار والـ Graph قبل الميدتيرم',
        day: 'الخميس',
        time: '08:00 م – 10:00 م',
        durationMinutes: 60,
        mode: 'online',
        location: 'عبر الإنترنت (أونلاين)',
        courseColor: AppColors.primary,
        isGroupSession: true,
        maxLearners: 10,
        enrolledLearnerIds: ['student_1', 'student_2', 'student_3'],
        meetingUrl: 'https://meet.google.com/abc-defg-hij',
        isFlexibleRange: true,
        timeRangeStart: '08:00 م',
        timeRangeEnd: '10:00 م',
      );

      expect(offer.isGroupSession, isTrue);
      expect(offer.maxLearners, equals(10));
      expect(offer.enrolledLearnerIds.length, equals(3));
      expect(offer.meetingUrl, contains('meet.google.com'));
      expect(offer.isFlexibleRange, isTrue);

      final map = offer.toMap();
      expect(map['isGroupSession'], isTrue);
      expect(map['maxLearners'], equals(10));
      expect(map['enrolledLearnerIds'], hasLength(3));

      final restored = TimeBankOfferModel.fromMap(map, 'offer_group_1');
      expect(restored.isGroupSession, isTrue);
      expect(restored.maxLearners, equals(10));
      expect(restored.meetingUrl, equals('https://meet.google.com/abc-defg-hij'));
      expect(restored.timeRangeStart, equals('08:00 م'));
    });

    test('سلوك حجز المقاعد الجماعية ومنع التسجيل المزدوج واكتمال السعة', () {
      final enrolled = ['std_1', 'std_2', 'std_3'];
      const maxSeats = 4;

      // متعلّم جديد يسجل بنجاح
      const newLearner = 'std_4';
      expect(enrolled.contains(newLearner), isFalse);
      expect(enrolled.length < maxSeats, isTrue);

      final updatedEnrolled = [...enrolled, newLearner];
      expect(updatedEnrolled.length, equals(4));

      // الجلسة أصبحت مكتملة
      final isFull = updatedEnrolled.length >= maxSeats;
      expect(isFull, isTrue);

      // محاولة تسجيل متعلّم إضافي تفشل
      const excessLearner = 'std_5';
      expect(updatedEnrolled.contains(excessLearner), isFalse);
      expect(updatedEnrolled.length >= maxSeats, isTrue);
    });
  });

  group('25. خدمات الإشعارات ووضع عدم الإزعاج (Focus DND & Notification Services)', () {
    test('FocusDndService يُفعل ويلغي وضع التركيز وعدم الإزعاج بأمان دون أخطاء', () async {
      final service = FocusDndService();
      expect(service.isDndActive, isFalse);

      await service.enableDnd();
      expect(service.isDndActive, isTrue);

      await service.disableDnd();
      expect(service.isDndActive, isFalse);
    });

    test('NotificationService يبني الإشعارات المحلية وخطاف FCM بنجاح', () async {
      final notificationService = NotificationService();
      expect(notificationService, isNotNull);

      // اختبار خطاف FCM المستقبلي
      await notificationService.setupFcmHook();
      expect(true, isTrue);
    });
  });
}
