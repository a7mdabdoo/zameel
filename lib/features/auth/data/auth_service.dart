// مطور 1
// خدمة المصادقة وحسابات المستخدمين عبر Firebase Auth & Cloud Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';

class AuthService {
  FirebaseAuth? get _auth {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (e) {
      debugPrint('AuthService: Failed to get FirebaseAuth instance: $e');
    }
    return null;
  }

  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (e) {
      debugPrint('AuthService: Failed to get FirebaseFirestore instance: $e');
    }
    return null;
  }

  Stream<User?> get authStateChanges =>
      _auth?.userChanges() ?? Stream.value(null);

  User? get currentUser => _auth?.currentUser;

  // =========================================================================
  // 1. إنشاء حساب جديد بواسطة (الاسم، اسم المستخدم، البريد، كلمة المرور)
  // =========================================================================
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required String username,
  }) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) {
      throw FirebaseException(
        plugin: 'auth',
        message: 'Firebase is not initialized',
      );
    }

    final cleanEmail = email.trim();
    if (!AppConstants.isValidEmail(cleanEmail)) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'يرجى إدخال بريد إلكتروني صالح ومكتمل',
      );
    }

    final cleanUsername = username.trim().toLowerCase();

    // إنشاء الحساب في Firebase Auth
    final cred = await auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    if (cred.user != null) {
      await cred.user!.updateDisplayName(name.trim());

      // إرسال رسالة التأكيد إلى البريد الإلكتروني فوراً
      try {
        await cred.user!.sendEmailVerification();
      } catch (e) {
        debugPrint('AuthService: Failed to send initial email verification: $e');
      }

      // إنشاء مستند المستخدم الأولي برصيد ترحيبي 2 عملة وتقييم 0
      await firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'name': name.trim(),
        'username': cleanUsername.isEmpty ? cleanEmail.split('@').first : cleanUsername,
        'email': cleanEmail,
        'timeCoins': AppConstants.welcomeCoins,
        'faculty': AppConstants.faculty,
        'year': null,
        'academicYear': null,
        'semester': null,
        'selectedCourses': <String>[],
        'coursesData': <Map<String, dynamic>>[],
        'courseRatings': <String, dynamic>{},
        'completedSessions': 0,
        'ratingSum': 0,
        'ratingCount': 0,
        'teacherRating': 0.0,
        'lastSessionId': null,
        'isOnboarded': false,
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return cred;
  }

  // =========================================================================
  // 2. تسجيل الدخول بواسطة البريد الإلكتروني وكلمة المرور
  // =========================================================================
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw FirebaseException(
        plugin: 'auth',
        message: 'Firebase is not initialized',
      );
    }

    final cred = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // تحديث التوكن لضمان تحديث حالة البريد وقواعد الأمان
    if (cred.user != null) {
      try {
        await cred.user!.getIdToken(true);
      } catch (e) {
        debugPrint('AuthService: Failed to force refresh ID token on signIn: $e');
      }

      // التحقق من وجود مستند المستخدم، وإذا كان المستخدم يسجل دخوله نضمن أن onboardingCompleted = true
      // حتى لا تظهر له شاشات التهيئة مرة أخرى عند كل تسجيل دخول
      if (_firestore != null) {
        try {
          final docRef = _firestore!.collection('users').doc(cred.user!.uid);
          final doc = await docRef.get();
          if (!doc.exists) {
            await docRef.set({
              'uid': cred.user!.uid,
              'name': cred.user!.displayName ?? email.split('@').first,
              'username': email.split('@').first.toLowerCase(),
              'timeCoins': AppConstants.welcomeCoins,
              'faculty': AppConstants.faculty,
              'year': AppConstants.academicYear,
              'department': 'عام (General)',
              'selectedCourses': <String>[],
              'courseRatings': <String, dynamic>{},
              'completedSessions': 0,
              'ratingSum': 0,
              'ratingCount': 0,
              'lastSessionId': null,
              'onboardingCompleted': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
          } else {
            final data = doc.data();
            final updates = <String, dynamic>{};
            if ((data?['onboardingCompleted'] as bool? ?? false) == false) {
              updates['onboardingCompleted'] = true;
            }
            if ((data?['name'] as String?)?.isEmpty ?? true) {
              updates['name'] = cred.user!.displayName ?? email.split('@').first;
            }
            if (updates.isNotEmpty) {
              await docRef.update(updates);
            }
          }
        } catch (e) {
          debugPrint('AuthService: Failed to sync user doc during signIn: $e');
        }
      }
    }

    return cred;
  }

  // =========================================================================
  // 3. إعادة إرسال رسالة التأكيد وفحص الحالة
  // =========================================================================
  Future<void> signOut() async {
    await _auth?.signOut();
  }

  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> reloadUserAndCheckVerified() async {
    final user = currentUser;
    if (user != null) {
      await user.reload();
      await user.getIdToken(true);
      return _auth?.currentUser?.emailVerified ?? false;
    }
    return false;
  }

  // =========================================================================
  // 4. تحديث الملف الشخصي وإتمام التهيئة
  // =========================================================================
  Future<void> updateUserProfile({
    String? faculty,
    String? year,
    dynamic academicYear,
    dynamic semester,
    String? term,
    String? department,
    List<String>? selectedCourses,
    Map<String, int>? courseRatings,
    List<Map<String, dynamic>>? coursesData,
    List<Map<String, dynamic>>? lecturesData,
    bool? onboardingCompleted,
    bool? isOnboarded,
  }) async {
    final uid = currentUser?.uid;
    final firestore = _firestore;
    if (uid == null || firestore == null) return;

    final updates = <String, dynamic>{};
    if (faculty != null) updates['faculty'] = faculty;
    if (year != null) updates['year'] = year;
    if (academicYear != null) updates['academicYear'] = academicYear;
    if (semester != null) updates['semester'] = semester;
    if (term != null) updates['term'] = term;
    if (department != null) updates['department'] = department;
    if (selectedCourses != null) updates['selectedCourses'] = selectedCourses;
    if (courseRatings != null) updates['courseRatings'] = courseRatings;
    if (coursesData != null) updates['coursesData'] = coursesData;
    if (lecturesData != null) updates['lecturesData'] = lecturesData;
    if (onboardingCompleted != null) updates['onboardingCompleted'] = onboardingCompleted;
    if (isOnboarded != null) updates['isOnboarded'] = isOnboarded;

    try {
      final docRef = firestore.collection('users').doc(uid);
      await docRef.set(updates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('updateUserProfile error: $e');
      rethrow;
    }
  }

  /// حفظ اختيار الفرقة الدراسية والفصل الدراسي وإسناد المواد تلقائياً (بشكل Idempotent)
  Future<void> saveAcademicSetup({
    required int academicYear,
    required int semester,
    required List<CourseSeed> courses,
  }) async {
    final uid = currentUser?.uid;
    final firestore = _firestore;
    if (uid == null || firestore == null) {
      throw Exception('المستخدم غير مسجل الدخول');
    }

    final yearLabel = CurriculumConstants.academicYearLabels[academicYear] ?? 'الفرقة $academicYear';
    final semesterLabel = CurriculumConstants.semesterLabels[semester] ?? 'الترم $semester';

    // ضمان الـ Idempotency: عدم تكرار المواد وحفظ معرفات وقيم فريدة
    final uniqueMap = <String, CourseSeed>{};
    for (final c in courses) {
      uniqueMap[c.id] = c;
    }
    final uniqueCourses = uniqueMap.values.toList();
    final courseIds = uniqueCourses.map((c) => c.id).toList();
    final coursesData = uniqueCourses.map((c) => c.toMap()).toList();
    final defaultRatings = {for (final c in uniqueCourses) c.id: 2};

    final updates = <String, dynamic>{
      'academicYear': academicYear,
      'semester': semester,
      'year': yearLabel,
      'term': semesterLabel,
      'isOnboarded': true,
      'onboardingCompleted': true,
      'selectedCourses': courseIds,
      'coursesData': coursesData,
      'courseRatings': defaultRatings,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final docRef = firestore.collection('users').doc(uid);
    await docRef.set(updates, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>?> getUserProfileStream() {
    final uid = currentUser?.uid;
    final firestore = _firestore;
    if (uid == null || firestore == null) {
      return Stream.value(null);
    }
    return firestore.collection('users').doc(uid).snapshots();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userProfileStreamProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  final auth = ref.watch(authServiceProvider);
  final user = authUser ?? auth.currentUser;
  if (user == null) return Stream.value(null);
  return auth.getUserProfileStream();
});
