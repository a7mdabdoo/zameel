import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CourseSeed {
  final String id;
  final String name;
  final String code;
  final Color color;

  const CourseSeed({
    required this.id,
    required this.name,
    required this.code,
    required this.color,
  });
}

class AppConstants {
  // App Identity
  static const String appName = 'زَميل';
  static const String appSlogan = 'ذاكر بخطة، وعلّم زميلك، وتعلّم من غيرك';

  // Faculty and Year (2nd Year CS & AI)
  static const String faculty = 'كلية الحاسبات والذكاء الاصطناعي';
  static const String academicYear = 'الفرقة الثانية';

  // Points & Time Rules (Answer to Question 1 & 2)
  static const int welcomeCoins = 2; // هدية البداية: 2 عملات وقت
  static const int sessionCostCoins = 1; // تكلفة كل جلسة: 1 عملة وقت ثابتة
  static const int maxDailyStudyHours = 3; // أقصى ساعات مذاكرة يومية
  static const int studyBlockDurationMin = 45; // مدة كتلة المذاكرة
  static const int breakDurationMin = 10; // مدة الاستراحة بعد الكتلة

  // Seed Courses for 2nd Year CS & AI
  static const List<CourseSeed> seedCourses = [
    CourseSeed(
      id: 'cs201',
      name: 'البرمجة الكائنية (OOP)',
      code: 'CS201',
      color: AppColors.courseTeal,
    ),
    CourseSeed(
      id: 'cs202',
      name: 'هياكل البيانات (Data Structures)',
      code: 'CS202',
      color: AppColors.courseSage,
    ),
    CourseSeed(
      id: 'is201',
      name: 'قواعد البيانات (Databases)',
      code: 'IS201',
      color: AppColors.courseSand,
    ),
    CourseSeed(
      id: 'math201',
      name: 'الجبر الخطي (Linear Algebra)',
      code: 'MATH201',
      color: AppColors.courseClay,
    ),
    CourseSeed(
      id: 'math202',
      name: 'التفاضل والتكامل (Calculus)',
      code: 'MATH202',
      color: AppColors.courseSlate,
    ),
    CourseSeed(
      id: 'cs203',
      name: 'تنظيم الحواسب (Computer Org)',
      code: 'CS203',
      color: AppColors.courseDustPlum,
    ),
  ];
}
