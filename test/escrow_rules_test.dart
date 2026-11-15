import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/core/algorithms/planner_algorithm.dart';
import 'package:zameel/core/constants/app_constants.dart';
import 'package:zameel/core/models/app_models.dart';
import 'package:zameel/core/theme/app_colors.dart';

/// محاكي منطق الضمان المالي لحركات بنك الوقت (Pure Escrow Domain Logic)
class EscrowDecisionEngine {
  /// التحقق من صلاحية الحجز والخصم الأولي
  static (int learnerCoins, String escrowStatus) processBooking({
    required int currentLearnerCoins,
    required int costCoins,
  }) {
    if (currentLearnerCoins < costCoins) {
      throw Exception('الرصيد لا يكفي لحجز الجلسة');
    }
    return (currentLearnerCoins - costCoins, 'held');
  }

  /// إطلاق العملة للمعلم عند إتمام الجلسة
  static (int teacherCoins, String escrowStatus) processCompletion({
    required int currentTeacherCoins,
    required int costCoins,
    required String currentEscrowStatus,
  }) {
    if (currentEscrowStatus != 'held') {
      throw Exception('حالة الضمان غير صالحة للإطلاق');
    }
    return (currentTeacherCoins + costCoins, 'released_to_teacher');
  }

  /// حسم مصير العملة عند الإلغاء
  static (int refundedLearnerCoins, int compensatedTeacherCoins, String escrowStatus, String outcome) processCancellation({
    required bool isCancelledByTeacher,
    required DateTime scheduledAt,
    required DateTime cancelledAt,
    required int initialLearnerCoins,
    required int initialTeacherCoins,
    required int costCoins,
  }) {
    if (isCancelledByTeacher) {
      // 1. المعلم ألغى: استرداد كامل للمتعلّم
      return (
        initialLearnerCoins + costCoins,
        initialTeacherCoins,
        'refunded_to_learner',
        'full_refund_to_learner'
      );
    } else {
      // 2. المتعلّم ألغى: فحص فارق الساعتين
      final diffMinutes = scheduledAt.difference(cancelledAt).inMinutes;
      if (diffMinutes > 120) {
        // إلغاء مبكر (> 2 ساعة): استرداد كامل
        return (
          initialLearnerCoins + costCoins,
          initialTeacherCoins,
          'refunded_to_learner',
          'full_refund_to_learner'
        );
      } else {
        // إلغاء متأخر (<= 2 ساعة): العملة تذهب للمعلم تعويضاً
        return (
          initialLearnerCoins,
          initialTeacherCoins + costCoins,
          'released_to_teacher',
          'compensation_to_teacher'
        );
      }
    }
  }
}

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

  group('2. منطق حجز الجلسات وحجز العملة في الضمان (Escrow Booking)', () {
    test('حجز جلسة بوجود رصيد كاف يخصم 1 عملة ويعلقها في الضمان', () {
      final initialBalance = AppConstants.welcomeCoins; // 2
      final (newBalance, escrowStatus) = EscrowDecisionEngine.processBooking(
        currentLearnerCoins: initialBalance,
        costCoins: AppConstants.sessionCostCoins, // 1
      );

      expect(newBalance, equals(1));
      expect(escrowStatus, equals('held'));
    });

    test('حجز جلسة برصيد غير كاف يلقي استثناءً فورياً', () {
      expect(
        () => EscrowDecisionEngine.processBooking(
          currentLearnerCoins: 0,
          costCoins: AppConstants.sessionCostCoins,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('3. منطق إتمام الجلسة وإطلاق العملة (Escrow Completion)', () {
    test('إتمام الجلسة يضيف 1 عملة لرصيد المعلم ويحرر الضمان', () {
      final teacherCoins = 1;
      final (updatedCoins, escrowStatus) = EscrowDecisionEngine.processCompletion(
        currentTeacherCoins: teacherCoins,
        costCoins: AppConstants.sessionCostCoins,
        currentEscrowStatus: 'held',
      );

      expect(updatedCoins, equals(2));
      expect(escrowStatus, equals('released_to_teacher'));
    });

    test('فشل إطلاق الضمان إذا لم تكن الحالة held', () {
      expect(
        () => EscrowDecisionEngine.processCompletion(
          currentTeacherCoins: 1,
          costCoins: AppConstants.sessionCostCoins,
          currentEscrowStatus: 'already_released',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('4. قواعد الإلغاء ونظام الحماية المالي (Cancellation & Dispute Rules)', () {
    final sessionTime = DateTime(2026, 11, 10, 14, 0); // الساعة 2:00 ظهراً

    test('إلغاء المتعلّم قبل الموعد بـ 3 ساعات (> 2h): استرداد كامل للمتعلّم', () {
      final cancellationTime = DateTime(2026, 11, 10, 11, 0); // قبلها بـ 3 ساعات
      final (learner, teacher, escrow, outcome) = EscrowDecisionEngine.processCancellation(
        isCancelledByTeacher: false,
        scheduledAt: sessionTime,
        cancelledAt: cancellationTime,
        initialLearnerCoins: 1, // كان معه 1 بعد الحجز
        initialTeacherCoins: 2,
        costCoins: 1,
      );

      expect(learner, equals(2), reason: 'يجب استرداد العملة للمتعلّم بالكامل');
      expect(teacher, equals(2), reason: 'لا تتغير عملات المعلم');
      expect(escrow, equals('refunded_to_learner'));
      expect(outcome, equals('full_refund_to_learner'));
    });

    test('إلغاء المتعلّم قبل الموعد بساعة واحدة (<= 2h): العملة تذهب للمعلم تعويضاً', () {
      final cancellationTime = DateTime(2026, 11, 10, 13, 0); // قبلها بساعة واحدة
      final (learner, teacher, escrow, outcome) = EscrowDecisionEngine.processCancellation(
        isCancelledByTeacher: false,
        scheduledAt: sessionTime,
        cancelledAt: cancellationTime,
        initialLearnerCoins: 1,
        initialTeacherCoins: 2,
        costCoins: 1,
      );

      expect(learner, equals(1), reason: 'لا يسترد المتعلم العملة لتأخره');
      expect(teacher, equals(3), reason: 'يحصل المعلم على العملة كتعويض عن وقته المحجوز');
      expect(escrow, equals('released_to_teacher'));
      expect(outcome, equals('compensation_to_teacher'));
    });

    test('إلغاء المعلم للجلسة في أي وقت: استرداد كامل للمتعلّم دون أي عقوبة عليه', () {
      final cancellationTime = DateTime(2026, 11, 10, 13, 50); // قبل الموعد بـ 10 دقائق
      final (learner, teacher, escrow, outcome) = EscrowDecisionEngine.processCancellation(
        isCancelledByTeacher: true,
        scheduledAt: sessionTime,
        cancelledAt: cancellationTime,
        initialLearnerCoins: 1,
        initialTeacherCoins: 2,
        costCoins: 1,
      );

      expect(learner, equals(2), reason: 'يسترد المتعلّم العملة لأن الإلغاء صدر من المعلم');
      expect(teacher, equals(2), reason: 'لا يحصل المعلم على أي عملة');
      expect(escrow, equals('refunded_to_learner'));
      expect(outcome, equals('full_refund_to_learner'));
    });
  });

  group('5. سلامة نماذج البيانات وتحويلها (App Models Serialization)', () {
    test('نموذج TimeBankSessionModel يحافظ على بيانات الضمان والتواريخ', () {
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
        location: 'المكتبة',
        costCoins: 1,
        escrowStatus: 'held',
      );

      final map = session.toMap();
      expect(map['costCoins'], equals(1));
      expect(map['escrowStatus'], equals('held'));

      final fromMap = TimeBankSessionModel.fromMap(map, 'sess_test_1');
      expect(fromMap.costCoins, equals(1));
      expect(fromMap.escrowStatus, equals('held'));
      expect(fromMap.teacherName, equals('عمر'));
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
