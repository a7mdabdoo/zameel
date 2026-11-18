// مطور 1
// نماذج البيانات الأساسية لمنظومة «زَميل» المتوافقة مع Firestore والـ Escrow Transactions

import 'package:material_ui/material_ui.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';

// 1. نموذج بيانات المستخدم
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? username;
  final String? bio;
  final String faculty;
  final String year;
  final dynamic academicYear; // 1, 2, 3, 4
  final dynamic semester;     // 1, 2
  final bool isOnboarded;
  final String department;
  final int timeCoins;
  final List<String> selectedCourses;
  final Map<String, int> courseRatings; // 1 to 5
  final List<String> canTeachCourseIds;
  final List<Map<String, dynamic>>? coursesData;
  final int completedSessions;
  final int studyHours;
  final int ratingSum;
  final int ratingCount;
  final bool onboardingCompleted;
  final DateTime? lastDisplayNameChangedAt;
  final DateTime? lastUsernameChangedAt;

  // If no sessions have been rated yet, rating must be 0.0 (NEVER default to 5.0)
  double get teacherRating => ratingCount > 0 ? (ratingSum / ratingCount) : 0.0;
  bool get hasRating => ratingCount > 0;

  // Formatted username handle with @
  String get handle {
    if (username != null && username!.trim().isNotEmpty) {
      final clean = username!.trim().replaceAll('@', '');
      return '@$clean';
    }
    final prefix = email.contains('@') ? email.split('@').first : 'user';
    final clean = prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();
    return '@${clean.isNotEmpty ? clean : 'zameel'}';
  }

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.username,
    this.bio,
    required this.faculty,
    required this.year,
    this.academicYear,
    this.semester,
    this.isOnboarded = false,
    this.department = 'عام (General)',
    this.timeCoins = AppConstants.welcomeCoins,
    this.selectedCourses = const [],
    this.courseRatings = const {},
    this.canTeachCourseIds = const [],
    this.coursesData,
    this.completedSessions = 0,
    this.studyHours = 0,
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.onboardingCompleted = false,
    this.lastDisplayNameChangedAt,
    this.lastUsernameChangedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'username': username,
      'bio': bio,
      'faculty': faculty,
      'year': year,
      'academicYear': academicYear,
      'semester': semester,
      'isOnboarded': isOnboarded,
      'department': department,
      'timeCoins': timeCoins,
      'selectedCourses': selectedCourses,
      'courseRatings': courseRatings,
      'canTeachCourseIds': canTeachCourseIds,
      'coursesData': coursesData,
      'completedSessions': completedSessions,
      'studyHours': studyHours,
      'ratingSum': ratingSum,
      'ratingCount': ratingCount,
      'teacherRating': teacherRating,
      'onboardingCompleted': onboardingCompleted || isOnboarded,
      'lastDisplayNameChangedAt': lastDisplayNameChangedAt?.toIso8601String(),
      'lastUsernameChangedAt': lastUsernameChangedAt?.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      try {
        return (val as dynamic).toDate();
      } catch (_) {
        return null;
      }
    }

    final isOnboardedVal = map['isOnboarded'] as bool? ?? (map['onboardingCompleted'] as bool? ?? false);
    final rawUsername = map['username'] as String?;
    final defaultUsername = rawUsername?.isNotEmpty == true
        ? rawUsername!.replaceAll('@', '')
        : (map['email'] != null && (map['email'] as String).contains('@')
            ? (map['email'] as String).split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase()
            : null);

    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? 'طالب زميل',
      email: map['email'] as String? ?? '',
      username: defaultUsername,
      bio: map['bio'] as String?,
      faculty: map['faculty'] as String? ?? AppConstants.faculty,
      year: map['year'] as String? ?? AppConstants.academicYear,
      academicYear: map['academicYear'],
      semester: map['semester'],
      isOnboarded: isOnboardedVal,
      department: map['department'] as String? ?? 'عام (General)',
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
      ratingSum: (map['ratingSum'] as num?)?.toInt() ?? 0,
      ratingCount: (map['ratingCount'] as num?)?.toInt() ?? 0,
      onboardingCompleted: isOnboardedVal,
      lastDisplayNameChangedAt: parseDate(map['lastDisplayNameChangedAt']),
      lastUsernameChangedAt: parseDate(map['lastUsernameChangedAt']),
    );
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? username,
    String? bio,
    String? faculty,
    String? year,
    dynamic academicYear,
    dynamic semester,
    bool? isOnboarded,
    String? department,
    int? timeCoins,
    List<String>? selectedCourses,
    Map<String, int>? courseRatings,
    List<String>? canTeachCourseIds,
    List<Map<String, dynamic>>? coursesData,
    int? completedSessions,
    int? studyHours,
    int? ratingSum,
    int? ratingCount,
    bool? onboardingCompleted,
    DateTime? lastDisplayNameChangedAt,
    DateTime? lastUsernameChangedAt,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      faculty: faculty ?? this.faculty,
      year: year ?? this.year,
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      department: department ?? this.department,
      timeCoins: timeCoins ?? this.timeCoins,
      selectedCourses: selectedCourses ?? this.selectedCourses,
      courseRatings: courseRatings ?? this.courseRatings,
      canTeachCourseIds: canTeachCourseIds ?? this.canTeachCourseIds,
      coursesData: coursesData ?? this.coursesData,
      completedSessions: completedSessions ?? this.completedSessions,
      studyHours: studyHours ?? this.studyHours,
      ratingSum: ratingSum ?? this.ratingSum,
      ratingCount: ratingCount ?? this.ratingCount,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      lastDisplayNameChangedAt: lastDisplayNameChangedAt ?? this.lastDisplayNameChangedAt,
      lastUsernameChangedAt: lastUsernameChangedAt ?? this.lastUsernameChangedAt,
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

