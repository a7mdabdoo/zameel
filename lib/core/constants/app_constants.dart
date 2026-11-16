import 'package:material_ui/material_ui.dart';
import '../theme/app_colors.dart';

class CourseSeed {
  final String id;
  final String name;
  final String code;
  final Color color;
  final int creditHours; // عدد الساعات المعتمدة للمادة (مثلاً 2 أو 3 أو 4 ساعات)

  const CourseSeed({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
    this.creditHours = 3,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'color': color.toARGB32(),
      'creditHours': creditHours,
    };
  }

  factory CourseSeed.fromMap(Map<String, dynamic> map) {
    return CourseSeed(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      code: map['code'] as String? ?? '',
      color: map['color'] != null ? Color(map['color'] as int) : AppColors.courseTeal,
      creditHours: (map['creditHours'] as num?)?.toInt() ?? 3,
    );
  }
}

class AppConstants {
  // App Identity
  static const String appName = 'زَميل';
  static const String appSlogan = 'ذاكر بخطة، وعلّم زميلك، وتعلّم من غيرك';

  // Faculty and Default Year
  static const String faculty = 'كلية الحاسبات والذكاء الاصطناعي';
  static const String academicYear = 'الفرقة الأولى';

  // Points & Time Rules
  static const int welcomeCoins = 2; // هدية البداية: 2 عملات وقت
  static const int sessionCostCoins = 1; // تكلفة كل جلسة: 1 عملة وقت ثابتة
  static const int maxDailyStudyHours = 3; // أقصى ساعات مذاكرة يومية
  static const int studyBlockDurationMin = 45; // مدة كتلة المذاكرة
  static const int breakDurationMin = 10; // مدة الاستراحة بعد الكتلة

  // Email Validation (يدعم Gmail وكافة الإيميلات العادية والشخصية)
  static bool isValidEmail(String email) {
    final clean = email.trim();
    final emailRegex = RegExp(r'^[\w\.\+-_]+@[\w-]+\.[\w-\.]+$');
    return emailRegex.hasMatch(clean);
  }

  // للتوافق التام مع أي فحص بالاسم القديم
  static bool isValidUniversityEmail(String email) => isValidEmail(email);

  // Seed Courses for 2nd Year CS & AI (and backward compatibility)
  static const List<CourseSeed> seedCourses = [
    CourseSeed(
      id: 'cs201',
      name: 'البرمجة الكائنية (OOP)',
      code: 'CS201',
      color: AppColors.courseTeal,
      creditHours: 3,
    ),
    CourseSeed(
      id: 'cs202',
      name: 'هياكل البيانات (Data Structures)',
      code: 'CS202',
      color: AppColors.courseSage,
      creditHours: 3,
    ),
    CourseSeed(
      id: 'is201',
      name: 'قواعد البيانات (Databases)',
      code: 'IS201',
      color: AppColors.courseSand,
      creditHours: 3,
    ),
    CourseSeed(
      id: 'math201',
      name: 'الجبر الخطي (Linear Algebra)',
      code: 'MATH201',
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    CourseSeed(
      id: 'math202',
      name: 'التفاضل والتكامل (Calculus)',
      code: 'MATH202',
      color: AppColors.courseSlate,
      creditHours: 3,
    ),
    CourseSeed(
      id: 'cs203',
      name: 'تنظيم الحواسب (Computer Org)',
      code: 'CS203',
      color: AppColors.courseDustPlum,
      creditHours: 2,
    ),
  ];
}

/// بيانات الخطة الدراسية والمقررات لجميع الفرق والفصول الدراسية
class CurriculumConstants {
  // تسميات الفرق الدراسية
  static const Map<int, String> academicYearLabels = {
    1: 'الفرقة الأولى',
    2: 'الفرقة الثانية',
    3: 'الفرقة الثالثة',
    4: 'الفرقة الرابعة',
  };

  // تسميات الفصول الدراسية
  static const Map<int, String> semesterLabels = {
    1: 'الترم الأول',
    2: 'الترم الثاني',
  };

