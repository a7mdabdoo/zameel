// مطور 3
// بنك الوقت الأكاديمي: سوق الجلسات الحي التفاعلي (TimeBank Live Academic Marketplace)

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../features/timebank/data/timebank_repository.dart';

class TimeBankFeedScreen extends ConsumerStatefulWidget {
  const TimeBankFeedScreen({super.key});

  @override
  ConsumerState<TimeBankFeedScreen> createState() => _TimeBankFeedScreenState();
}

// الاسم السابق للحفاظ على التوافق الكامل مع الموجه وشاشات التنقل
typedef MyOffersScreen = TimeBankFeedScreen;

class _TimeBankFeedScreenState extends ConsumerState<TimeBankFeedScreen> {
  // التاب الافتراضي: 0 = استكشف العروض (Marketplace Discovery)، 1 = جلساتي وعروضي
  int _selectedMainTab = 0;
  // التاب الداخلي لجلساتي: 0 = كمتعلّم، 1 = كشارح
  int _selectedSubTab = 0;
  // فلترة المواد
  String _selectedCourseFilter = 'الكل';
  bool _isProcessingAction = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userId = user?.uid ?? '';

    // بيانات المستخدم والفرقة الدراسية
    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final rawAcademicYear = userDoc?['academicYear'];
    String? userAcademicYear;
    if (rawAcademicYear is int) {
      userAcademicYear = CurriculumConstants.academicYearLabels[rawAcademicYear];
    } else if (rawAcademicYear is String) {
      userAcademicYear = rawAcademicYear;
    }

    // استخراج المواد المسجلة للمستخدم للفلترة السريعة
    final rawSelectedCourses = userDoc?['selectedCourses'] as List<dynamic>? ?? [];
    final List<String> userCoursesNames = rawSelectedCourses
        .map((c) => (c is Map ? (c['name'] as String? ?? '') : c.toString()))
        .where((s) => s.isNotEmpty)
        .toList();

    // العروض المتاحة في السوق الحي
    final availableOffersAsync = ref.watch(availableOffersStreamProvider);
    final allOffers = availableOffersAsync.value ?? [];

    // جلسات المستخدم كمتعلم وشارح
    final learnerSessionsAsync = ref.watch(learnerSessionsStreamProvider(userId));
    final learnerSessions = learnerSessionsAsync.value ?? [];

