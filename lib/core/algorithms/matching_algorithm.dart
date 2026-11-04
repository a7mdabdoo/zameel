// مطور 1
// خوارزمية: مطابقة أوقات الفراغ المشتركة وترشيح الأقران (Shared Free Slots & Peer Matching)

class TimeInterval {
  final String day;
  final int startMinutes; // بالدقائق من منتصف الليل (e.g. 13:30 = 810)
  final int endMinutes;
  final String label;

  const TimeInterval({
    required this.day,
    required this.startMinutes,
    required this.endMinutes,
    required this.label,
  });

  int get durationMinutes => endMinutes - startMinutes;

  /// فحص التقاطع الزمني بين فترتين في نفس اليوم
  TimeInterval? intersectWith(TimeInterval other) {
    if (day != other.day) return null;
    final maxStart = startMinutes > other.startMinutes ? startMinutes : other.startMinutes;
    final minEnd = endMinutes < other.endMinutes ? endMinutes : other.endMinutes;

    if (minEnd - maxStart >= 30) {
      // يوجد تقاطع لا يقل عن 30 دقيقة
      final startH = (maxStart ~/ 60).toString().padLeft(2, '0');
      final startM = (maxStart % 60).toString().padLeft(2, '0');
      final endH = (minEnd ~/ 60).toString().padLeft(2, '0');
      final endM = (minEnd % 60).toString().padLeft(2, '0');

      return TimeInterval(
        day: day,
        startMinutes: maxStart,
        endMinutes: minEnd,
        label: '$day • $startH:$startM – $endH:$endM (${minEnd - maxStart} دقيقة)',
      );
    }
    return null;
  }
}

class PeerTeacherProfile {
  final String id;
  final String name;
  final String initials;
  final double rating; // out of 5.0
  final int totalReviews;
  final List<String> proficientCourseIds;
  final List<TimeInterval> availableSlots;
  final String preferredLocation;
  final String bioNote;

  const PeerTeacherProfile({
    required this.id,
    required this.name,
    required this.initials,
    required this.rating,
    required this.totalReviews,
    required this.proficientCourseIds,
    required this.availableSlots,
    required this.preferredLocation,
    required this.bioNote,
  });
}

class MatchResult {
  final PeerTeacherProfile teacher;
  final int matchScore; // Percentage 0 - 100%
  final List<TimeInterval> sharedSlots;
  final String bestSlotFormatted;

  const MatchResult({
    required this.teacher,
    required this.matchScore,
    required this.sharedSlots,
    required this.bestSlotFormatted,
  });
}

class MatchingAlgorithm {
  /// تشغيل خوارزمية التوافق واستخراج المرشحين مرتبين تنازلياً
  static List<MatchResult> findMatches({
    required String targetCourseId,
    required List<TimeInterval> learnerFreeSlots,
    required List<PeerTeacherProfile> allTeachers,
    int requestedDurationMinutes = 60,
  }) {
    final List<MatchResult> results = [];

    for (final teacher in allTeachers) {
      // شرط أساسي: أن يكون الزميل مؤهلاً في المادة المطلوبة
      final isExpert = teacher.proficientCourseIds.contains(targetCourseId);
      final expertiseScore = isExpert ? 30.0 : 10.0;

      // حساب تقاطع فترات الفراغ المشتركة بين المتعلم والشارح
      final List<TimeInterval> sharedSlots = [];
      for (final learnerSlot in learnerFreeSlots) {
        for (final teacherSlot in teacher.availableSlots) {
          final intersection = learnerSlot.intersectWith(teacherSlot);
          if (intersection != null && intersection.durationMinutes >= requestedDurationMinutes) {
            sharedSlots.add(intersection);
          }
        }
      }

      // حساب مكون التقييم (حد أقصى 40%)
      final ratingScore = (teacher.rating / 5.0).clamp(0.0, 1.0) * 40.0;

      // حساب مكون الإتاحة وتعدد الفترات المشتركة (حد أقصى 30%)
      final availabilityScore = (sharedSlots.length.clamp(1, 5) / 5.0) * 30.0;

      final totalScore = (ratingScore + availabilityScore + expertiseScore).round().clamp(65, 98);

      final bestSlot = sharedSlots.isNotEmpty
          ? sharedSlots.first.label
          : (teacher.availableSlots.isNotEmpty ? teacher.availableSlots.first.label : 'حسب الاتفاق المباشر');

      results.add(
        MatchResult(
          teacher: teacher,
          matchScore: totalScore,
          sharedSlots: sharedSlots,
          bestSlotFormatted: bestSlot,
        ),
      );
    }

    // ترتيب المرشحين بالأعلى تطابقاً (Descending Order)
    results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return results;
  }

