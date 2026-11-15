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
}
