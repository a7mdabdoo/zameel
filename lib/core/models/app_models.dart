// مطور 1
// نماذج البيانات الأساسية لمنظومة «زَميل»

import 'package:flutter/material.dart';

// 1. نموذج بيانات المستخدم
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String faculty;
  final String year;
  final String department;
  final String? whatsappNumber;
  final int timeCoins;
  final List<String> selectedCourses;
  final Map<String, int> courseRatings; // 1 to 5
  final List<String> canTeachCourseIds;
  final int completedSessions;
  final int studyHours;
  final double teacherRating;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.faculty,
    required this.year,
    this.department = 'عام (General)',
    this.whatsappNumber,
    this.timeCoins = 3,
    this.selectedCourses = const [],
    this.courseRatings = const {},
    this.canTeachCourseIds = const [],
    this.completedSessions = 0,
    this.studyHours = 0,
    this.teacherRating = 5.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'faculty': faculty,
      'year': year,
      'department': department,
      'whatsappNumber': whatsappNumber,
      'timeCoins': timeCoins,
      'selectedCourses': selectedCourses,
      'courseRatings': courseRatings,
      'canTeachCourseIds': canTeachCourseIds,
      'completedSessions': completedSessions,
      'studyHours': studyHours,
      'teacherRating': teacherRating,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? 'طالب زميل',
      email: map['email'] as String? ?? '',
      faculty: map['faculty'] as String? ?? 'كلية الحاسبات والذكاء الاصطناعي',
      year: map['year'] as String? ?? 'الفرقة الثانية',
      department: map['department'] as String? ?? 'عام (General)',
      whatsappNumber: map['whatsappNumber'] as String?,
      timeCoins: map['timeCoins'] as int? ?? 3,
      selectedCourses: List<String>.from(map['selectedCourses'] ?? []),
      courseRatings: Map<String, int>.from(map['courseRatings'] ?? {}),
      canTeachCourseIds: List<String>.from(map['canTeachCourseIds'] ?? []),
      completedSessions: map['completedSessions'] as int? ?? 0,
      studyHours: map['studyHours'] as int? ?? 0,
      teacherRating: (map['teacherRating'] as num?)?.toDouble() ?? 5.0,
    );
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? faculty,
    String? year,
    String? department,
    String? whatsappNumber,
    int? timeCoins,
    List<String>? selectedCourses,
    Map<String, int>? courseRatings,
    List<String>? canTeachCourseIds,
    int? completedSessions,
    int? studyHours,
    double? teacherRating,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      faculty: faculty ?? this.faculty,
      year: year ?? this.year,
      department: department ?? this.department,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      timeCoins: timeCoins ?? this.timeCoins,
      selectedCourses: selectedCourses ?? this.selectedCourses,
      courseRatings: courseRatings ?? this.courseRatings,
      canTeachCourseIds: canTeachCourseIds ?? this.canTeachCourseIds,
      completedSessions: completedSessions ?? this.completedSessions,
      studyHours: studyHours ?? this.studyHours,
      teacherRating: teacherRating ?? this.teacherRating,
    );
  }
}

// 2. نموذج كتلة المذاكرة (Study Block)
class StudyBlockModel {
  final String id;
  final String courseId;
  final String courseName;
  final String courseCode;
  final String topic;
  final String day;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final Color ribbonColor;
  final String room;
  final bool isCompleted;
  final bool isMissed;

  const StudyBlockModel({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.topic,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.ribbonColor,
    required this.room,
    this.isCompleted = false,
    this.isMissed = false,
  });

  StudyBlockModel copyWith({
    bool? isCompleted,
    bool? isMissed,
  }) {
    return StudyBlockModel(
      id: id,
      courseId: courseId,
      courseName: courseName,
      courseCode: courseCode,
      topic: topic,
      day: day,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      ribbonColor: ribbonColor,
      room: room,
      isCompleted: isCompleted ?? this.isCompleted,
      isMissed: isMissed ?? this.isMissed,
    );
  }
}

// 3. نموذج مواعيد المحاضرات والانشغال
class ScheduleItemModel {
  final String id;
  final String courseName;
  final String courseCode;
  final String day;
  final String startTime;
  final String endTime;
  final String room;
  final Color color;

  const ScheduleItemModel({
    required this.id,
    required this.courseName,
    required this.courseCode,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.color,
  });
}

// 4. نموذج جلسة بنك الوقت بين الأقران (Time Bank Session)
class TimeBankSessionModel {
  final String id;
  final String learnerId;
  final String learnerName;
  final String teacherId;
  final String teacherName;
  final String teacherInitials;
  final String courseName;
  final String courseCode;
  final String topic;
  final String day;
  final String time;
  final int durationMinutes;
  final String location;
  final int costCoins;
  final String status; // pending, confirmed, completed, cancelled
  final int rating;
  final String? reviewComment;

  const TimeBankSessionModel({
    required this.id,
    required this.learnerId,
    required this.learnerName,
    required this.teacherId,
    required this.teacherName,
    required this.teacherInitials,
    required this.courseName,
    required this.courseCode,
    required this.topic,
    required this.day,
    required this.time,
    required this.durationMinutes,
    required this.location,
    this.costCoins = 1,
    this.status = 'confirmed',
    this.rating = 5,
    this.reviewComment,
  });

  TimeBankSessionModel copyWith({
    String? status,
    int? rating,
    String? reviewComment,
  }) {
    return TimeBankSessionModel(
      id: id,
      learnerId: learnerId,
      learnerName: learnerName,
      teacherId: teacherId,
      teacherName: teacherName,
      teacherInitials: teacherInitials,
      courseName: courseName,
      courseCode: courseCode,
      topic: topic,
      day: day,
      time: time,
      durationMinutes: durationMinutes,
      location: location,
      costCoins: costCoins,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      reviewComment: reviewComment ?? this.reviewComment,
    );
  }
}

// 5. نموذج عرض الشرح في بنك الوقت (Teaching Offer)
class TimeBankOfferModel {
  final String id;
  final String teacherId;
  final String teacherName;
  final String courseId;
  final String courseName;
  final String courseCode;
  final String topic;
  final String day;
  final String time;
  final int durationMinutes;
  final String location;
  final Color courseColor;
  final bool isAvailable;

  const TimeBankOfferModel({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.topic,
    required this.day,
    required this.time,
    required this.durationMinutes,
    required this.location,
    required this.courseColor,
    this.isAvailable = true,
  });
}

// 6. نموذج حركة المحفظة (Wallet Transaction)
class WalletTransactionModel {
  final String id;
  final String title;
  final String date;
  final int amount;
  final bool isNegative;
  final IconData icon;

  const WalletTransactionModel({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.isNegative,
    required this.icon,
  });
}