  /// إرجاع قائمة بيانات الزملاء المرشحين الافتراضية
  static List<PeerTeacherProfile> getDefaultTeachers() {
    return const [
      PeerTeacherProfile(
        id: 'teacher_1',
        name: 'عمر خالد',
        initials: 'ع.خ',
        rating: 4.9,
        totalReviews: 14,
        proficientCourseIds: ['math201', 'cs202'], // الجبر الخطي، هياكل البيانات
        availableSlots: [
          TimeInterval(day: 'اليوم', startMinutes: 810, endMinutes: 900, label: 'اليوم • 1:30 ظهراً (60 دقيقة)'),
          TimeInterval(day: 'الخميس', startMinutes: 960, endMinutes: 1050, label: 'الخميس • 4:00 عصراً (60 دقيقة)'),
        ],
        preferredLocation: 'معمل 3 أو مكتبة الكلية',
        bioNote: 'متمكن في الجبر الخطي والتحويلات الخطية، وحصل على امتياز في المادة.',
      ),
      PeerTeacherProfile(
        id: 'teacher_2',
        name: 'سارة علي',
        initials: 'س.ع',
        rating: 4.8,
        totalReviews: 9,
        proficientCourseIds: ['math201', 'is201', 'cs201'],
        availableSlots: [
          TimeInterval(day: 'غداً', startMinutes: 660, endMinutes: 720, label: 'غداً • 11:00 صباحاً (45 دقيقة)'),
          TimeInterval(day: 'الثلاثاء', startMinutes: 840, endMinutes: 930, label: 'الثلاثاء • 2:00 ظهراً (60 دقيقة)'),
        ],
        preferredLocation: 'ساحة الكلية • قاعة الاستذكار',
        bioNote: 'شرحت لـ 9 زملاء سابقاً بتقييم ممتاز وتركيز على حل المسائل.',
      ),
      PeerTeacherProfile(
        id: 'teacher_3',
        name: 'محمود يوسف',
        initials: 'م.ي',
        rating: 4.7,
        totalReviews: 6,
        proficientCourseIds: ['math201', 'cs203'],
        availableSlots: [
          TimeInterval(day: 'بعد غد', startMinutes: 840, endMinutes: 930, label: 'بعد غد • 2:00 ظهراً (60 دقيقة)'),
        ],
        preferredLocation: 'معمل الحاسب الآلي',
        bioNote: 'شرح مبسط وخطوة بخطوة مع حل تجميعة أسئلة امتحانات سابقة.',
      ),
    ];
  }

  /// فترات فراغ الطالب المتعلم الافتراضية
  static List<TimeInterval> getDefaultLearnerFreeSlots() {
    return const [
      TimeInterval(day: 'اليوم', startMinutes: 780, endMinutes: 930, label: 'اليوم • 1:00 م – 3:30 م'),
      TimeInterval(day: 'غداً', startMinutes: 630, endMinutes: 750, label: 'غداً • 10:30 ص – 12:30 م'),
      TimeInterval(day: 'الخميس', startMinutes: 900, endMinutes: 1080, label: 'الخميس • 3:00 م – 6:00 م'),
    ];
  }
}
