// مطور 1
// خوارزمية: توزيع جلسات المذاكرة الذكية (Greedy Study Planner Algorithm)
// تعتمد معادلة الأولوية: الأولوية = (6 - التقييم الذاتي) × (1 / الأيام المتبقية للامتحان)

import '../constants/app_constants.dart';
import '../models/app_models.dart';

class CourseStudyInput {
  final CourseSeed course;
  final int selfRating; // 1 to 5
  final int daysUntilExam; // e.g. 14, 21, 30
  final List<String> topics;

  CourseStudyInput({
    required this.course,
    required this.selfRating,
    required this.daysUntilExam,
    required this.topics,
  });

  double calculateInitialPriority() {
    final effectiveRating = selfRating.clamp(1, 5);
    final effectiveDays = daysUntilExam.clamp(1, 120);
    // الأولوية = (6 - التقييم) × (1 / الأيام للامتحان)
    return (6.0 - effectiveRating) * (1.0 / effectiveDays);
  }
}

class PlannerAlgorithm {
  static const int blockDurationMinutes = 45; // مدة كتلة المذاكرة
  static const int breakDurationMinutes = 10; // مدة الاستراحة
  static const double diversityDecay = 0.8;   // معامل تخفيض الأولوية للتنوع
  static const int defaultMaxDailyMinutes = 180; // 3 ساعات كحد أقصى يومياً