  /// خريطة المقررات الدقيقة لكل فرقة وفصل دراسي ("Year-Semester")
  static const Map<String, List<String>> curriculumMapping = {
    "1-1": [
      "تاريخ الحوسبة",
      "الإلكترونيات",
      "رياضيات 1",
      "اساسيات علوم الحاسب",
      "اللغة الإنجليزية",
      "الحاسبات و الأخلاقيات",
      "التفكير العلمي",
    ],
    "1-2": [
      "الهياكل المتقطعة",
      "قوانين الحاسبات",
      "رياضيات 2",
      "احتمالات و احصاء 1",
      "اساسيات البرمجة",
      "الكتابة التقنية",
      "سلوكيات الهيئات",
    ],
    "2-1": [
      "التصميم المنطقي",
      "بحوث العمليات",
      "احتمالات و احصاء 2",
      "البرمجة الشيئية",
      "إدارة المشروعات",
      "شبكات الحاسب 1",
    ],
    "2-2": [
      "قواعد البيانات",
      "الفيزياء",
      "البرمجة المتوازية",
      "هياكل البيانات 1",
      "تكنولوجيا الويب",
      "النمذجة والمحاكاة",
    ],
    "3-1": [
      "هندسة البرمجيات",
      "معالجة الصور",
      "الذكاء الإصطناعي",
      "هياكل البيانات 2",
      "الخوارزميات",
      "نظم التشغيل",
    ],
    "3-2": [
      "بنية و تنظيم الحاسبات",
      "التدريب الميداني",
      "التشفير",
      "الرسم بالحاسب",
      "مفاهيم لغات الحاسب",
      "البرمجة المرئية",
    ],
    "4-1": [
      "نظرية الحاسبات",
      "تعلم الآلة",
      "اكتشاف المعرفة",
      "برمجة الأجهزة المحمولة",
      "الحوسبة السحابية",
      "مشروع التخرج",
    ],
    "4-2": [
      "المترجمات",
      "الحوسبة الضبابية",
      "الرؤية بالحاسب",
      "معالجة البيانات الضخمة",
      "معالجة اللغات الطبيعية",
      "مشروع التخرج",
    ],
  };

