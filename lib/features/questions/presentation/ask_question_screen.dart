import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_service.dart';
import '../data/question_repository.dart';

class AskQuestionScreen extends ConsumerStatefulWidget {
  const AskQuestionScreen({super.key});

  @override
  ConsumerState<AskQuestionScreen> createState() => _AskQuestionScreenState();
}

class _AskQuestionScreenState extends ConsumerState<AskQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _picker = ImagePicker();

  CourseSeed? _selectedCourse;
  XFile? _pickedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() => _pickedImage = image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر اختيار الصورة، يرجى المحاولة مرة أخرى')),
        );
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'إرفاق صورة توضيحية للمسألة 📸',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  title: const Text('التقاط صورة بالكاميرا'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                  title: const Text('اختيار صورة من المعرض'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المادة الدراسية المرتبطة بالسؤال')),
      );
      return;
    }

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final userProfileAsync = ref.read(userProfileStreamProvider);
    final userDoc = userProfileAsync.value?.data();
    final authorName = (userDoc?['name'] as String?)?.isNotEmpty == true
        ? (userDoc!['name'] as String)
        : (user.displayName ?? 'طالب زميل');

    // استخراج السنة الدراسية
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

    setState(() => _isSubmitting = true);

    try {
      await ref.read(questionRepositoryProvider).createQuestion(
        title: _titleController.text,
        body: _bodyController.text,
        courseId: _selectedCourse!.id,
        courseName: _selectedCourse!.name,
        academicYear: academicYear,
        authorId: user.uid,
        authorName: authorName,
        imageFile: _pickedImage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نشر سؤالك في المنتدى بنجاح! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر نشر السؤال: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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

    // المواد المتاحة
    final coursesData = userDoc?['coursesData'] as List<dynamic>?;
    List<CourseSeed> availableCourses = [];
    if (coursesData != null && coursesData.isNotEmpty) {
      availableCourses = coursesData.map((m) => CourseSeed.fromMap(Map<String, dynamic>.from(m as Map))).toList();
    } else {
      availableCourses = AppConstants.seedCourses;
    }

    // تنقية التكرار
    final uniqueMap = <String, CourseSeed>{};
    for (final c in availableCourses) {
      uniqueMap.putIfAbsent(c.id, () => c);
    }
    final cleanCourses = uniqueMap.values.toList();

    if (_selectedCourse == null && cleanCourses.isNotEmpty) {
      _selectedCourse = cleanCourses.first;
    }

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
          'طرح سؤال أكاديمي ✏️',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: onSurface),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(top: BorderSide(color: hairline)),
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'نشر السؤال في دفعتي',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // بطاقة إرشادية
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: primaryColor, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'سيظهر سؤالك لجميع زملائك في نفس فرقتك الدراسية ليتمكنوا من مساعدتك بالحلول والشروحات.',
                          style: TextStyle(fontSize: 12, color: onSurface, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // اختيار المادة
                Text('المادة الدراسية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: hairline),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCourse?.id,
                      isExpanded: true,
                      dropdownColor: cardColor,
                      items: cleanCourses.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.id,
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: c.color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(c.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCourse = cleanCourses.firstWhere((c) => c.id == val);
                          });
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // عنوان السؤال
                Text('عنوان السؤال / المشكلة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'يرجى كتابة عنوان مختصر للسؤال';
                    if (val.trim().length < 5) return 'العنوان قصير جداً';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'مثال: مسألة في مصفوفات الـ OOP أو خطأ NullPointerException',
                    hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                    filled: true,
                    fillColor: surfaceAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairline)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairline)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                  ),
                ),

                const SizedBox(height: 18),

                // نص وتفاصيل السؤال
                Text('شرح وتفاصيل المسألة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bodyController,
                  maxLines: 5,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'يرجى توضيح نص ومسألة السؤال بدقة';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'اكتب كود المشكلة، نص المسألة، أو ما حاولت القيام به لتسهيل المساعدة...',
                    hintStyle: TextStyle(fontSize: 13, color: textSecondary),
                    filled: true,
                    fillColor: surfaceAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairline)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: hairline)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 1.5)),
                  ),
                ),

                const SizedBox(height: 18),

                // إرفاق صورة اختيارية
                Text('صورة توضيحية للمسألة (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: onSurface)),
                const SizedBox(height: 8),

                if (_pickedImage != null)
                  Stack(
                    children: [
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                          image: DecorationImage(
                            image: FileImage(File(_pickedImage!.path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            onPressed: () => setState(() => _pickedImage = null),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _showImagePickerOptions,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: hairline, style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: primaryColor, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            'اضغط لالتقاط أو اختيار صورة توضيحية للكود أو المسألة',
                            style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
