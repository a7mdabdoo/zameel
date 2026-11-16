// مطور 1
// نماذج البيانات الأساسية لمنظومة «زَميل» المتوافقة مع Firestore والـ Escrow Transactions

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

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
  final List<Map<String, dynamic>>? coursesData;
  final int completedSessions;
  final int studyHours;
  final double teacherRating;
  final bool onboardingCompleted;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.faculty,
    required this.year,
    this.department = 'عام (General)',
    this.whatsappNumber,
    this.timeCoins = AppConstants.welcomeCoins,
    this.selectedCourses = const [],
    this.courseRatings = const {},
    this.canTeachCourseIds = const [],
    this.coursesData,
    this.completedSessions = 0,
    this.studyHours = 0,
    this.teacherRating = 5.0,
    this.onboardingCompleted = false,
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
      'coursesData': coursesData,
      'completedSessions': completedSessions,
      'studyHours': studyHours,
      'teacherRating': teacherRating,
      'onboardingCompleted': onboardingCompleted,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? 'طالب زميل',
      email: map['email'] as String? ?? '',
      faculty: map['faculty'] as String? ?? AppConstants.faculty,
      year: map['year'] as String? ?? AppConstants.academicYear,
      department: map['department'] as String? ?? 'عام (General)',
      whatsappNumber: map['whatsappNumber'] as String?,
      timeCoins: (map['timeCoins'] as num?)?.toInt() ?? AppConstants.welcomeCoins,
      selectedCourses: List<String>.from(map['selectedCourses'] ?? []),
      courseRatings: (map['courseRatings'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          ) ??
          {},
      canTeachCourseIds: List<String>.from(map['canTeachCourseIds'] ?? []),
      coursesData: (map['coursesData'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      completedSessions: (map['completedSessions'] as num?)?.toInt() ?? 0,
      studyHours: (map['studyHours'] as num?)?.toInt() ?? 0,
      teacherRating: (map['teacherRating'] as num?)?.toDouble() ?? 5.0,
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
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
    List<Map<String, dynamic>>? coursesData,
    int? completedSessions,
    int? studyHours,
    double? teacherRating,
    bool? onboardingCompleted,
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
      coursesData: coursesData ?? this.coursesData,
      completedSessions: completedSessions ?? this.completedSessions,
      studyHours: studyHours ?? this.studyHours,
      teacherRating: teacherRating ?? this.teacherRating,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseName': courseName,
      'courseCode': courseCode,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'colorValue': color.toARGB32(),
    };
  }

  factory ScheduleItemModel.fromMap(Map<String, dynamic> map) {
    return ScheduleItemModel(
      id: map['id'] as String? ?? 'lec_${DateTime.now().millisecondsSinceEpoch}',
      courseName: map['courseName'] as String? ?? '',
      courseCode: map['courseCode'] as String? ?? '',
      day: map['day'] as String? ?? 'السبت',
      startTime: map['startTime'] as String? ?? '09:00 ص',
      endTime: map['endTime'] as String? ?? '10:30 ص',
      room: map['room'] as String? ?? 'قاعة',
      color: map['colorValue'] != null ? Color((map['colorValue'] as num).toInt()) : AppColors.courseSlate,
    );
  }

  ScheduleItemModel copyWith({
    String? id,
    String? courseName,
    String? courseCode,
    String? day,
    String? startTime,
    String? endTime,
    String? room,
    Color? color,
  }) {
    return ScheduleItemModel(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      day: day ?? this.day,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      color: color ?? this.color,
    );
  }
}

