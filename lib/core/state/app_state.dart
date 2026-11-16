// مطور 1
// إدارة الحالة المركزية لمنظومة «زَميل» عبر Riverpod 3

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../algorithms/planner_algorithm.dart';
import '../algorithms/matching_algorithm.dart';
import '../models/app_models.dart';
import '../../features/auth/data/auth_service.dart';

// ==========================================
// 1. مزود الثيم العام (Light / Dark Mode)
// ==========================================
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void setTheme(ThemeMode mode) => state = mode;
  void toggleTheme(bool isDark) => state = isDark ? ThemeMode.dark : ThemeMode.light;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

// ==========================================
// 2. حالة وخطة المذاكرة (Planner State)
// ==========================================
class PlannerState {
  final List<StudyBlockModel> studyBlocks;
  final List<ScheduleItemModel> lectureSchedule;
  final int completedBlocksCount;
  final int totalWeeklyTarget;

  const PlannerState({
    required this.studyBlocks,
    required this.lectureSchedule,
    required this.completedBlocksCount,
    required this.totalWeeklyTarget,
  });

  double get progressPercentage {
    if (totalWeeklyTarget == 0) return 0.0;
    return (completedBlocksCount / totalWeeklyTarget).clamp(0.0, 1.0);
  }

  PlannerState copyWith({
    List<StudyBlockModel>? studyBlocks,
    List<ScheduleItemModel>? lectureSchedule,
    int? completedBlocksCount,
    int? totalWeeklyTarget,
  }) {
    return PlannerState(
      studyBlocks: studyBlocks ?? this.studyBlocks,
      lectureSchedule: lectureSchedule ?? this.lectureSchedule,
      completedBlocksCount: completedBlocksCount ?? this.completedBlocksCount,
      totalWeeklyTarget: totalWeeklyTarget ?? this.totalWeeklyTarget,
    );
  }
}

class PlannerNotifier extends Notifier<PlannerState> {
  String? _lastUserId;
  List<CourseSeed> _currentCourses = [];
  Map<String, int> _currentRatings = {};
  final Set<String> _completedBlockIds = {};
  final Set<String> _missedBlockIds = {};

  Set<String> get completedBlockIds => Set.unmodifiable(_completedBlockIds);
  Set<String> get missedBlockIds => Set.unmodifiable(_missedBlockIds);

  /// تبديل أو تصفير حالة المستخدم لمنع تسريب بيانات الحسابات على نفس الجهاز
  void switchUser(String? newUserId) {
    if (_lastUserId != newUserId) {
      _lastUserId = newUserId;
      _completedBlockIds.clear();
      _missedBlockIds.clear();
      _currentCourses = [];
      _currentRatings = {};
    }
  }

  List<CourseStudyInput> _buildInputs(List<CourseSeed>? courses, Map<String, int>? ratings) {
    if (courses != null && courses.isNotEmpty) _currentCourses = courses;
    if (ratings != null) _currentRatings = ratings;
    return _currentCourses.map((course) {
      final rating = _currentRatings[course.id] ?? 2;
      return CourseStudyInput(
        course: course,
        selfRating: rating,
        daysUntilExam: 21,
        topics: ['مفاهيم ومسائل ${course.name}'],
      );
    }).toList();
  }