  /// توليد خطة المذاكرة الأسبوعية بالخوارزمية الجشعة
  static List<StudyBlockModel> generateWeeklyPlan({
    required List<CourseStudyInput> courseInputs,
    required List<ScheduleItemModel> lectureSchedule,
    int maxDailyStudyMinutes = defaultMaxDailyMinutes,
  }) {
    final List<StudyBlockModel> generatedBlocks = [];
    if (courseInputs.isEmpty) return generatedBlocks;

    final days = ['السبت', 'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final Map<String, double> currentPriorities = {};
    final Map<String, int> topicIndexTracker = {};

    for (final input in courseInputs) {
      currentPriorities[input.course.id] = input.calculateInitialPriority();
      topicIndexTracker[input.course.id] = 0;
    }

    // فترات الفراغ القياسية المتاحة للدراسة في كل يوم
    final Map<String, List<Map<String, String>>> standardSlots = {
      'السبت': [
        {'start': '11:00 ص', 'end': '11:45 ص', 'room': 'المكتبة المركزية'},
        {'start': '02:00 م', 'end': '02:45 م', 'room': 'مكتبة الكلية طابق 2'},
        {'start': '06:00 م', 'end': '06:45 م', 'room': 'المنزل'},
      ],
      'الأحد': [
        {'start': '10:30 ص', 'end': '11:15 ص', 'room': 'قاعة الاستذكار 1'},
        {'start': '01:00 م', 'end': '01:45 م', 'room': 'معمل الحاسب 2'},
        {'start': '05:00 م', 'end': '05:45 م', 'room': 'المنزل'},
      ],
      'الاثنين': [
        {'start': '12:00 م', 'end': '12:45 م', 'room': 'مكتبة الكلية'},
        {'start': '03:00 م', 'end': '03:45 م', 'room': 'قاعة 4'},
        {'start': '07:00 م', 'end': '07:45 م', 'room': 'المنزل'},
      ],
      'الثلاثاء': [
        {'start': '11:30 ص', 'end': '12:15 م', 'room': 'المكتبة المركزية'},
        {'start': '02:30 م', 'end': '03:15 م', 'room': 'معمل 3'},
        {'start': '06:00 م', 'end': '06:45 م', 'room': 'المنزل'},
      ],
      'الأربعاء': [
        {'start': '10:00 ص', 'end': '10:45 ص', 'room': 'قاعة الاستذكار 2'},
        {'start': '01:30 م', 'end': '02:15 م', 'room': 'مكتبة الكلية'},
        {'start': '05:30 م', 'end': '06:15 م', 'room': 'المنزل'},
      ],
      'الخميس': [
        {'start': '11:00 ص', 'end': '11:45 ص', 'room': 'المكتبة المركزية'},
        {'start': '03:00 م', 'end': '03:45 م', 'room': 'المنزل'},
      ],
    };

    int blockIdCounter = 1;

    for (final day in days) {
      final availableSlots = standardSlots[day] ?? [];
      int dailyMinutesUsed = 0;

      for (final slot in availableSlots) {
        if (dailyMinutesUsed + blockDurationMinutes > maxDailyStudyMinutes) {
          break; // تجاوز الحد الأقصى للمذاكرة اليومية (3 ساعات)
        }

        // اختيار المادة الأعلى أولوية حالياً (Greedy Selection)
        String? bestCourseId;
        double highestPriority = -1.0;

        for (final entry in currentPriorities.entries) {
          if (entry.value > highestPriority) {
            highestPriority = entry.value;
            bestCourseId = entry.key;
          }
        }

        if (bestCourseId == null) break;

        final courseInput = courseInputs.firstWhere((c) => c.course.id == bestCourseId);
        final topicList = courseInput.topics.isNotEmpty
            ? courseInput.topics
            : ['مراجعة وتمارين شاملة'];

        final currentTopicIdx = topicIndexTracker[bestCourseId] ?? 0;
        final selectedTopic = topicList[currentTopicIdx % topicList.length];
        topicIndexTracker[bestCourseId] = currentTopicIdx + 1;

        // حجز كتلة المذاكرة
        generatedBlocks.add(
          StudyBlockModel(
            id: 'block_$blockIdCounter',
            courseId: courseInput.course.id,
            courseName: courseInput.course.name,
            courseCode: courseInput.course.code,
            topic: selectedTopic,
            day: day,
            startTime: slot['start']!,
            endTime: slot['end']!,
            durationMinutes: blockDurationMinutes,
            ribbonColor: courseInput.course.color,
            room: slot['room']!,
            isCompleted: day == 'السبت' && dailyMinutesUsed == 0, // كتلة سابقة مكتملة للتجربة
          ),
        );

        blockIdCounter++;
        dailyMinutesUsed += blockDurationMinutes;

        // ضرب الأولوية في 0.8 لضمان التنوع وعدم احتكار نفس المادة (Diversity Decay)
        currentPriorities[bestCourseId] = (currentPriorities[bestCourseId] ?? 1.0) * diversityDecay;
      }
    }

    return generatedBlocks;
  }

  /// إرجاع بيانات الإدخال الافتراضية لمواد الفصل الدراسي لطلاب الفرقة الثانية
  static List<CourseStudyInput> getDefaultSeedInputs() {
    return [
      CourseStudyInput(
        course: AppConstants.seedCourses[0], // OOP
        selfRating: 3,
        daysUntilExam: 25,
        topics: ['البرمجة الكائنية والوراثة', 'تعدد الأشكال (Polymorphism)', 'حل شيت المعمل والاختبارات'],
      ),
      CourseStudyInput(
        course: AppConstants.seedCourses[1], // Data Structures
        selfRating: 2,
        daysUntilExam: 18,
        topics: ['الأشجار الثنائية و AVL', 'جداول التجزئة (Hash Tables)', 'خوارزميات الرسوم البيانية Graph'],
      ),
      CourseStudyInput(
        course: AppConstants.seedCourses[2], // Databases
        selfRating: 2,
        daysUntilExam: 22,
        topics: ['نماذج العلاقات ERD', 'استعلامات SQL المتقدمة', 'التطبيع Normalization'],
      ),
      CourseStudyInput(
        course: AppConstants.seedCourses[3], // Linear Algebra
        selfRating: 1, // يحتاج مساعدة أعلى أولوية
        daysUntilExam: 14,
        topics: ['الفضاءات المتجهة', 'التحويلات الخطية والمصفوفات', 'القيم والمتجهات الذاتية'],
      ),
      CourseStudyInput(
        course: AppConstants.seedCourses[4], // Calculus
        selfRating: 2,
        daysUntilExam: 20,
        topics: ['التكامل الثنائي والثلاثي', 'المتسلسلات اللانهائية', 'تطبيقات على المعادلات التفاضلية'],
      ),
      CourseStudyInput(
        course: AppConstants.seedCourses[5], // Computer Org
        selfRating: 3,
        daysUntilExam: 28,
        topics: ['هيكلية المعالج ALU و Control Unit', 'مسجلات الذاكرة والـ Pipelining', 'لغة التجميع Assembly'],
      ),
    ];
  }
}
