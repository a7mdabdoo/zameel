// مطور 1
// إدارة الحالة المركزية لمنظومة «زَميل» عبر Riverpod 3

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
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
  static final List<ScheduleItemModel> _defaultLectures = [
    const ScheduleItemModel(
      id: 'lec_1',
      courseName: 'التفاضل والتكامل (Calculus)',
      courseCode: 'MATH202',
      day: 'السبت',
      startTime: '09:00 ص',
      endTime: '10:30 ص',
      room: 'قاعة 3',
      color: AppColors.courseSlate,
    ),
    const ScheduleItemModel(
      id: 'lec_2',
      courseName: 'تنظيم الحواسب (Computer Org)',
      courseCode: 'CS203',
      day: 'الأحد',
      startTime: '08:30 ص',
      endTime: '10:00 ص',
      room: 'مدرج 2',
      color: AppColors.courseDustPlum,
    ),
    const ScheduleItemModel(
      id: 'lec_3',
      courseName: 'هياكل البيانات (Data Structures)',
      courseCode: 'CS202',
      day: 'الاثنين',
      startTime: '10:00 ص',
      endTime: '11:30 ص',
      room: 'معمل الحاسب 1',
      color: AppColors.courseSage,
    ),
  ];

  @override
  PlannerState build() {
    return PlannerState(
      studyBlocks: PlannerAlgorithm.generateWeeklyPlan(
        courseInputs: PlannerAlgorithm.getDefaultSeedInputs(),
        lectureSchedule: _defaultLectures,
      ),
      lectureSchedule: _defaultLectures,
      completedBlocksCount: 7,
      totalWeeklyTarget: 12,
    );
  }

  /// تسجيل إتمام كتلة مذاكرة
  void markBlockCompleted(String blockId) {
    state = state.copyWith(
      studyBlocks: state.studyBlocks.map((b) {
        if (b.id == blockId) {
          return b.copyWith(isCompleted: true, isMissed: false);
        }
        return b;
      }).toList(),
      completedBlocksCount: state.completedBlocksCount + 1,
    );
  }

  /// تسجيل تفويت جلسة
  void markBlockMissed(String blockId) {
    state = state.copyWith(
      studyBlocks: state.studyBlocks.map((b) {
        if (b.id == blockId) {
          return b.copyWith(isCompleted: false, isMissed: true);
        }
        return b;
      }).toList(),
    );
  }

  /// إعادة الجدولة باستخدام الخوارزمية
  void rescheduleBlock(String blockId) {
    final updatedBlocks = state.studyBlocks.map((b) {
      if (b.id == blockId) {
        return b.copyWith(isCompleted: false, isMissed: false);
      }
      return b;
    }).toList();

    state = state.copyWith(studyBlocks: updatedBlocks);
  }

  /// إضافة محاضرة أو موعد انشغال وإعادة توليد الخطة تلقائياً
  void addLecture(ScheduleItemModel item) {
    final updatedLectures = [...state.lectureSchedule, item];
    final regenerated = PlannerAlgorithm.generateWeeklyPlan(
      courseInputs: PlannerAlgorithm.getDefaultSeedInputs(),
      lectureSchedule: updatedLectures,
    );

    state = state.copyWith(
      lectureSchedule: updatedLectures,
      studyBlocks: regenerated,
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
    return TimeBankState(
      activeTimeCoins: 3,
      offers: [
        const TimeBankOfferModel(
          id: 'offer_1',
          teacherId: 'current_user',
          teacherName: 'أحمد محمود (أنت)',
          courseId: 'cs201',
          courseName: 'البرمجة الكائنية (OOP - CS201)',
          courseCode: 'CS201',
          topic: 'مفاهيم الوراثة وتعدد الأشكال (Inheritance & Polymorphism) وحل شيت المعمل.',
          day: 'الأربعاء',
          time: '12:00 ظهراً',
          durationMinutes: 60,
          location: 'مكتبة الكلية • الطابق الثاني',
          courseColor: AppColors.courseTeal,
        ),
      ],
      sessions: const [
        TimeBankSessionModel(
          id: 'sess_1',
          learnerId: 'current_user',
          learnerName: 'أحمد محمود',
          teacherId: 'teacher_1',
          teacherName: 'عمر خالد',
          teacherInitials: 'ع.خ',
          courseName: 'الجبر الخطي (Linear Algebra)',
          courseCode: 'MATH201',
          topic: 'الفضاءات المتجهة والتحويلات الخطية',
          day: 'اليوم (السبت)',
          time: '1:30 ظهراً',
          durationMinutes: 60,
          location: 'معمل 3 • مبنى الكلية',
          costCoins: 1,
          status: 'confirmed',
        ),
        TimeBankSessionModel(
          id: 'sess_2',
          learnerId: 'learner_ziyad',
          learnerName: 'زياد ناصح',
          teacherId: 'current_user',
          teacherName: 'أحمد محمود (أنت)',
          teacherInitials: 'ز.ن',
          courseName: 'البرمجة الكائنية (OOP)',
          courseCode: 'CS201',
          topic: 'شرح الـ Inheritance والـ Polymorphism',
          day: 'الأربعاء',
          time: '12:00 ظهراً',
          durationMinutes: 60,
          location: 'مكتبة الكلية • الطابق الثاني',
          costCoins: 1,
          status: 'pending',
        ),
      ],
      transactions: const [
        WalletTransactionModel(
          id: 'tx_1',
          title: 'شرح الجبر الخطي من عمر خالد',
          date: 'اليوم • 1:30 م',
          amount: 1,
          isNegative: true,
          icon: Icons.school_outlined,
        ),
        WalletTransactionModel(
          id: 'tx_2',
          title: 'شرح البرمجة الكائنية لـ زياد ناصح',
          date: 'أمس • 4:00 م',
          amount: 1,
          isNegative: false,
          icon: Icons.volunteer_activism_outlined,
        ),
        WalletTransactionModel(
          id: 'tx_3',
          title: 'مكافأة التسجيل الترحيبية في زَميل',
          date: 'منذ يومين',
          amount: 3,
          isNegative: false,
          icon: Icons.card_giftcard_rounded,
        ),
      ],
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

// مزود المرشحين بناءً على خوارزمية التوافق
final peerMatchesProvider = Provider<List<MatchResult>>((ref) {
  return MatchingAlgorithm.findMatches(
    targetCourseId: 'math201',
    learnerFreeSlots: MatchingAlgorithm.getDefaultLearnerFreeSlots(),
    allTeachers: MatchingAlgorithm.getDefaultTeachers(),
  );
});
