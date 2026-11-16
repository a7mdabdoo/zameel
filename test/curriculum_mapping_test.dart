import 'package:flutter_test/flutter_test.dart';
import 'package:zameel/core/constants/app_constants.dart';
import 'package:zameel/core/models/app_models.dart';

void main() {
  group('Curriculum Mapping & Academic Setup Tests', () {
    test('Curriculum mapping contains all 8 semesters with exact subjects', () {
      final expectedMapping = {
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

      for (final entry in expectedMapping.entries) {
        expect(
          CurriculumConstants.curriculumMapping[entry.key],
          equals(entry.value),
          reason: 'Mismatch in curriculum for ${entry.key}',
        );
      }
    });

    test('getCoursesFor returns correct CourseSeed list with valid metadata', () {
      for (int year = 1; year <= 4; year++) {
        for (int semester = 1; semester <= 2; semester++) {
          final courses = CurriculumConstants.getCoursesFor(year, semester);
          final expectedNames = CurriculumConstants.curriculumMapping['$year-$semester']!;
          expect(courses.length, equals(expectedNames.length));

          for (int i = 0; i < courses.length; i++) {
            final course = courses[i];
            expect(course.name, equals(expectedNames[i]));
            expect(course.id, isNotEmpty);
            expect(course.code, isNotEmpty);
            expect(course.creditHours, greaterThanOrEqualTo(2));
          }
        }
      }
    });

    test('Idempotency: duplicate calls and course deduplication', () {
      final courses1 = CurriculumConstants.getCoursesFor(1, 1);
      final courses2 = CurriculumConstants.getCoursesFor(1, 1);

      expect(courses1.map((c) => c.id).toList(), equals(courses2.map((c) => c.id).toList()));

      // Deduplication test
      final merged = [...courses1, ...courses2];
      final uniqueMap = <String, CourseSeed>{};
      for (final c in merged) {
        uniqueMap[c.id] = c;
      }
      expect(uniqueMap.length, equals(courses1.length));
    });

    test('UserModel handles academicYear, semester, and isOnboarded', () {
      final user = UserModel(
        uid: 'user_123',
        name: 'أحمد',
        email: 'ahmed@test.com',
        faculty: 'كلية الحاسبات والذكاء الاصطناعي',
        year: 'الفرقة الأولى',
        academicYear: 1,
        semester: 1,
        isOnboarded: true,
      );

      final map = user.toMap();
      expect(map['academicYear'], equals(1));
      expect(map['semester'], equals(1));
      expect(map['isOnboarded'], isTrue);
      expect(map['onboardingCompleted'], isTrue);

      final reconstructed = UserModel.fromMap(map, 'user_123');
      expect(reconstructed.academicYear, equals(1));
      expect(reconstructed.semester, equals(1));
      expect(reconstructed.isOnboarded, isTrue);
      expect(reconstructed.onboardingCompleted, isTrue);
    });
  });
}
