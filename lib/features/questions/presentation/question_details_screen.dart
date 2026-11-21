import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/data/auth_service.dart';
import '../data/question_model.dart';
import '../data/question_repository.dart';
import 'widgets/app_question_image.dart';

class QuestionDetailsScreen extends ConsumerStatefulWidget {
  final QuestionModel question;

  const QuestionDetailsScreen({
    super.key,
    required this.question,
  });

  @override
  ConsumerState<QuestionDetailsScreen> createState() => _QuestionDetailsScreenState();
}

class _QuestionDetailsScreenState extends ConsumerState<QuestionDetailsScreen> {
  final _answerController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  XFile? _answerImage;
  bool _isSubmittingAnswer = false;

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _pickAnswerImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 70,
      );
      if (img != null) {
        setState(() => _answerImage = img);
      }
    } catch (_) {}
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadii.sheetTopRadius,
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: context.tokens.brand),
                title: const Text('التقاط صورة للحل بالكاميرا'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAnswerImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: context.tokens.brand),
                title: const Text('اختيار صورة الحل من المعرض'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAnswerImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitAnswer() async {
    final text = _answerController.text.trim();
    if (text.isEmpty && _answerImage == null) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final userProfileAsync = ref.read(userProfileStreamProvider);
    final authorName = (userProfileAsync.value?.data()?['name'] as String?)?.isNotEmpty == true
        ? (userProfileAsync.value!.data()!['name'] as String)
        : (user.displayName ?? 'طالب زميل');

    setState(() => _isSubmittingAnswer = true);

    try {
      await ref.read(questionRepositoryProvider).postAnswer(
        questionId: widget.question.id,
        text: text.isNotEmpty ? text : 'مرفق صورة الحل أعلاه',
        authorId: user.uid,
        authorName: authorName,
        imageFile: _answerImage,
      );

      _answerController.clear();
      setState(() => _answerImage = null);

      // تمرير القائمة للأسفل
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر إرسال الإجابة: $e'), backgroundColor: context.tokens.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingAnswer = false);
      }
    }
  }

  void _showFullImage(String imageUrl) {
    AppQuestionImage.showFullImageDialog(context, imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final cardColor = tokens.surface;
    final hairline = tokens.border;
    final surfaceAlt = tokens.surfaceAlt;
    final primaryColor = tokens.brand;
    final textSecondary = tokens.textMedium;
    final onSurface = tokens.textHigh;

    final currentUser = ref.watch(authServiceProvider).currentUser;
    final currentUserId = currentUser?.uid ?? '';
    final isQuestionAuthor = currentUser?.uid == widget.question.authorId;

    // استماع للتحديثات الحية للسؤال والإجابات
    final answersAsync = ref.watch(answersStreamProvider(widget.question.id));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_forward_ios_rounded, color: onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.question.courseName,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).viewInsets.bottom + 12),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: hairline)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_answerImage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: surfaceAlt,
                  borderRadius: AppRadii.controlRadius,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: AppRadii.controlRadius,
                      child: Image.file(File(_answerImage!.path), width: 36, height: 36, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('صورة مرفقة للحل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _answerImage = null),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.add_photo_alternate_rounded, color: primaryColor),
                  onPressed: _isSubmittingAnswer ? null : _showImageOptions,
                  tooltip: 'إرفاق صورة للحل',
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: surfaceAlt,
                      borderRadius: AppRadii.chipRadius,
                    ),
                    child: TextField(
                      controller: _answerController,
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'اكتب حلك أو مساهمتك الأكاديمية...',
                        hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSubmittingAnswer
                    ? const SizedBox(
                        width: 38,
                        height: 38,
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : CircleAvatar(
                        backgroundColor: primaryColor,
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                          onPressed: _submitAnswer,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // بطاقة السؤال الرئيسية
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isQuestionAuthor
                    ? tokens.brandContainer.withValues(alpha: 0.3)
                    : cardColor,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(
                  color: isQuestionAuthor ? primaryColor : hairline,
                  width: isQuestionAuthor ? 1.5 : 1,
                ),
                boxShadow: tokens.floatingShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isQuestionAuthor ? primaryColor : primaryColor.withValues(alpha: 0.15),
                              child: isQuestionAuthor
                                  ? Icon(Icons.person_rounded, size: 16, color: Colors.white)
                                  : Text(
                                      widget.question.authorName.isNotEmpty ? widget.question.authorName.substring(0, 1) : 'ز',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          isQuestionAuthor ? 'أنت (صاحب السؤال)' : widget.question.authorName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: isQuestionAuthor ? FontWeight.w800 : FontWeight.bold,
                                            fontSize: 13,
                                            color: isQuestionAuthor ? primaryColor : onSurface,
                                          ),
                                        ),
                                      ),
                                      if (isQuestionAuthor) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: tokens.brandContainer,
                                            borderRadius: AppRadii.controlRadius,
                                          ),
                                          child: Text(
                                            'سؤالك',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(_formatTime(widget.question.createdAt), style: TextStyle(fontSize: 11, color: textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tokens.brandContainer,
                          borderRadius: AppRadii.chipRadius,
                        ),
                        child: Text(
                          widget.question.academicYear,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  Text(
                    widget.question.title,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: onSurface, height: 1.3),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    widget.question.body,
                    style: TextStyle(fontSize: 14, color: onSurface, height: 1.5),
                  ),

                  if (widget.question.imageUrl != null && widget.question.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _showFullImage(widget.question.imageUrl!),
                      child: ClipRRect(
                        borderRadius: AppRadii.controlRadius,
                        child: Stack(
                          alignment: Alignment.bottomLeft,
                          children: [
                            AppQuestionImage(
                              imageUrl: widget.question.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 220,
                            ),
                            Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: AppRadii.controlRadius,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('اضغط للتكبير', style: TextStyle(color: Colors.white, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 22),

            // عنوان قسم الإجابات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الحلول والمناقشات الأكاديمية',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: onSurface),
                ),
                answersAsync.maybeWhen(
                  data: (list) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: surfaceAlt,
                      borderRadius: AppRadii.controlRadius,
                    ),
                    child: Text(
                      '${list.length} حلول',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // قائمة الإجابات
            answersAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              error: (e, _) => Center(child: Text('تعذر تحميل الحلول: $e', style: TextStyle(color: tokens.danger, fontSize: 12))),
              data: (answers) {
                if (answers.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: AppRadii.cardRadius,
                      border: Border.all(color: hairline),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.rate_review_outlined, size: 36, color: primaryColor),
                        const SizedBox(height: 8),
                        Text('لم يتم إضافة حلول لهذا السؤال بعد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: onSurface)),
                        const SizedBox(height: 4),
                        Text('كن أول من يكتب حلاً ويساعد زميله لنيل التقدير ونقاط الأقران!', style: TextStyle(fontSize: 11, color: textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: answers.length,
                  itemBuilder: (context, index) {
                    final answer = answers[index];
                    final isMyAnswer = answer.authorId == currentUserId;
                    final isAuthorAnswer = answer.authorId == widget.question.authorId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isMyAnswer
                            ? tokens.brandContainer.withValues(alpha: 0.25)
                            : (answer.isAcceptedSolution
                                ? tokens.successContainer.withValues(alpha: 0.35)
                                : cardColor),
                        borderRadius: AppRadii.cardRadius,
                        border: Border.all(
                          color: answer.isAcceptedSolution
                              ? tokens.success
                              : (isMyAnswer ? primaryColor.withValues(alpha: 0.6) : hairline),
                          width: (answer.isAcceptedSolution || isMyAnswer) ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // شارة الحل المعتمد إن وجد
                            if (answer.isAcceptedSolution) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tokens.success.withValues(alpha: 0.15),
                                  borderRadius: AppRadii.chipRadius,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: tokens.success, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'حل معتمد من صاحب السؤال',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: tokens.success),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // معلومات المجيب
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: isMyAnswer
                                            ? primaryColor
                                            : primaryColor.withValues(alpha: 0.12),
                                        child: isMyAnswer
                                            ? Icon(Icons.person_rounded, size: 14, color: Colors.white)
                                            : Text(
                                                answer.authorName.isNotEmpty ? answer.authorName.substring(0, 1) : 'ز',
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: primaryColor),
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          isMyAnswer ? 'أنت (إجابتك)' : answer.authorName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: isMyAnswer ? FontWeight.w800 : FontWeight.bold,
                                            fontSize: 12,
                                            color: isMyAnswer ? primaryColor : onSurface,
                                          ),
                                        ),
                                      ),
                                      if (isMyAnswer) ...[
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: tokens.brandContainer,
                                            borderRadius: AppRadii.controlRadius,
                                          ),
                                          child: Text(
                                            'إجابتك',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryColor),
                                          ),
                                        ),
                                      ] else if (isAuthorAnswer) ...[
                                        const SizedBox(width: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: tokens.warningContainer,
                                            borderRadius: AppRadii.controlRadius,
                                          ),
                                          child: Text(
                                            'صاحب السؤال',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tokens.warning),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 6),
                                      Text(
                                        '• ${_formatTime(answer.createdAt)}',
                                        style: TextStyle(fontSize: 10, color: textSecondary),
                                      ),
                                    ],
                                  ),
                                ),

                                // زر اعتماد الحل (يظهر لصاحب السؤال فقط)
                                if (isQuestionAuthor)
                                  InkWell(
                                    borderRadius: AppRadii.controlRadius,
                                    onTap: () {
                                      ref.read(questionRepositoryProvider).toggleAcceptedSolution(
                                        questionId: widget.question.id,
                                        answerId: answer.id,
                                        currentStatus: answer.isAcceptedSolution,
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            answer.isAcceptedSolution ? Icons.star_rounded : Icons.star_border_rounded,
                                            size: 16,
                                            color: answer.isAcceptedSolution ? tokens.coin : textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            answer.isAcceptedSolution ? 'معتمد' : 'اعتماد كحل',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: answer.isAcceptedSolution ? tokens.coin : textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // نص الحل
                            Text(answer.text, style: TextStyle(fontSize: 13, color: onSurface, height: 1.4)),

                            // صورة مرفقة في الحل
                            if (answer.imageUrl != null && answer.imageUrl!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () => _showFullImage(answer.imageUrl!),
                                child: AppQuestionImage(
                                  imageUrl: answer.imageUrl!,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  borderRadius: AppRadii.controlRadius,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}