// أنواع الجلسات في بنك الوقت (1-on-1 vs Group Webinar)
enum SessionType { individual, group }

// حالات الضمان المالي في بنك الوقت
enum EscrowStatus { held, released, refunded, disputed }

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
  final String mode; // online, in_person
  final String? meetingUrl;
  final DateTime? meetingUpdatedAt;
  final int? rating;
  final String? reviewComment;
  final DateTime? scheduledAt;
  final DateTime? createdAt;
  final String? cancellationReason;
  final String? cancelledBy;
  final DateTime? confirmedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final DateTime? teacherMarkedDoneAt;
  final DateTime? disputedAt;
  final String? disputeReason;
  final String? teacherContact;
  final String? learnerContact;
  final bool isGroupSession;
  final List<String> enrolledLearnerIds;
  final int? maxLearners;

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
    this.status = 'pending',
    this.escrowStatus = 'held',
    this.mode = 'in_person',
    this.meetingUrl,
    this.meetingUpdatedAt,
    this.rating,
    this.reviewComment,
    this.scheduledAt,
    this.createdAt,
    this.cancellationReason,
    this.cancelledBy,
    this.confirmedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.teacherMarkedDoneAt,
    this.disputedAt,
    this.disputeReason,
    this.teacherContact,
    this.learnerContact,
    this.isGroupSession = false,
    this.enrolledLearnerIds = const [],
    this.maxLearners,
  });

  SessionType get sessionType => isGroupSession ? SessionType.group : SessionType.individual;
  EscrowStatus get escrowStatusEnum {
    switch (escrowStatus) {
      case 'held':
        return EscrowStatus.held;
      case 'released_to_teacher':
      case 'released':
        return EscrowStatus.released;
      case 'refunded_to_learner':
      case 'refunded':
        return EscrowStatus.refunded;
      case 'disputed':
        return EscrowStatus.disputed;
      default:
        return EscrowStatus.held;
    }
  }

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
      'mode': mode,
      'meetingUrl': meetingUrl,
      'meetingUpdatedAt': meetingUpdatedAt?.toIso8601String(),
      'rating': rating,
      'reviewComment': reviewComment,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'cancellationReason': cancellationReason,
      'cancelledBy': cancelledBy,
      'confirmedAt': confirmedAt?.toIso8601String(),
      'rejectedAt': rejectedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'teacherMarkedDoneAt': teacherMarkedDoneAt?.toIso8601String(),
      'disputedAt': disputedAt?.toIso8601String(),
      'disputeReason': disputeReason,
      'teacherContact': teacherContact,
      'learnerContact': learnerContact,
      'isGroupSession': isGroupSession,
      'enrolledLearnerIds': enrolledLearnerIds,
      'maxLearners': maxLearners,
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
      status: map['status'] as String? ?? 'pending',
      escrowStatus: map['escrowStatus'] as String? ?? 'held',
      mode: map['mode'] as String? ?? 'in_person',
      meetingUrl: map['meetingUrl'] as String?,
      meetingUpdatedAt: parseDate(map['meetingUpdatedAt']),
      rating: (map['rating'] as num?)?.toInt(),
      reviewComment: map['reviewComment'] as String?,
      scheduledAt: parseDate(map['scheduledAt']),
      createdAt: parseDate(map['createdAt']),
      cancellationReason: map['cancellationReason'] as String?,
      cancelledBy: map['cancelledBy'] as String?,
      confirmedAt: parseDate(map['confirmedAt']),
      rejectedAt: parseDate(map['rejectedAt']),
      rejectionReason: map['rejectionReason'] as String?,
      teacherMarkedDoneAt: parseDate(map['teacherMarkedDoneAt']),
      disputedAt: parseDate(map['disputedAt']),
      disputeReason: map['disputeReason'] as String?,
      teacherContact: map['teacherContact'] as String?,
      learnerContact: map['learnerContact'] as String?,
      isGroupSession: map['isGroupSession'] as bool? ?? false,
      enrolledLearnerIds: (map['enrolledLearnerIds'] as List<dynamic>?)?.cast<String>() ?? const [],
      maxLearners: (map['maxLearners'] as num?)?.toInt(),
    );
  }

  TimeBankSessionModel copyWith({
    String? status,
    String? escrowStatus,
    String? mode,
    String? meetingUrl,
    DateTime? meetingUpdatedAt,
    int? rating,
    String? reviewComment,
    DateTime? scheduledAt,
    String? cancellationReason,
    String? cancelledBy,
    DateTime? confirmedAt,
    DateTime? rejectedAt,
    String? rejectionReason,
    DateTime? teacherMarkedDoneAt,
    DateTime? disputedAt,
    String? disputeReason,
    String? teacherContact,
    String? learnerContact,
    bool? isGroupSession,
    List<String>? enrolledLearnerIds,
    int? maxLearners,
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
      mode: mode ?? this.mode,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      meetingUpdatedAt: meetingUpdatedAt ?? this.meetingUpdatedAt,
      rating: rating ?? this.rating,
      reviewComment: reviewComment ?? this.reviewComment,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      teacherMarkedDoneAt: teacherMarkedDoneAt ?? this.teacherMarkedDoneAt,
      disputedAt: disputedAt ?? this.disputedAt,
      disputeReason: disputeReason ?? this.disputeReason,
      teacherContact: teacherContact ?? this.teacherContact,
      learnerContact: learnerContact ?? this.learnerContact,
      isGroupSession: isGroupSession ?? this.isGroupSession,
      enrolledLearnerIds: enrolledLearnerIds ?? this.enrolledLearnerIds,
      maxLearners: maxLearners ?? this.maxLearners,
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

// 4-أ. فترات الإتاحة الأسبوعية لعرض الشرح (Weekly Availability Slot)
class OfferTimeSlot {
  final int weekday; // 0 = السبت, 1 = الأحد, ..., 6 = الجمعة (أسبوع التطبيق)
  final int startMin; // الدقائق من منتصف الليل (0 - 1439) بتوقيت Africa/Cairo
  final int endMin;   // الدقائق من منتصف الليل (0 - 1439) بتوقيت Africa/Cairo

  const OfferTimeSlot({
    required this.weekday,
    required this.startMin,
    required this.endMin,
  });

  Map<String, dynamic> toMap() {
    return {
      'weekday': weekday,
      'startMin': startMin,
      'endMin': endMin,
    };
  }

  factory OfferTimeSlot.fromMap(Map<String, dynamic> map) {
    return OfferTimeSlot(
      weekday: (map['weekday'] as num?)?.toInt() ?? 0,
      startMin: (map['startMin'] as num?)?.toInt() ?? 0,
      endMin: (map['endMin'] as num?)?.toInt() ?? 0,
    );
  }

  String get weekdayName => appWeekdayNames[weekday] ?? 'السبت';

  String get formattedRange {
    return '$weekdayName • ${formatMinutes(startMin)} – ${formatMinutes(endMin)}';
  }

  static String formatMinutes(int minutes) {
    final h24 = minutes ~/ 60;
    final m = minutes % 60;
    final period = h24 >= 12 ? 'م' : 'ص';
    final h12 = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
    final mStr = m.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }

  static const Map<int, String> appWeekdayNames = {
    0: 'السبت',
    1: 'الأحد',
    2: 'الاثنين',
    3: 'الثلاثاء',
    4: 'الأربعاء',
    5: 'الخميس',
    6: 'الجمعة',
  };

  static const Map<String, int> appWeekdayIndexes = {
    'السبت': 0,
    'الأحد': 1,
    'الاثنين': 2,
    'الثلاثاء': 3,
    'الأربعاء': 4,
    'الخميس': 5,
    'الجمعة': 6,
  };
}

// 5. نموذج عرض الشرح في بنك الوقت (Teaching Offer - Live Academic Marketplace)
class TimeBankOfferModel {
  final String id;
  final String teacherId;
  final String teacherName;
  final String? teacherAvatarUrl;
  final double teacherRating;
  final String courseId;
  final String courseName;
  final String topic;
  final SessionType sessionType; // individual vs group
  final DateTime? scheduledAt;   // Exact date & time (No confusing ranges)
  final int durationMinutes;     // Typically 45 or 60 min
  final String? meetingUrl;      // Required for group, optional/chat-shared for individual
  final int maxAttendees;        // 1 for individual, e.g. 100 for group
  final List<String> attendeeIds;
  final bool isCompleted;
  final DateTime? createdAt;
  final String? academicYear;
  final Color courseColor;
  final List<OfferTimeSlot> slots;
  final bool isFlexibleRange;
  final String? timeRangeStart;
  final String? timeRangeEnd;
  final String? rawDay;
  final String? rawTime;
  final String? rawLocation;
  final String? rawMode;
  final String? rawCourseCode;

  const TimeBankOfferModel({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    this.teacherAvatarUrl,
    this.teacherRating = 0.0,
    required this.courseId,
    required this.courseName,
    required this.topic,
    SessionType? sessionType,
    this.scheduledAt,
    this.durationMinutes = 60,
    this.meetingUrl,
    int? maxAttendees,
    List<String>? attendeeIds,
    this.isCompleted = false,
    this.createdAt,
    this.academicYear,
    this.courseColor = const Color(0xFF2F8F89),
    this.slots = const [],
    this.isFlexibleRange = false,
    this.timeRangeStart,
    this.timeRangeEnd,
    // Legacy / backward-compat parameters:
    String? day,
    String? time,
    String? courseCode,
    String? location,
    String? mode,
    bool? isAvailable,
    bool? isGroupSession,
    int? maxLearners,
    List<String>? enrolledLearnerIds,
  })  : sessionType = sessionType ?? ((isGroupSession == true) ? SessionType.group : SessionType.individual),
        maxAttendees = maxAttendees ?? maxLearners ?? ((sessionType == SessionType.group || isGroupSession == true) ? 100 : 1),
        attendeeIds = attendeeIds ?? enrolledLearnerIds ?? const [],
        rawDay = day,
        rawTime = time,
        rawLocation = location,
        rawMode = mode,
        rawCourseCode = courseCode;

  // Getters
  bool get isFull => attendeeIds.length >= maxAttendees;
  int get attendeesCount => attendeeIds.length;
  bool get isGroupSession => sessionType == SessionType.group;
  List<String> get enrolledLearnerIds => attendeeIds;
  int? get maxLearners => maxAttendees;
  bool get isAvailable => !isCompleted && !isFull;
  String get mode => rawMode ?? 'online';
  String get location => rawLocation ?? 'أونلاين (Google Meet / Zoom)';
  String get courseCode => rawCourseCode ?? courseId;
  DateTime get effectiveScheduledAt => scheduledAt ?? (createdAt ?? DateTime.now());
  String get day => rawDay ?? (scheduledAt != null ? formatDayArabic(scheduledAt!) : 'الخميس');
  String get time => rawTime ?? (scheduledAt != null ? formatTimeArabic(scheduledAt!) : '08:00 م');

  static String formatDayArabic(DateTime dt) {
    const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[(dt.weekday - 1) % 7];
  }

  static String formatTimeArabic(DateTime dt) {
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'مساءً' : 'صباحاً';
    return '$hour12:$minuteStr $period';
  }

  static String formatFullDateArabic(DateTime dt) {
    return '${formatDayArabic(dt)}، ${formatTimeArabic(dt)}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'teacherAvatarUrl': teacherAvatarUrl,
      'teacherRating': teacherRating,
      'courseId': courseId,
      'courseName': courseName,
      'courseCode': courseCode,
      'topic': topic,
      'academicYear': academicYear,
      'sessionType': sessionType.name,
      'scheduledAt': (scheduledAt ?? effectiveScheduledAt).toIso8601String(),
      'durationMinutes': durationMinutes,
      'meetingUrl': meetingUrl,
      'maxAttendees': maxAttendees,
      'attendeeIds': attendeeIds,
      'isCompleted': isCompleted,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'courseColor': courseColor.toARGB32(),
      'slots': (slots.isNotEmpty
              ? slots
              : [
                  OfferTimeSlot(
                    weekday: (effectiveScheduledAt.weekday - 1) % 7,
                    startMin: effectiveScheduledAt.hour * 60 + effectiveScheduledAt.minute,
                    endMin: effectiveScheduledAt.hour * 60 + effectiveScheduledAt.minute + durationMinutes,
                  )
                ])
          .map((s) => s.toMap())
          .toList(),
      // Legacy compatibility keys:
      'isAvailable': isAvailable,
      'isGroupSession': isGroupSession,
      'maxLearners': maxAttendees,
      'enrolledLearnerIds': attendeeIds,
      'day': day,
      'time': time,
      'mode': mode,
      'location': location,
      'isFlexibleRange': isFlexibleRange,
      'timeRangeStart': timeRangeStart,
      'timeRangeEnd': timeRangeEnd,
    };
  }

  static TimeBankOfferModel? fromMapSafe(Map<String, dynamic>? map, String id) {
    if (map == null) return null;
    try {
      final teacherId = map['teacherId'] as String?;
      final courseName = map['courseName'] as String?;
      if (teacherId == null || teacherId.trim().isEmpty || courseName == null || courseName.trim().isEmpty) {
        return null;
      }

      // التحقق الدفاعي من الشرائح إذا تم تمريرها صراحة في الاختبارات أو المستندات القديمة
      List<OfferTimeSlot> parsedSlots = const [];
      if (map.containsKey('slots') && map['slots'] is List) {
        final rawSlots = map['slots'] as List;
        final list = <OfferTimeSlot>[];
        for (final item in rawSlots) {
          if (item is Map) {
            try {
              final slotMap = Map<String, dynamic>.from(item);
              final weekday = (slotMap['weekday'] as num?)?.toInt();
              final startMin = (slotMap['startMin'] as num?)?.toInt();
              final endMin = (slotMap['endMin'] as num?)?.toInt();
              if (weekday != null &&
                  weekday >= 0 &&
                  weekday <= 6 &&
                  startMin != null &&
                  startMin >= 0 &&
                  startMin < 1440 &&
                  endMin != null &&
                  endMin > startMin &&
                  endMin <= 1440) {
                list.add(OfferTimeSlot(
                  weekday: weekday,
                  startMin: startMin,
                  endMin: endMin,
                ));
              }
            } catch (_) {}
          }
        }
        if (rawSlots.isNotEmpty && list.isEmpty) {
          return null; // كل الشرائح المرسلة كانت تالفة
        }
        parsedSlots = list.length > 7 ? list.sublist(0, 7) : list;
      }

      return TimeBankOfferModel.fromMap(map, id, overrideSlots: parsedSlots.isNotEmpty ? parsedSlots : null);
    } catch (_) {
      return null;
    }
  }

  factory TimeBankOfferModel.fromMap(Map<String, dynamic> map, String id, {List<OfferTimeSlot>? overrideSlots}) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      try {
        return (v as dynamic).toDate() as DateTime?;
      } catch (_) {
        return null;
      }
    }

    final isGroup = map['sessionType'] == 'group' || map['isGroupSession'] == true;
    final sessionType = isGroup ? SessionType.group : SessionType.individual;

    final attendeeIds = (map['attendeeIds'] as List<dynamic>?)?.cast<String>() ??
        (map['enrolledLearnerIds'] as List<dynamic>?)?.cast<String>() ??
        const <String>[];

    final maxAttendees = (map['maxAttendees'] as num?)?.toInt() ??
        (map['maxLearners'] as num?)?.toInt() ??
        (isGroup ? 100 : 1);

    final scheduledAt = parseDate(map['scheduledAt']);
    final createdAt = parseDate(map['createdAt']);
    final colorInt = (map['courseColor'] as num?)?.toInt();

    return TimeBankOfferModel(
      id: id,
      teacherId: map['teacherId'] as String? ?? '',
      teacherName: map['teacherName'] as String? ?? 'زميل',
      teacherAvatarUrl: map['teacherAvatarUrl'] as String?,
      teacherRating: (map['teacherRating'] as num?)?.toDouble() ?? 0.0,
      courseId: map['courseId'] as String? ?? '',
      courseName: map['courseName'] as String? ?? '',
      courseCode: map['courseCode'] as String? ?? '',
      topic: map['topic'] as String? ?? '',
      academicYear: map['academicYear'] as String?,
      sessionType: sessionType,
      scheduledAt: scheduledAt,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      meetingUrl: map['meetingUrl'] as String?,
      maxAttendees: maxAttendees,
      attendeeIds: attendeeIds,
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAt: createdAt,
      courseColor: colorInt != null ? Color(colorInt) : const Color(0xFF2F8F89),
      slots: overrideSlots ?? const [],
      isFlexibleRange: map['isFlexibleRange'] as bool? ?? false,
      timeRangeStart: map['timeRangeStart'] as String?,
      timeRangeEnd: map['timeRangeEnd'] as String?,
      day: map['day'] as String?,
      time: map['time'] as String?,
      location: map['location'] as String?,
      mode: map['mode'] as String?,
    );
  }

  TimeBankOfferModel copyWith({
    String? id,
    String? teacherId,
    String? teacherName,
    String? teacherAvatarUrl,
    double? teacherRating,
    String? courseId,
    String? courseName,
    String? topic,
    String? academicYear,
    SessionType? sessionType,
    DateTime? scheduledAt,
    int? durationMinutes,
    String? meetingUrl,
    int? maxAttendees,
    List<String>? attendeeIds,
    bool? isCompleted,
    DateTime? createdAt,
    Color? courseColor,
    List<OfferTimeSlot>? slots,
    bool? isFlexibleRange,
    String? timeRangeStart,
    String? timeRangeEnd,
    String? day,
    String? time,
    String? courseCode,
    String? location,
    String? mode,
    bool? isAvailable,
    bool? isGroupSession,
    int? maxLearners,
    List<String>? enrolledLearnerIds,
  }) {
    return TimeBankOfferModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      teacherAvatarUrl: teacherAvatarUrl ?? this.teacherAvatarUrl,
      teacherRating: teacherRating ?? this.teacherRating,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      topic: topic ?? this.topic,
      academicYear: academicYear ?? this.academicYear,
      sessionType: sessionType ?? (isGroupSession != null ? (isGroupSession ? SessionType.group : SessionType.individual) : this.sessionType),
      scheduledAt: scheduledAt ?? this.scheduledAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      maxAttendees: maxAttendees ?? maxLearners ?? this.maxAttendees,
      attendeeIds: attendeeIds ?? enrolledLearnerIds ?? this.attendeeIds,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      courseColor: courseColor ?? this.courseColor,
      slots: slots ?? this.slots,
      isFlexibleRange: isFlexibleRange ?? this.isFlexibleRange,
      timeRangeStart: timeRangeStart ?? this.timeRangeStart,
      timeRangeEnd: timeRangeEnd ?? this.timeRangeEnd,
      day: day ?? rawDay,
      time: time ?? rawTime,
      courseCode: courseCode ?? rawCourseCode,
      location: location ?? rawLocation,
      mode: mode ?? rawMode,
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
      case 'release':
        return Icons.volunteer_activism_outlined;
      case 'session_booking':
      case 'booking':
        return Icons.school_outlined;
      case 'cancellation_refund':
      case 'refund':
        return Icons.undo_rounded;
      case 'late_compensation':
      case 'compensation':
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
