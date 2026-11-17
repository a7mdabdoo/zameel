import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String academicYear; // e.g. 'الفرقة الأولى', 'الفرقة الثانية', etc.
  final String courseId;
  final String courseName;
  final String title;
  final String body;
  final String? imageUrl;
  final int answersCount;
  final DateTime createdAt;

  const QuestionModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.academicYear,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.body,
    this.imageUrl,
    this.answersCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'academicYear': academicYear,
      'courseId': courseId,
      'courseName': courseName,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'answersCount': answersCount,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory QuestionModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return QuestionModel(
      id: docId,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'طالب زميل',
      authorAvatarUrl: map['authorAvatarUrl'] as String?,
      academicYear: map['academicYear'] as String? ?? 'الفرقة الأولى',
      courseId: map['courseId'] as String? ?? '',
      courseName: map['courseName'] as String? ?? 'مادة عامة',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      answersCount: (map['answersCount'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(map['createdAt']),
    );
  }

  QuestionModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    String? academicYear,
    String? courseId,
    String? courseName,
    String? title,
    String? body,
    String? imageUrl,
    int? answersCount,
    DateTime? createdAt,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      academicYear: academicYear ?? this.academicYear,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      answersCount: answersCount ?? this.answersCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AnswerModel {
  final String id;
  final String questionId;
  final String authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final String text;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isAcceptedSolution;

  const AnswerModel({
    required this.id,
    required this.questionId,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl,
    required this.text,
    this.imageUrl,
    required this.createdAt,
    this.isAcceptedSolution = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionId': questionId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'text': text,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isAcceptedSolution': isAcceptedSolution,
    };
  }

  factory AnswerModel.fromMap(Map<String, dynamic> map, String docId, {required String questionId}) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return AnswerModel(
      id: docId,
      questionId: questionId,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'طالب زميل',
      authorAvatarUrl: map['authorAvatarUrl'] as String?,
      text: map['text'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      createdAt: parseDate(map['createdAt']),
      isAcceptedSolution: map['isAcceptedSolution'] as bool? ?? false,
    );
  }

  AnswerModel copyWith({
    String? id,
    String? questionId,
    String? authorId,
    String? authorName,
    String? authorAvatarUrl,
    String? text,
    String? imageUrl,
    DateTime? createdAt,
    bool? isAcceptedSolution,
  }) {
    return AnswerModel(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      isAcceptedSolution: isAcceptedSolution ?? this.isAcceptedSolution,
    );
  }
}