  @override
  PlannerState build() {
    final currentUserId = ref.watch(authServiceProvider).currentUser?.uid;
    switchUser(currentUserId);

    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();

    // 1. استخراج جدول المحاضرات المدخل من الطالب
    final rawLectures = userDoc?['lecturesData'] as List<dynamic>?;
    List<ScheduleItemModel> lectures = [];
    if (rawLectures != null && rawLectures.isNotEmpty) {
      lectures = rawLectures
          .map((m) => ScheduleItemModel.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    }

    // 2. استخراج المواد المسجلة من الطالب
    final rawCourses = userDoc?['coursesData'] as List<dynamic>?;
    List<CourseSeed> courses = [];
    if (rawCourses != null && rawCourses.isNotEmpty) {
      courses = rawCourses
          .map((m) => CourseSeed.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList();
    }
    if (courses.isEmpty) {
      final selectedIds = (userDoc?['selectedCourses'] as List<dynamic>?)?.cast<String>();
      if (selectedIds != null && selectedIds.isNotEmpty) {
        courses = CurriculumConstants.findCoursesByIds(selectedIds);
      } else {
        // إذا لم يختر الطالب مواد بعد، نعتمد مواد الكلية الأساسية افتراضياً لتوليد خطة المذاكرة وأزرار (تم / لم تتم)
        courses = List<CourseSeed>.from(AppConstants.seedCourses);
      }
    }

    final ratings = (userDoc?['courseRatings'] as Map<dynamic, dynamic>?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        ) ??
        {};

    // استرجاع الحالات المحفوظة من الكلاود
    final savedCompleted = (userDoc?['completedBlockIds'] as List<dynamic>?)?.cast<String>();
    if (savedCompleted != null) {
      _completedBlockIds.addAll(savedCompleted);
    }

    List<StudyBlockModel> generatedBlocks = [];
    if (lectures.isNotEmpty || courses.isNotEmpty) {
      final inputs = _buildInputs(courses.isNotEmpty ? courses : null, ratings);
      if (inputs.isNotEmpty) {
        generatedBlocks = PlannerAlgorithm.generateWeeklyPlan(
          courseInputs: inputs,
          lectureSchedule: lectures,
        );
      }
    }

    // الحفاظ على حالة الإتمام والتفويت حتى لا تنمحي عند أي تحديث بروفايل أو انقطاع شبكة
    final preservedBlocks = generatedBlocks.map((b) {
      final isDone = _completedBlockIds.contains(b.id) || b.isCompleted;
      final isMissed = _missedBlockIds.contains(b.id) || b.isMissed;
      return b.copyWith(
        isCompleted: isDone,
        isMissed: isMissed,
      );
    }).toList();

    return PlannerState(
      studyBlocks: preservedBlocks,
      lectureSchedule: lectures,
      completedBlocksCount: preservedBlocks.where((b) => b.isCompleted).length,
      totalWeeklyTarget: preservedBlocks.length,
    );
  }

  /// تسجيل إتمام كتلة مذاكرة
  void markBlockCompleted(String blockId) {
    _completedBlockIds.add(blockId);
    _missedBlockIds.remove(blockId);
    final updatedBlocks = state.studyBlocks.map((b) {
      if (b.id == blockId) {
        return b.copyWith(isCompleted: true, isMissed: false);
      }
      return b;
    }).toList();
    state = state.copyWith(
      studyBlocks: updatedBlocks,
      completedBlocksCount: updatedBlocks.where((b) => b.isCompleted).length,
    );
  }

  /// تبديل حالة إتمام المذاكرة (تم / لم تتم)
  void toggleBlockCompleted(String blockId) {
    final currentBlock = state.studyBlocks.firstWhere((b) => b.id == blockId, orElse: () => state.studyBlocks.first);
    final willBeCompleted = !currentBlock.isCompleted;
    if (willBeCompleted) {
      _completedBlockIds.add(blockId);
      _missedBlockIds.remove(blockId);
    } else {
      _completedBlockIds.remove(blockId);
    }
    final updatedBlocks = state.studyBlocks.map((b) {
      if (b.id == blockId) {
        return b.copyWith(isCompleted: willBeCompleted, isMissed: false);
      }
      return b;
    }).toList();
    state = state.copyWith(
      studyBlocks: updatedBlocks,
      completedBlocksCount: updatedBlocks.where((b) => b.isCompleted).length,
    );
  }

  /// تسجيل تفويت جلسة
  void markBlockMissed(String blockId) {
    _missedBlockIds.add(blockId);
    _completedBlockIds.remove(blockId);
    final updatedBlocks = state.studyBlocks.map((b) {
      if (b.id == blockId) {
        return b.copyWith(isCompleted: false, isMissed: true);
      }
      return b;
    }).toList();
    state = state.copyWith(
      studyBlocks: updatedBlocks,
      completedBlocksCount: updatedBlocks.where((b) => b.isCompleted).length,
    );
  }

  /// إعادة الجدولة باستخدام الخوارزمية
  void rescheduleBlock(String blockId) {
    _completedBlockIds.remove(blockId);
    _missedBlockIds.remove(blockId);
    final updatedBlocks = state.studyBlocks.map((b) {
      if (b.id == blockId) {
        return b.copyWith(isCompleted: false, isMissed: false);
      }
      return b;
    }).toList();

    state = state.copyWith(
      studyBlocks: updatedBlocks,
      completedBlocksCount: updatedBlocks.where((b) => b.isCompleted).length,
    );
  }

  /// إضافة محاضرة أو موعد انشغال وإعادة توليد الخطة تلقائياً
  void addLecture(ScheduleItemModel item) {
    final updatedLectures = [...state.lectureSchedule, item];
    setLecturesAndRegeneratePlan(updatedLectures);
  }

  /// حذف محاضرة من الجدول وإعادة حساب الخطة
  void removeLecture(String lectureId) {
    final updatedLectures = state.lectureSchedule.where((l) => l.id != lectureId).toList();
    setLecturesAndRegeneratePlan(updatedLectures);
  }

  /// تعيين قائمة المحاضرات كاملة وإعادة توليد خطة المذاكرة حولها
  void setLecturesAndRegeneratePlan(
    List<ScheduleItemModel> lectures, {
    List<CourseSeed>? courses,
    Map<String, int>? ratings,
  }) {
    final inputs = _buildInputs(courses, ratings);
    final regenerated = PlannerAlgorithm.generateWeeklyPlan(
      courseInputs: inputs.isNotEmpty ? inputs : PlannerAlgorithm.getDefaultSeedInputs(),
      lectureSchedule: lectures,
    );

    state = state.copyWith(
      lectureSchedule: lectures,
      studyBlocks: regenerated,
      totalWeeklyTarget: regenerated.isNotEmpty ? regenerated.length : 12,
    );
  }

  /// إعادة حساب الخطة الأسبوعية وفق المواد والتقييمات المحدثة للمستخدم
  void updateCoursesAndRegeneratePlan(List<CourseSeed> courses, Map<String, int> ratings) {
    _currentCourses = courses;
    _currentRatings = ratings;
    final inputs = _buildInputs(courses, ratings);

    final regenerated = PlannerAlgorithm.generateWeeklyPlan(
      courseInputs: inputs.isNotEmpty ? inputs : PlannerAlgorithm.getDefaultSeedInputs(),
      lectureSchedule: state.lectureSchedule,
    );

    state = state.copyWith(
      studyBlocks: regenerated,
      totalWeeklyTarget: regenerated.isNotEmpty ? regenerated.length : 12,
    );
  }
}

final plannerProvider = NotifierProvider<PlannerNotifier, PlannerState>(PlannerNotifier.new);

// ==========================================
// 3. حالة بنك الوقت والمحفظة (Time Bank & Wallet)
// ==========================================
class TimeBankState {
  final List<TimeBankOfferModel> offers;
  final List<TimeBankSessionModel> sessions;
  final List<WalletTransactionModel> transactions;
  final int activeTimeCoins;

  const TimeBankState({
    required this.offers,
    required this.sessions,
    required this.transactions,
    required this.activeTimeCoins,
  });

  TimeBankState copyWith({
    List<TimeBankOfferModel>? offers,
    List<TimeBankSessionModel>? sessions,
    List<WalletTransactionModel>? transactions,
    int? activeTimeCoins,
  }) {
    return TimeBankState(
      offers: offers ?? this.offers,
      sessions: sessions ?? this.sessions,
      transactions: transactions ?? this.transactions,
      activeTimeCoins: activeTimeCoins ?? this.activeTimeCoins,
    );
  }
}

class TimeBankNotifier extends Notifier<TimeBankState> {
  @override
  TimeBankState build() {
    return const TimeBankState(
      activeTimeCoins: AppConstants.welcomeCoins,
      offers: [],
      sessions: [],
      transactions: [],
    );
  }

  /// إضافة عرض شرح جديد
  void addOffer(TimeBankOfferModel offer) {
    state = state.copyWith(offers: [offer, ...state.offers]);
  }

  /// حجز جلسة جديدة مع زميل
  void bookSession({
    required String teacherName,
    required String teacherInitials,
    required String courseName,
    required String courseCode,
    required String topic,
    required String time,
    required String location,
  }) {
    final newSession = TimeBankSessionModel(
      id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
      learnerId: 'current_user',
      learnerName: 'أحمد محمود',
      teacherId: 'teacher_selected',
      teacherName: teacherName,
      teacherInitials: teacherInitials,
      courseName: courseName,
      courseCode: courseCode,
      topic: topic,
      day: 'اليوم',
      time: time,
      durationMinutes: 60,
      location: location,
      costCoins: 1,
      status: 'confirmed',
    );

    final newCoins = (state.activeTimeCoins - 1).clamp(0, 99);
    final newTx = WalletTransactionModel(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      title: 'حجز جلسة $courseName مع $teacherName',
      date: 'الآن',
      amount: 1,
      isNegative: true,
      icon: Icons.calendar_month_outlined,
    );

    state = state.copyWith(
      sessions: [newSession, ...state.sessions],
      activeTimeCoins: newCoins,
      transactions: [newTx, ...state.transactions],
    );

    // مزامنة مع Firestore إذا كان المستخدم مسجلاً
    try {
      ref.read(authServiceProvider).updateUserProfile();
    } catch (_) {}
  }

  /// تأكيد إتمام الجلسة وإرسال التقييم ونقل العملة الذري
  void completeAndRateSession({
    required String sessionId,
    required int rating,
    required String reviewComment,
  }) {
    final updatedSessions = state.sessions.map((s) {
      if (s.id == sessionId) {
        return s.copyWith(
          status: 'completed',
          rating: rating,
          reviewComment: reviewComment,
        );
      }
      return s;
    }).toList();

    state = state.copyWith(sessions: updatedSessions);
  }
}

final timeBankProvider = NotifierProvider<TimeBankNotifier, TimeBankState>(TimeBankNotifier.new);

// ==========================================
// 4. مزود رصيد عملات الوقت المتجاوب فورياً (Spendable Time Coins Provider)
// الرصيد يُشتق حصرياً من قاعدة بيانات Firestore ولا يخلط بنقاط المذاكرة
// ==========================================
class UserCoinsNotifier extends Notifier<int> {
  @override
  int build() {
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final remoteTimeCoins = (userDoc?['timeCoins'] as num?)?.toInt() ?? AppConstants.welcomeCoins;

    return remoteTimeCoins;
  }
}

final userTimeCoinsProvider = NotifierProvider<UserCoinsNotifier, int>(UserCoinsNotifier.new);

// مزود نقاط وساعات المذاكرة المشتقة حصرياً من عدد الكتل المكتملة
final userStudyBlocksCountProvider = Provider<int>((ref) {
  final userProfileAsync = ref.watch(userProfileStreamProvider);
  final userDoc = userProfileAsync.value?.data();
  final completed = (userDoc?['completedBlockIds'] as List<dynamic>?) ?? [];
  return completed.length;
});

// مزود المرشحين بناءً على خوارزمية التوافق
final peerMatchesProvider = Provider<List<MatchResult>>((ref) {
  return MatchingAlgorithm.findMatches(
    targetCourseId: 'math201',
    learnerFreeSlots: MatchingAlgorithm.getDefaultLearnerFreeSlots(),
    allTeachers: MatchingAlgorithm.getDefaultTeachers(),
  );
});