    final userOffersAsync = ref.watch(userOffersStreamProvider(userId));
    final myOffers = userOffersAsync.value ?? [];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final surfaceColor = theme.cardTheme.color ?? (isDark ? const Color(0xFF1E293B) : Colors.white);
    final hairlineColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bolt_rounded, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'سوق الجلسات الأكاديمي ⏱️',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'محفظة الوقت',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            color: primaryColor,
            onPressed: () => context.push('/wallet'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_timebank_create_offer',
        onPressed: () => context.push('/create-offer'),
        backgroundColor: primaryColor,
        icon: Icon(Icons.add_rounded, color: isDark ? AppColors.darkOnPrimary : Colors.white),
        label: Text(
          'أضف عرضاً للشرح 🚀',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkOnPrimary : Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // شريط التبويب العلوي: [ 🌐 استكشف العروض ] | [ 📋 جلساتي وعروضي ]
            Container(
              color: surfaceColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: hairlineColor),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildMainTabItem(
                      index: 0,
                      title: '🌐 استكشف العروض (${allOffers.length})',
                      isSelected: _selectedMainTab == 0,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                    _buildMainTabItem(
                      index: 1,
                      title: '📋 جلساتي وعروضي (${learnerSessions.length + myOffers.length})',
                      isSelected: _selectedMainTab == 1,
                      primaryColor: primaryColor,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            // المحتوى بناءً على التاب المختار
            Expanded(
              child: _selectedMainTab == 0
                  ? _buildMarketplaceFeed(
                      allOffers: allOffers,
                      userId: userId,
                      userCoursesNames: userCoursesNames,
                      userAcademicYear: userAcademicYear,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      surfaceColor: surfaceColor,
                      hairlineColor: hairlineColor,
                    )
                  : _buildMySessionsAndOffers(
                      learnerSessions: learnerSessions,
                      myOffers: myOffers,
                      userId: userId,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      surfaceColor: surfaceColor,
                      hairlineColor: hairlineColor,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainTabItem({
    required int index,
    required String title,
    required bool isSelected,
    required Color primaryColor,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMainTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? (isDark ? AppColors.darkOnPrimary : Colors.white)
                  : (isDark ? Colors.white70 : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // الشاشة 1: استكشف العروض (Marketplace Discovery Feed)
  // =========================================================================
  Widget _buildMarketplaceFeed({
    required List<TimeBankOfferModel> allOffers,
    required String userId,
    required List<String> userCoursesNames,
    required String? userAcademicYear,
    required bool isDark,
    required Color primaryColor,
    required Color surfaceColor,
    required Color hairlineColor,
  }) {
    // 1. فلترة العروض بالمواد
    final filteredOffers = allOffers.where((offer) {
      if (offer.isCompleted) return false;
      if (_selectedCourseFilter == 'الكل') return true;
      return offer.courseName.contains(_selectedCourseFilter) ||
          _selectedCourseFilter.contains(offer.courseName) ||
          offer.courseCode.contains(_selectedCourseFilter);
    }).toList();

    return Column(
      children: [
        // شريط فلترة المواد السريع (Filter Chips)
        Container(
          color: surfaceColor,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('الكل', primaryColor, isDark),
                for (final course in userCoursesNames) ...[
                  const SizedBox(width: 8),
                  _buildFilterChip(course, primaryColor, isDark),
                ],
              ],
            ),
          ),
        ),

        // قائمة بطاقات العروض
        Expanded(
          child: filteredOffers.isEmpty
              ? _buildEmptyOffersPlaceholder(isDark, primaryColor)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredOffers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final offer = filteredOffers[index];
                    return _buildOfferCard(
                      offer: offer,
                      userId: userId,
                      isDark: isDark,
                      primaryColor: primaryColor,
                      surfaceColor: surfaceColor,
                      hairlineColor: hairlineColor,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, Color primaryColor, bool isDark) {
    final isSelected = _selectedCourseFilter == label;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? (isDark ? AppColors.darkOnPrimary : Colors.white)
              : (isDark ? Colors.white70 : AppColors.textPrimary),
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? primaryColor : (isDark ? Colors.white12 : Colors.black12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _selectedCourseFilter = label),
    );
  }

  Widget _buildOfferCard({
    required TimeBankOfferModel offer,
    required String userId,
    required bool isDark,
    required Color primaryColor,
    required Color surfaceColor,
    required Color hairlineColor,
  }) {
    final isTeacher = offer.teacherId == userId;
    final isEnrolled = offer.attendeeIds.contains(userId);
    final isFull = offer.isFull;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEnrolled
              ? AppColors.success.withValues(alpha: 0.5)
              : (isTeacher ? primaryColor.withValues(alpha: 0.4) : hairlineColor),
          width: isEnrolled || isTeacher ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. رأس البطاقة: الزميل الشارح + التقييم + نوع الجلسة
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryColor.withValues(alpha: 0.15),
                child: Text(
                  offer.teacherName.isNotEmpty ? offer.teacherName.substring(0, 1) : 'ز',
                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isTeacher ? 'أنت (الزميل الشارح)' : offer.teacherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isTeacher ? primaryColor : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: offer.teacherRating > 0
                                ? Colors.amber.withValues(alpha: isDark ? 0.25 : 0.12)
                                : (isDark ? AppColors.darkSurfaceAlt : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: offer.teacherRating > 0 ? Colors.amber : (isDark ? Colors.white60 : Colors.black45),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                offer.teacherRating > 0 ? offer.teacherRating.toStringAsFixed(1) : 'جديد',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: offer.teacherRating > 0 ? Colors.amber : (isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'جلسة أونلاين 100% • مدة ${offer.durationMinutes} دقيقة',
                      style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // شارة نوع الجلسة (SessionType Pill)
              _buildSessionTypeBadge(offer.sessionType, isDark, primaryColor),
            ],
          ),

          const SizedBox(height: 12),

          // 2. جسم البطاقة: شارة المادة + عنوان وموضوع الشرح
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              offer.courseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            offer.topic,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, height: 1.3),
          ),

          const SizedBox(height: 10),

          // 3. الموعد المحدد بدقة ورابط الاجتماع
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hairlineColor),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, size: 16, color: primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${offer.day}، ${offer.time}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (offer.meetingUrl != null && offer.meetingUrl!.isNotEmpty) ...[
                  Icon(Icons.videocam_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  const Text(
                    'رابط Meeting متاح',
                    style: TextStyle(fontSize: 10.5, color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4. تذييل البطاقة: عداد المشاركين + زر الإجراء
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // عداد الحضور المباشر
              Row(
                children: [
                  Icon(
                    offer.sessionType == SessionType.group ? Icons.groups_rounded : Icons.person_rounded,
                    size: 17,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    offer.sessionType == SessionType.group
                        ? '${offer.attendeesCount} من ${offer.maxAttendees} زميل'
                        : (offer.isFull ? 'محجوزة بالكامل' : 'مقعد فردي متاح'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: offer.isFull ? AppColors.pointsAmber : null,
                    ),
                  ),
                ],
              ),

              // أزرار الإجراء
              if (isTeacher) ...[
                OutlinedButton.icon(
                  onPressed: () => context.push('/create-offer'),
                  icon: const Icon(Icons.settings_outlined, size: 15),
                  label: const Text('أنت الشارح 👑', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ] else if (isEnrolled) ...[
                FilledButton.tonalIcon(
                  onPressed: () => _openMeetingOrSession(offer),
                  icon: const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                  label: const Text(
                    'أنت منضم ✅',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success.withValues(alpha: 0.15),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ] else if (isFull) ...[
                FilledButton.tonal(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('مكتملة 🔒', style: TextStyle(fontSize: 12)),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _isProcessingAction ? null : () => _confirmAndJoinOffer(offer),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('انضم الآن (1 عملة) ⚡', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTypeBadge(SessionType type, bool isDark, Color primaryColor) {
    final isGroup = type == SessionType.group;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isGroup
            ? (isDark ? const Color(0xFF0369A1).withValues(alpha: 0.3) : const Color(0xFFE0F2FE))
            : (isDark ? const Color(0xFF7C3AED).withValues(alpha: 0.3) : const Color(0xFFEDE9FE)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGroup
              ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
              : (isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6)),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGroup ? Icons.groups_rounded : Icons.person_rounded,
            size: 13,
            color: isGroup
                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                : (isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED)),
          ),
          const SizedBox(width: 4),
          Text(
            isGroup ? 'جلسة جماعية' : 'جلسة خاصة (1-on-1)',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isGroup
                  ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                  : (isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // الشاشة 2: جلساتي وعروضي (My Sessions & My Offers)
  // =========================================================================
  Widget _buildMySessionsAndOffers({
    required List<TimeBankSessionModel> learnerSessions,
    required List<TimeBankOfferModel> myOffers,
    required String userId,
    required bool isDark,
    required Color primaryColor,
    required Color surfaceColor,
    required Color hairlineColor,
  }) {
    return Column(
      children: [
        // تبويب فرعي داخلي
        Container(
          color: surfaceColor,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              _buildSubTabButton(0, '🎓 جلساتي كمتعلّم (${learnerSessions.length})', primaryColor, isDark),
              const SizedBox(width: 10),
              _buildSubTabButton(1, '👨‍🏫 عروضي كشارح (${myOffers.length})', primaryColor, isDark),
            ],
          ),
        ),

        Expanded(
          child: _selectedSubTab == 0
              ? _buildLearnerSessionsList(learnerSessions, userId, isDark, primaryColor, surfaceColor, hairlineColor)
              : _buildTeacherOffersList(myOffers, isDark, primaryColor, surfaceColor, hairlineColor),
        ),
      ],
    );
  }

  Widget _buildSubTabButton(int index, String title, Color primaryColor, bool isDark) {
    final isSelected = _selectedSubTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedSubTab = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withValues(alpha: isDark ? 0.3 : 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? primaryColor : Colors.transparent),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? primaryColor : (isDark ? Colors.white60 : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLearnerSessionsList(
    List<TimeBankSessionModel> sessions,
    String userId,
    bool isDark,
    Color primaryColor,
    Color surfaceColor,
    Color hairlineColor,
  ) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 56, color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 12),
            const Text(
              'لم تنضم إلى أي جلسة تعليمية بعد',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'استكشف العروض المتاحة وانضم بمقابل عملة وقت واحدة ⏱️',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => setState(() => _selectedMainTab = 0),
              child: const Text('تصفح سوق الجلسات 🌐'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hairlineColor),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      session.courseName,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                  _buildSessionStatusBadge(session.status, isDark),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                session.topic,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'الشارح: ${session.teacherName} • ${session.day}، ${session.time}',
                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (session.meetingUrl != null && session.meetingUrl!.isNotEmpty) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _launchMeetingUrl(session.meetingUrl!),
                        icon: const Icon(Icons.videocam_rounded, size: 16),
                        label: const Text('رابط الاجتماع 📹', style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton.filledTonal(
                    tooltip: 'محادثة الجلسة',
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    onPressed: () => context.push('/session-chat', extra: session),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: 'تفاصيل الجلسة والتقييم',
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    onPressed: () => context.push('/session-learner', extra: session),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeacherOffersList(
    List<TimeBankOfferModel> offers,
    bool isDark,
    Color primaryColor,
    Color surfaceColor,
    Color hairlineColor,
  ) {
    if (offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.co_present_outlined, size: 56, color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 12),
            const Text(
              'لم تقم بنشر أي عروض للشرح بعد',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'شارك علمك مع زملائك واكسب عملات وقت لمذاكرتك! 🚀',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/create-offer'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('نشر عرض جديد الآن'),
              style: FilledButton.styleFrom(backgroundColor: primaryColor),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: offers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final offer = offers[index];
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hairlineColor),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      offer.courseName,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                  _buildSessionTypeBadge(offer.sessionType, isDark, primaryColor),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                offer.topic,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${offer.day}، ${offer.time} • الحضور: ${offer.attendeesCount} / ${offer.maxAttendees} زميل',
                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!offer.isCompleted) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _confirmSettleSession(offer),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('إنهاء الجلسة وصرف العملات 🪙', style: TextStyle(fontSize: 11.5)),
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    const Expanded(
                      child: Text(
                        'تمت تسوية هذه الجلسة واحتساب المكافأة بنجاح 🎉',
                        style: TextStyle(fontSize: 11.5, color: AppColors.success, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  if (offer.meetingUrl != null && offer.meetingUrl!.isNotEmpty) ...[
                    IconButton.filledTonal(
                      tooltip: 'فتح رابط الاجتماع',
                      icon: const Icon(Icons.videocam_rounded, size: 18),
                      onPressed: () => _launchMeetingUrl(offer.meetingUrl!),
                    ),
                  ],
                  if (!offer.isCompleted && offer.attendeesCount == 0) ...[
                    IconButton(
                      tooltip: 'حذف العرض',
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                      onPressed: () => _deleteOffer(offer.id),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionStatusBadge(String status, bool isDark) {
    Color bg = AppColors.success;
    String label = 'مؤكدة ✅';
    if (status == 'completed' || status == 'completed_auto') {
      label = 'مكتملة 🎉';
      bg = Colors.blue;
    } else if (status.startsWith('cancelled')) {
      label = 'ملغاة ❌';
      bg = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bg),
      ),
    );
  }

  Widget _buildEmptyOffersPlaceholder(bool isDark, Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black12),
            const SizedBox(height: 14),
            const Text(
              'لا توجد عروض شرح متاحة حالياً',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'كن أول من يبادر ويطرح جلسة شرح لزملائه في دفعتك واكسب عملات وقت 💡',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.push('/create-offer'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('نشر عرض شرح جديد 🚀'),
              style: FilledButton.styleFrom(backgroundColor: primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // عمليات المعاملات المالية والتفاعل
  // =========================================================================
  Future<void> _confirmAndJoinOffer(TimeBankOfferModel offer) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل الدخول أولاً للانضمام للجلسات')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('تأكيد الانضمام للجلسة ⚡', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المادة: ${offer.courseName}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('الموضوع: ${offer.topic}'),
            const SizedBox(height: 4),
            Text('الموعد: ${offer.day}، ${offer.time}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security_rounded, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيتم خصم 1 عملة وقت ووضعها في الضمان المالي حتى انتهاء الشرح.',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الانضمام (1 عملة)'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingAction = true);
    try {
      final userProfileAsync = ref.read(userProfileStreamProvider);
      final userName = userProfileAsync.value?.data()?['name'] as String? ?? (user.displayName ?? 'طالب زميل');

      await ref.read(timeBankRepositoryProvider).joinSessionWithEscrow(
            offerId: offer.id,
            learnerId: user.uid,
            learnerName: userName,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم انضمامك للجلسة بنجاح وحجز العملة في الضمان! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
        // التبديل إلى تاب الجلسات لعرض الجلسة المحجوزة
        setState(() {
          _selectedMainTab = 1;
          _selectedSubTab = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _confirmSettleSession(TimeBankOfferModel offer) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('إنهاء الجلسة وتسوية الأجر 🪙'),
        content: Text(
          'هل تم إنهاء شرح الجلسة لزملائك (${offer.attendeesCount} حضور)؟\n'
          'سيتم احتساب مكافأة الشارح وإيداع العملات فوراً في محفظتك وفقاً لخوارزمية الاقتصاد الذكية.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإنهاء واستلام الأجر'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessingAction = true);
    try {
      final reward = await ref.read(timeBankRepositoryProvider).settleSessionCompletion(
            offerId: offer.id,
            settledByUserId: user.uid,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('مبروك! تم إنهاء الجلسة وإيداع $reward عملة في محفظتك 🪙🎉'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إنهاء الجلسة: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _deleteOffer(String offerId) async {
    try {
      await ref.read(timeBankRepositoryProvider).deleteOffer(offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف العرض بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحذف: $e')),
        );
      }
    }
  }

  void _openMeetingOrSession(TimeBankOfferModel offer) {
    if (offer.meetingUrl != null && offer.meetingUrl!.isNotEmpty) {
      _launchMeetingUrl(offer.meetingUrl!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سيقوم الزميل الشارح بمشاركة الرابط في محادثة الجلسة قبل البدء 💬')),
      );
    }
  }

  Future<void> _launchMeetingUrl(String url) async {
    String finalUrl = url.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }
    final uri = Uri.tryParse(finalUrl);
    if (uri != null) {
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر فتح الرابط: $finalUrl')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في تشغيل الرابط: $e')),
          );
        }
      }
    }
  }
}