// 4. نموذج جلسة بنك الوقت مع الضمان المعلق (Time Bank Session with Escrow)
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
  final String status; // pending, confirmed, completed, cancelled_by_learner, cancelled_by_teacher
  final String escrowStatus; // held, released_to_teacher, refunded_to_learner
  final int rating;
  final String? reviewComment;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final String? cancellationReason;
  final String? cancelledBy;

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
    this.costCoins = AppConstants.sessionCostCoins,
    this.status = 'confirmed',
    this.escrowStatus = 'held',
    this.rating = 5,
    this.reviewComment,
    this.scheduledAt,
    this.createdAt,
    this.cancellationReason,
    this.cancelledBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'learnerId': learnerId,
      'learnerName': learnerName,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherInitials': teacherInitials,
      'courseName': courseName,
      'courseCode': courseCode,
      'topic': topic,
      'day': day,
      'time': time,
      'durationMinutes': durationMinutes,
      'location': location,
      'costCoins': costCoins,
      'status': status,
      'escrowStatus': escrowStatus,
      'rating': rating,
      'reviewComment': reviewComment,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
    };
  }

  factory TimeBankSessionModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val);
      try {
        return (val as dynamic).toDate() as DateTime;
      } catch (_) {}
      return null;
    }

    return TimeBankSessionModel(
      id: id,
      learnerId: map['learnerId'] as String? ?? '',
      learnerName: map['learnerName'] as String? ?? '',
      teacherId: map['teacherId'] as String? ?? '',
      teacherName: map['teacherName'] as String? ?? '',
      teacherInitials: map['teacherInitials'] as String? ?? '',
      courseName: map['courseName'] as String? ?? '',
      courseCode: map['courseCode'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      day: map['day'] as String? ?? '',
      time: map['time'] as String? ?? '',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      location: map['location'] as String? ?? '',
      costCoins: (map['costCoins'] as num?)?.toInt() ?? AppConstants.sessionCostCoins,
      status: map['status'] as String? ?? 'confirmed',
      escrowStatus: map['escrowStatus'] as String? ?? 'held',
      rating: (map['rating'] as num?)?.toInt() ?? 5,
      reviewComment: map['reviewComment'] as String?,
      scheduledAt: parseDate(map['scheduledAt']),
      createdAt: parseDate(map['createdAt']),
      cancellationReason: map['cancellationReason'] as String?,
      cancelledBy: map['cancelledBy'] as String?,
    );
  }

  TimeBankSessionModel copyWith({
    String? status,
    String? escrowStatus,
    int? rating,
    String? reviewComment,
    DateTime? scheduledAt,
    String? cancellationReason,
    String? cancelledBy,
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
      escrowStatus: escrowStatus ?? this.escrowStatus,
      rating: rating ?? this.rating,
      reviewComment: reviewComment ?? this.reviewComment,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }
}

// 4-أ. نموذج رسالة محادثة الجلسة (Session Chat Message)
class SessionMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  const SessionMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SessionMessageModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      try {
        return (val as dynamic).toDate() as DateTime;
      } catch (_) {}
      return DateTime.now();
    }

    return SessionMessageModel(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'زميل',
      text: map['text'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
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
  final DateTime? createdAt;

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
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'courseId': courseId,
      'courseName': courseName,
      'courseCode': courseCode,
      'topic': topic,
      'day': day,
      'time': time,
      'durationMinutes': durationMinutes,
      'location': location,
      'courseColor': courseColor.toARGB32(),
      'isAvailable': isAvailable,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory TimeBankOfferModel.fromMap(Map<String, dynamic> map, String id) {
    final colorInt = (map['courseColor'] as num?)?.toInt();
    return TimeBankOfferModel(
      id: id,
      teacherId: map['teacherId'] as String? ?? '',
      teacherName: map['teacherName'] as String? ?? '',
      courseId: map['courseId'] as String? ?? '',
      courseName: map['courseName'] as String? ?? '',
      courseCode: map['courseCode'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      day: map['day'] as String? ?? '',
      time: map['time'] as String? ?? '',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      location: map['location'] as String? ?? '',
      courseColor: colorInt != null ? Color(colorInt) : const Color(0xFF2F8F89),
      isAvailable: map['isAvailable'] as bool? ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }
}

// 6. نموذج حركة المحفظة (Wallet Transaction)
class WalletTransactionModel {
  final String id;
  final String title;
  final String date;
  final int amount;
  final bool isNegative;
  final IconData icon;
  final String? userId;
  final String? sessionId;
  final String type; // welcome_gift, session_booking, session_earning, cancellation_refund, late_compensation
  final DateTime? createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.title,
    required this.date,
    required this.amount,
    required this.isNegative,
    required this.icon,
    this.userId,
    this.sessionId,
    this.type = 'session_booking',
    this.createdAt,
  });

  static IconData getIconForType(String type) {
    switch (type) {
      case 'welcome_gift':
        return Icons.card_giftcard_rounded;
      case 'session_earning':
        return Icons.volunteer_activism_outlined;
      case 'session_booking':
        return Icons.school_outlined;
      case 'cancellation_refund':
        return Icons.undo_rounded;
      case 'late_compensation':
        return Icons.shield_outlined;
      case 'study_reward':
        return Icons.stars_rounded;
      default:
        return Icons.wallet_outlined;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'sessionId': sessionId,
      'title': title,
      'date': date,
      'amount': amount,
      'isNegative': isNegative,
      'type': type,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory WalletTransactionModel.fromMap(Map<String, dynamic> map, String id) {
    final txType = map['type'] as String? ?? 'session_booking';
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is String) return DateTime.tryParse(val);
      try {
        return (val as dynamic).toDate() as DateTime;
      } catch (_) {}
      return null;
    }

    return WalletTransactionModel(
      id: id,
      userId: map['userId'] as String?,
      sessionId: map['sessionId'] as String?,
      title: map['title'] as String? ?? '',
      date: map['date'] as String? ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 1,
      isNegative: map['isNegative'] as bool? ?? false,
      type: txType,
      icon: getIconForType(txType),
      createdAt: parseDate(map['createdAt']),
    );
  }
}
