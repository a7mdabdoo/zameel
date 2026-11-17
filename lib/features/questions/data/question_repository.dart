import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'question_model.dart';

final questionRepositoryProvider = Provider<QuestionRepository>((ref) {
  return QuestionRepository(
    firestore: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
  );
});

final questionsStreamProvider = StreamProvider.family<List<QuestionModel>, ({String academicYear, String? courseId})>((ref, arg) {
  final repo = ref.watch(questionRepositoryProvider);
  return repo.watchQuestions(academicYear: arg.academicYear, courseId: arg.courseId);
});

final questionDetailsStreamProvider = StreamProvider.family<QuestionModel?, String>((ref, questionId) {
  final repo = ref.watch(questionRepositoryProvider);
  return repo.watchQuestion(questionId);
});

final answersStreamProvider = StreamProvider.family<List<AnswerModel>, String>((ref, questionId) {
  final repo = ref.watch(questionRepositoryProvider);
  return repo.watchAnswers(questionId);
});

class QuestionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  QuestionRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  Future<String?> uploadImage({
    required XFile file,
    required String path,
  }) async {
    // المحاولة الأولى: الرفع إلى Firebase Storage
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      UploadTask uploadTask;
      uploadTask = ref.putFile(File(file.path), metadata);

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl.isNotEmpty) {
        return downloadUrl;
      }
    } catch (e) {
      debugPrint('Firebase Storage upload notice (falling back to Base64 safely): $e');
    }

    // خط دفاع قوي وبديل مباشر: إذا لم تكن خدمة Firebase Storage مفعلة بعد في كونسول المشروع،
    // يتم تحويل بايتس الصورة المضغوطة إلى Base64 Data URL وتخزينها بأمان فوري دون فقدان الصورة
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        final base64String = base64Encode(bytes);
        return 'data:image/jpeg;base64,$base64String';
      }
    } catch (fallbackError) {
      debugPrint('Base64 fallback encoding failed: $fallbackError');
    }

    return null;
  }

  Future<String> createQuestion({
    required String title,
    required String body,
    required String courseId,
    required String courseName,
    required String academicYear,
    required String authorId,
    required String authorName,
    String? authorAvatarUrl,
    XFile? imageFile,
  }) async {
    final questionDocRef = _firestore.collection('questions').doc();
    final questionId = questionDocRef.id;

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await uploadImage(
        file: imageFile,
        path: 'questions/$questionId/img_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    }

    final question = QuestionModel(
      id: questionId,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      academicYear: academicYear,
      courseId: courseId,
      courseName: courseName,
      title: title.trim(),
      body: body.trim(),
      imageUrl: imageUrl,
      answersCount: 0,
      createdAt: DateTime.now(),
    );

    final data = question.toMap();
    await questionDocRef.set(data);
    return questionId;
  }

  Future<String> postAnswer({
    required String questionId,
    required String text,
    required String authorId,
    required String authorName,
    String? authorAvatarUrl,
    XFile? imageFile,
  }) async {
    final questionDocRef = _firestore.collection('questions').doc(questionId);
    final answerDocRef = questionDocRef.collection('answers').doc();
    final answerId = answerDocRef.id;

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await uploadImage(
        file: imageFile,
        path: 'questions/$questionId/answers/$answerId/img_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
    }

    final answer = AnswerModel(
      id: answerId,
      questionId: questionId,
      authorId: authorId,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      text: text.trim(),
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
      isAcceptedSolution: false,
    );

    final batch = _firestore.batch();
    batch.set(answerDocRef, answer.toMap());
    batch.update(questionDocRef, {
      'answersCount': FieldValue.increment(1),
    });

    await batch.commit();
    return answerId;
  }

  Future<void> toggleAcceptedSolution({
    required String questionId,
    required String answerId,
    required bool currentStatus,
  }) async {
    final answerDocRef = _firestore
        .collection('questions')
        .doc(questionId)
        .collection('answers')
        .doc(answerId);

    await answerDocRef.update({
      'isAcceptedSolution': !currentStatus,
    });
  }

  Future<void> deleteQuestion(String questionId) async {
    await _firestore.collection('questions').doc(questionId).delete();
  }

  Future<void> deleteAnswer({
    required String questionId,
    required String answerId,
  }) async {
    final questionDocRef = _firestore.collection('questions').doc(questionId);
    final answerDocRef = questionDocRef.collection('answers').doc(answerId);

    final batch = _firestore.batch();
    batch.delete(answerDocRef);
    batch.update(questionDocRef, {
      'answersCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  Stream<List<QuestionModel>> watchQuestions({
    required String academicYear,
    String? courseId,
  }) {
    Query query = _firestore.collection('questions');

    // فلترة حتمية بالسنة الدراسية للطالب لضمان صلة الأسئلة بدفعته
    if (academicYear.isNotEmpty) {
      query = query.where('academicYear', isEqualTo: academicYear);
    }

    if (courseId != null && courseId.isNotEmpty) {
      query = query.where('courseId', isEqualTo: courseId);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return QuestionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // ترتيب زمني من الأحدث إلى الأقدم
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<QuestionModel?> watchQuestion(String questionId) {
    return _firestore.collection('questions').doc(questionId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return QuestionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  Stream<List<AnswerModel>> watchAnswers(String questionId) {
    return _firestore
        .collection('questions')
        .doc(questionId)
        .collection('answers')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        return AnswerModel.fromMap(doc.data(), doc.id, questionId: questionId);
      }).toList();

      // ترتيب: الحل المعتمد أولاً ثم الترتيب الزمني
      list.sort((a, b) {
        if (a.isAcceptedSolution && !b.isAcceptedSolution) return -1;
        if (!a.isAcceptedSolution && b.isAcceptedSolution) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });
      return list;
    });
  }
}
