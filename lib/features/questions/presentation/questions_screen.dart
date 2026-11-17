import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_service.dart';
import '../data/question_repository.dart';
import 'widgets/app_question_image.dart';

class QuestionsScreen extends ConsumerStatefulWidget {
  const QuestionsScreen({super.key});

  @override
  ConsumerState<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends ConsumerState<QuestionsScreen> {
  String? _selectedCourseId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final hairline = isDark ? AppColors.darkHairline : AppColors.hairline;
    final surfaceAlt = isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.primary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final onSurface = theme.colorScheme.onSurface;

    final userProfileAsync = ref.watch(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();

    // استخراج السنة الدراسية للطالب لفلترة الأسئلة بدقة
    final rawYear = userDoc?['academicYear'];
    String academicYear = 'الفرقة الأولى';
    if (rawYear is int) {
      academicYear = CurriculumConstants.academicYearLabels[rawYear] ?? 'الفرقة الأولى';
    } else if (rawYear is String && int.tryParse(rawYear) != null) {
      final parsed = int.parse(rawYear);
      academicYear = CurriculumConstants.academicYearLabels[parsed] ?? 'الفرقة الأولى';
    } else if (userDoc?['year'] is String && (userDoc!['year'] as String).isNotEmpty) {
      academicYear = userDoc['year'] as String;
    }

    // استخراج قائمة مواد الطالب للفلترة
    final coursesData = userDoc?['coursesData'] as List<dynamic>?;
    List<CourseSeed> userCourses = [];
    if (coursesData != null && coursesData.isNotEmpty) {
      userCourses = coursesData.map((m) => CourseSeed.fromMap(Map<String, dynamic>.from(m as Map))).toList();
    } else {
      userCourses = AppConstants.seedCourses;
    }

    final questionsAsync = ref.watch(questionsStreamProvider((
      academicYear: academicYear,
      courseId: _selectedCourseId,
    )));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_forward_ios_rounded, color: onSurface),
                onPressed: () => context.pop(),
              )
            : null,
        title: Column(
          children: [
            Text(
              'منتدى الأسئلة والحلول 💬',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: onSurface),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'أسئلة ومقررات $academicYear 🎓',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ask-question'),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white, size: 20),
        label: const Text(
          'اطرح سؤالاً',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // شريط البحث وفلترة المقررات
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: hairline),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مسألة أو سؤال أو كود...',
                    hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                    prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),

            // شرائح المواد (Course Filters)
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ChoiceChip(
                      label: const Text('جميع المواد'),
                      selected: _selectedCourseId == null,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCourseId = null);
                      },
                      selectedColor: primaryColor,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedCourseId == null ? Colors.white : onSurface,
                      ),
                      backgroundColor: cardColor,
                      side: BorderSide(color: hairline),
                    ),
                  ),
                  ...userCourses.map((c) {
                    final isSelected = _selectedCourseId == c.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ChoiceChip(
                        avatar: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                        ),
                        label: Text(c.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedCourseId = selected ? c.id : null);
                        },
                        selectedColor: primaryColor,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : onSurface,
                        ),
                        backgroundColor: cardColor,
                        side: BorderSide(color: hairline),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // قائمة الأسئلة
            Expanded(
              child: questionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text(
                    'تعذر تحميل الأسئلة، يرجى المحاولة لاحقاً',
                    style: TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
                data: (allQuestions) {
                  // تصفية محلية بالبحث النصي
                  final filtered = allQuestions.where((q) {
                    if (_searchQuery.isEmpty) return true;
                    final query = _searchQuery.toLowerCase();
                    return q.title.toLowerCase().contains(query) ||
                        q.body.toLowerCase().contains(query) ||
                        q.courseName.toLowerCase().contains(query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.help_outline_rounded, size: 48, color: primaryColor),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'لا توجد نتائج تطابق بحثك'
                                  : 'لا توجد أسئلة مطروحة في هذه المادة بعد',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onSurface),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'كن أول من يطرح سؤالاً أو مسألة ليساعدك زملاؤك في دفعتك!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final question = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: hairline),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/question-details', extra: question),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // رأس البطاقة: كاتب السؤال + المادة + الوقت
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: primaryColor.withValues(alpha: 0.15),
                                          child: Text(
                                            question.authorName.isNotEmpty
                                                ? question.authorName.substring(0, 1)
                                                : 'ز',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          question.authorName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '• ${_formatTimeAgo(question.createdAt)}',
                                          style: TextStyle(fontSize: 11, color: textSecondary),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: surfaceAlt,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        question.courseName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // عنوان السؤال
                                Text(
                                  question.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface,
                                    height: 1.3,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // نص السؤال
                                Text(
                                  question.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: textSecondary, height: 1.4),
                                ),

                                // إذا كانت هناك صورة مرفقة تظهر مصغرة
                                if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  AppQuestionImage(
                                    imageUrl: question.imageUrl!,
                                    height: 130,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ],

                                const SizedBox(height: 12),

                                // الجزء السفلي: عدد الإجابات
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: question.answersCount > 0
                                            ? AppColors.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.6)
                                            : surfaceAlt,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 13,
                                            color: question.answersCount > 0 ? primaryColor : textSecondary,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            question.answersCount > 0
                                                ? '${question.answersCount} إجابات'
                                                : 'لا توجد إجابات بعد',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: question.answersCount > 0 ? primaryColor : textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'عرض التفاصيل والحلول',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: primaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_back_ios_new_rounded, size: 10, color: primaryColor),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
