// مطور 4
// فيجما: منتدى الأسئلة الأكاديمية وحلول الزملاء - ذاكر وعلّم

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
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
  bool _showOnlyMyQuestions = false;

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
    final tokens = context.tokens;
    final currentUserId = ref.watch(authServiceProvider).currentUser?.uid ?? '';

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
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_forward_ios_rounded, color: tokens.textHigh),
                onPressed: () => context.pop(),
              )
            : null,
        title: Column(
          children: [
            Text(
              'منتدى الأسئلة والحلول',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: tokens.textHigh),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.brandContainer.withValues(alpha: 0.5),
                borderRadius: AppRadii.controlRadius,
              ),
              child: Text(
                'أسئلة ومقررات $academicYear',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tokens.brand),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/ask-question'),
        backgroundColor: tokens.brand,
        icon: Icon(Icons.add_comment_rounded, color: tokens.onBrand, size: 20),
        label: Text(
          'اطرح سؤالاً',
          style: TextStyle(color: tokens.onBrand, fontWeight: FontWeight.bold, fontSize: 13),
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
                  color: tokens.surface,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(color: tokens.border),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: tokens.textHigh),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن مسألة أو سؤال أو كود...',
                    hintStyle: TextStyle(fontSize: 13, color: tokens.textMedium),
                    prefixIcon: Icon(Icons.search_rounded, color: tokens.brand),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, size: 18, color: tokens.textMedium),
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
                      selectedColor: tokens.brand,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedCourseId == null ? tokens.onBrand : tokens.textHigh,
                      ),
                      backgroundColor: tokens.surface,
                      side: BorderSide(color: tokens.border),
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
                        selectedColor: tokens.brand,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? tokens.onBrand : tokens.textHigh,
                        ),
                        backgroundColor: tokens.surface,
                        side: BorderSide(color: tokens.border),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // تابات التبديل بين جميع الأسئلة وأسئلتي الخاصة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: questionsAsync.maybeWhen(
                data: (allQuestions) {
                  final myQuestionsCount = allQuestions.where((q) => q.authorId == currentUserId).length;
                  return Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: AppRadii.controlRadius,
                          onTap: () => setState(() => _showOnlyMyQuestions = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_showOnlyMyQuestions
                                  ? tokens.brand
                                  : tokens.surfaceAlt,
                              borderRadius: AppRadii.controlRadius,
                              border: Border.all(
                                color: !_showOnlyMyQuestions ? tokens.brand : tokens.border,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'جميع أسئلة الدفعة (${allQuestions.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: !_showOnlyMyQuestions ? tokens.onBrand : tokens.textMedium,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: AppRadii.controlRadius,
                          onTap: () => setState(() => _showOnlyMyQuestions = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _showOnlyMyQuestions
                                  ? tokens.brand
                                  : tokens.surfaceAlt,
                              borderRadius: AppRadii.controlRadius,
                              border: Border.all(
                                color: _showOnlyMyQuestions ? tokens.brand : tokens.border,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'أسئلتي الخاصة',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _showOnlyMyQuestions ? tokens.onBrand : tokens.textMedium,
                                    ),
                                  ),
                                  if (myQuestionsCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: _showOnlyMyQuestions
                                            ? tokens.onBrand.withValues(alpha: 0.25)
                                            : tokens.brandContainer,
                                        borderRadius: AppRadii.controlRadius,
                                      ),
                                      child: Text(
                                        '$myQuestionsCount',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _showOnlyMyQuestions ? tokens.onBrand : tokens.brand,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ),

            const SizedBox(height: 6),

            // قائمة الأسئلة
            Expanded(
              child: questionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text(
                    'تعذر تحميل الأسئلة، يرجى المحاولة لاحقاً',
                    style: TextStyle(color: tokens.danger, fontSize: 13),
                  ),
                ),
                data: (allQuestions) {
                  // تصفية محلية بالبحث النصي وتبويب أسئلتي الخاصة
                  final filtered = allQuestions.where((q) {
                    if (_showOnlyMyQuestions && q.authorId != currentUserId) {
                      return false;
                    }
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
                                color: tokens.brandContainer.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _showOnlyMyQuestions ? Icons.person_search_rounded : Icons.help_outline_rounded,
                                size: 48,
                                color: tokens.brand,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showOnlyMyQuestions
                                  ? 'لم تطرح أي أسئلة بعد في هذا المقرر'
                                  : (_searchQuery.isNotEmpty
                                      ? 'لا توجد نتائج تطابق بحثك'
                                      : 'لا توجد أسئلة مطروحة في هذه المادة بعد'),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: tokens.textHigh),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _showOnlyMyQuestions
                                  ? 'استخدم زر "اطرح سؤالاً" بالأسفل لطرح استفساراتك وسيقوم زملاؤك بمساعدتك!'
                                  : 'كن أول من يطرح سؤالاً أو مسألة ليساعدك زملاؤك في دفعتك!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: tokens.textMedium),
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
                      final isMyQuestion = question.authorId == currentUserId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isMyQuestion
                              ? tokens.brandContainer.withValues(alpha: 0.3)
                              : tokens.surface,
                          borderRadius: AppRadii.cardRadius,
                          border: Border.all(
                            color: isMyQuestion
                                ? tokens.brand.withValues(alpha: 0.5)
                                : tokens.border,
                            width: isMyQuestion ? 1.5 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: AppRadii.cardRadius,
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
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: isMyQuestion
                                                ? tokens.brand
                                                : tokens.brandContainer,
                                            child: isMyQuestion
                                                ? Icon(Icons.person_rounded, size: 14, color: tokens.onBrand)
                                                : Text(
                                                    question.authorName.isNotEmpty
                                                        ? question.authorName.substring(0, 1)
                                                        : 'ز',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: tokens.brand,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              isMyQuestion ? 'أنت (سؤالك)' : question.authorName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isMyQuestion ? FontWeight.w800 : FontWeight.bold,
                                                color: isMyQuestion ? tokens.brand : tokens.textHigh,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '• ${_formatTimeAgo(question.createdAt)}',
                                            style: TextStyle(fontSize: 11, color: tokens.textMedium),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isMyQuestion) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: tokens.brandContainer,
                                              borderRadius: AppRadii.controlRadius,
                                              border: Border.all(color: tokens.brand.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              'سؤالك',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: tokens.brand,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 115),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: tokens.surfaceAlt,
                                              borderRadius: AppRadii.controlRadius,
                                            ),
                                            child: Text(
                                              question.courseName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: tokens.brand,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
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
                                    color: tokens.textHigh,
                                    height: 1.3,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // نص السؤال
                                Text(
                                  question.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: tokens.textMedium, height: 1.4),
                                ),

                                // إذا كانت هناك صورة مرفقة تظهر مصغرة
                                if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  AppQuestionImage(
                                    imageUrl: question.imageUrl!,
                                    height: 130,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    borderRadius: AppRadii.controlRadius,
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
                                            ? tokens.brandContainer.withValues(alpha: 0.5)
                                            : tokens.surfaceAlt,
                                        borderRadius: AppRadii.fullRadius,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 13,
                                            color: question.answersCount > 0 ? tokens.brand : tokens.textMedium,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            question.answersCount > 0
                                                ? '${question.answersCount} إجابات'
                                                : 'لا توجد إجابات بعد',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: question.answersCount > 0 ? tokens.brand : tokens.textMedium,
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
                                            color: tokens.brand,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.arrow_back_ios_new_rounded, size: 10, color: tokens.brand),
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