  /// تفاصيل المقررات الإضافية (الكود، اللون، الساعات المعتمدة، والمعرف)
  static final Map<String, CourseSeed> _allSubjectsMetadata = {
    // 1-1
    "تاريخ الحوسبة": const CourseSeed(
      id: "c_1_1_history_computing",
      name: "تاريخ الحوسبة",
      code: "HUM101",
      color: AppColors.courseSand,
      creditHours: 2,
    ),
    "الإلكترونيات": const CourseSeed(
      id: "c_1_1_electronics",
      name: "الإلكترونيات",
      code: "ELEC101",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "رياضيات 1": const CourseSeed(
      id: "c_1_1_math1",
      name: "رياضيات 1",
      code: "MATH101",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "اساسيات علوم الحاسب": const CourseSeed(
      id: "c_1_1_cs_fundamentals",
      name: "اساسيات علوم الحاسب",
      code: "CS101",
      color: AppColors.courseTeal,
      creditHours: 3,
    ),
    "اللغة الإنجليزية": const CourseSeed(
      id: "c_1_1_english",
      name: "اللغة الإنجليزية",
      code: "ENG101",
      color: AppColors.courseSand,
      creditHours: 2,
    ),
    "الحاسبات و الأخلاقيات": const CourseSeed(
      id: "c_1_1_ethics",
      name: "الحاسبات و الأخلاقيات",
      code: "HUM102",
      color: AppColors.courseSand,
      creditHours: 2,
    ),
    "التفكير العلمي": const CourseSeed(
      id: "c_1_1_thinking",
      name: "التفكير العلمي",
      code: "HUM103",
      color: AppColors.courseSand,
      creditHours: 2,
    ),

    // 1-2
    "الهياكل المتقطعة": const CourseSeed(
      id: "c_1_2_discrete",
      name: "الهياكل المتقطعة",
      code: "CS102",
      color: AppColors.courseSage,
      creditHours: 3,
    ),
    "قوانين الحاسبات": const CourseSeed(
      id: "c_1_2_law",
      name: "قوانين الحاسبات",
      code: "LAW101",
      color: AppColors.courseSand,
      creditHours: 2,
    ),
    "رياضيات 2": const CourseSeed(
      id: "c_1_2_math2",
      name: "رياضيات 2",
      code: "MATH102",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "احتمالات و احصاء 1": const CourseSeed(
      id: "c_1_2_prob1",
      name: "احتمالات و احصاء 1",
      code: "STAT101",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "اساسيات البرمجة": const CourseSeed(
      id: "c_1_2_programming",
      name: "اساسيات البرمجة",
      code: "CS103",
      color: AppColors.courseTeal,
      creditHours: 3,
    ),
    "الكتابة التقنية": const CourseSeed(
      id: "c_1_2_tech_writing",
      name: "الكتابة التقنية",
      code: "ENG102",
      color: AppColors.courseSand,
      creditHours: 2,
    ),
    "سلوكيات الهيئات": const CourseSeed(
      id: "c_1_2_org_behavior",
      name: "سلوكيات الهيئات",
      code: "HUM104",
      color: AppColors.courseSand,
      creditHours: 2,
    ),

    // 2-1
    "التصميم المنطقي": const CourseSeed(
      id: "c_2_1_logic_design",
      name: "التصميم المنطقي",
      code: "CS204",
      color: AppColors.courseDustPlum,
      creditHours: 3,
    ),
    "بحوث العمليات": const CourseSeed(
      id: "c_2_1_operations_research",
      name: "بحوث العمليات",
      code: "OR201",
      color: AppColors.courseSage,
      creditHours: 3,
    ),
    "احتمالات و احصاء 2": const CourseSeed(
      id: "c_2_1_prob2",
      name: "احتمالات و احصاء 2",
      code: "STAT201",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "البرمجة الشيئية": const CourseSeed(
      id: "cs201",
      name: "البرمجة الشيئية",
      code: "CS201",
      color: AppColors.courseTeal,
      creditHours: 3,
    ),
    "إدارة المشروعات": const CourseSeed(
      id: "c_2_1_project_mgmt",
      name: "إدارة المشروعات",
      code: "IS211",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "شبكات الحاسب 1": const CourseSeed(
      id: "c_2_1_networks1",
      name: "شبكات الحاسب 1",
      code: "IT221",
      color: AppColors.courseTeal,
      creditHours: 3,
    ),

    // 2-2
    "قواعد البيانات": const CourseSeed(
      id: "is201",
      name: "قواعد البيانات",
      code: "IS201",
      color: AppColors.courseSand,
      creditHours: 3,
    ),
    "الفيزياء": const CourseSeed(
      id: "c_2_2_physics",
      name: "الفيزياء",
      code: "PHYS201",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "البرمجة المتوازية": const CourseSeed(
      id: "c_2_2_parallel",
      name: "البرمجة المتوازية",
      code: "CS223",
      color: AppColors.courseSlate,
      creditHours: 3,
    ),
    "هياكل البيانات 1": const CourseSeed(
      id: "cs202",
      name: "هياكل البيانات 1",
      code: "CS202",
      color: AppColors.courseSage,
      creditHours: 3,
    ),
    "تكنولوجيا الويب": const CourseSeed(
      id: "c_2_2_web",
      name: "تكنولوجيا الويب",
      code: "IT222",
      color: AppColors.courseTeal,
      creditHours: 3,
    ),
    "النمذجة والمحاكاة": const CourseSeed(
      id: "c_2_2_simulation",
      name: "النمذجة والمحاكاة",
      code: "CS222",
      color: AppColors.courseClay,
      creditHours: 3,
    ),

    // 3-1
    "هندسة البرمجيات": const CourseSeed(
      id: "c_3_1_software_eng",
      name: "هندسة البرمجيات",
      code: "SE301",
      color: AppColors.courseSand,
      creditHours: 3,
    ),
    "معالجة الصور": const CourseSeed(
      id: "c_3_1_image_processing",
      name: "معالجة الصور",
      code: "CS315",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "الذكاء الإصطناعي": const CourseSeed(
      id: "c_3_1_ai",
      name: "الذكاء الإصطناعي",
      code: "AI301",
      color: AppColors.courseTeal,
      creditHours: 3,
    ),
    "هياكل البيانات 2": const CourseSeed(
      id: "c_3_1_data_structures_2",
      name: "هياكل البيانات 2",
      code: "CS313",
      color: AppColors.courseSage,
      creditHours: 3,
    ),
    "الخوارزميات": const CourseSeed(
      id: "c_3_1_algorithms",
      name: "الخوارزميات",
      code: "CS312",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "نظم التشغيل": const CourseSeed(
      id: "c_3_1_operating_systems",
      name: "نظم التشغيل",
      code: "CS311",
      color: AppColors.courseTeal,
      creditHours: 3,
    ),

    // 3-2
    "بنية و تنظيم الحاسبات": const CourseSeed(
      id: "cs203",
      name: "بنية و تنظيم الحاسبات",
      code: "CS325",
      color: AppColors.courseDustPlum,
      creditHours: 3,
    ),
    "التدريب الميداني": const CourseSeed(
      id: "c_3_2_field_training",
      name: "التدريب الميداني",
      code: "TRN301",
      color: AppColors.courseSand,
      creditHours: 2,
    ),
    "التشفير": const CourseSeed(
      id: "c_3_2_cryptography",
      name: "التشفير",
      code: "CS324",
      color: AppColors.courseSand,
      creditHours: 3,
    ),
    "الرسم بالحاسب": const CourseSeed(
      id: "c_3_2_graphics",
      name: "الرسم بالحاسب",
      code: "CS323",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "مفاهيم لغات الحاسب": const CourseSeed(
      id: "c_3_2_prog_languages",
      name: "مفاهيم لغات الحاسب",
      code: "CS322",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "البرمجة المرئية": const CourseSeed(
      id: "c_3_2_visual_programming",
      name: "البرمجة المرئية",
      code: "CS321",
      color: AppColors.courseSand,
      creditHours: 3,
    ),

    // 4-1
    "نظرية الحاسبات": const CourseSeed(
      id: "c_4_1_automata",
      name: "نظرية الحاسبات",
      code: "CS415",
      color: AppColors.courseSand,
      creditHours: 3,
    ),
    "تعلم الآلة": const CourseSeed(
      id: "c_4_1_machine_learning",
      name: "تعلم الآلة",
      code: "AI401",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "اكتشاف المعرفة": const CourseSeed(
      id: "c_4_1_knowledge_discovery",
      name: "اكتشاف المعرفة",
      code: "CS413",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "برمجة الأجهزة المحمولة": const CourseSeed(
      id: "c_4_1_mobile_dev",
      name: "برمجة الأجهزة المحمولة",
      code: "CS412",
      color: AppColors.courseSand,
      creditHours: 3,
    ),
    "الحوسبة السحابية": const CourseSeed(
      id: "c_4_1_cloud_computing",
      name: "الحوسبة السحابية",
      code: "CS411",
      color: AppColors.courseSand,
      creditHours: 3,
    ),
    "مشروع التخرج 1": const CourseSeed(
      id: "c_4_1_graduation_project",
      name: "مشروع التخرج",
      code: "PRJ401",
      color: AppColors.courseTeal,
      creditHours: 3,
    ),

    // 4-2
    "المترجمات": const CourseSeed(
      id: "c_4_2_compilers",
      name: "المترجمات",
      code: "CS425",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "الحوسبة الضبابية": const CourseSeed(
      id: "c_4_2_fog_computing",
      name: "الحوسبة الضبابية",
      code: "CS424",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "الرؤية بالحاسب": const CourseSeed(
      id: "c_4_2_computer_vision",
      name: "الرؤية بالحاسب",
      code: "CS423",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "معالجة البيانات الضخمة": const CourseSeed(
      id: "c_4_2_big_data",
      name: "معالجة البيانات الضخمة",
      code: "CS422",
      color: AppColors.courseClay,
      creditHours: 3,
    ),
    "معالجة اللغات الطبيعية": const CourseSeed(
      id: "c_4_2_nlp",
      name: "معالجة اللغات الطبيعية",
      code: "AI402",
      color: AppColors.courseSand,
      creditHours: 3,
    ),
    "مشروع التخرج 2": const CourseSeed(
      id: "c_4_2_graduation_project",
      name: "مشروع التخرج",
      code: "PRJ402",
      color: AppColors.courseTeal,
      creditHours: 3,
    ),
  };

  /// استرجاع قائمة المقررات الدراسية لفرقة وفصل دراسي معين
  static List<CourseSeed> getCoursesFor(int year, int semester) {
    final key = '$year-$semester';
    final subjectNames = curriculumMapping[key] ?? [];

    return subjectNames.map((name) {
      if (name == 'مشروع التخرج') {
        if (year == 4 && semester == 2) {
          return _allSubjectsMetadata['مشروع التخرج 2']!;
        }
        return _allSubjectsMetadata['مشروع التخرج 1']!;
      }

      if (_allSubjectsMetadata.containsKey(name)) {
        return _allSubjectsMetadata[name]!;
      }

      // Fallback
      return CourseSeed(
        id: 'c_${year}_${semester}_${name.hashCode.abs()}',
        name: name,
        code: 'CS${year}0$semester',
        color: AppColors.courseTeal,
        creditHours: 3,
      );
    }).toList();
  }

  /// جميع المقررات في اللائحة
  static List<CourseSeed> get allCurriculumCourses {
    final list = <CourseSeed>[];
    for (int y = 1; y <= 4; y++) {
      for (int s = 1; s <= 2; s++) {
        list.addAll(getCoursesFor(y, s));
      }
    }
    return list;
  }

  /// البحث عن مقرر بالمعرف
  static CourseSeed? findCourseById(String id) {
    for (final c in allCurriculumCourses) {
      if (c.id == id) return c;
    }
    // Also check legacy seed courses
    for (final c in AppConstants.seedCourses) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// استرجاع المقررات بحسب قائمة المعرفات
  static List<CourseSeed> findCoursesByIds(List<String> ids) {
    final result = <CourseSeed>[];
    for (final id in ids) {
      final found = findCourseById(id);
      if (found != null && !result.any((c) => c.id == found.id)) {
        result.add(found);
      }
    }
    return result;
  }
}
