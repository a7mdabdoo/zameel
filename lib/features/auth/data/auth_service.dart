// مطور 1
// خدمة المصادقة وحسابات المستخدمين عبر Firebase Auth & Cloud Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';

class AuthService {
  FirebaseAuth? get _auth {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? Stream.value(null);

  User? get currentUser => _auth?.currentUser;

  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) {
      throw FirebaseException(
        plugin: 'auth',
        message: 'Firebase is not initialized',
      );
    }

    final cred = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (cred.user != null) {
      await cred.user!.updateDisplayName(name.trim());
      try {
        await cred.user!.sendEmailVerification();
      } catch (_) {}

      // إنشاء مستند المستخدم الأولي برصيد ترحيبي (2 عملات وقت)
      await firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'name': name.trim(),
        'email': email.trim(),
        'timeCoins': AppConstants.welcomeCoins,
        'faculty': AppConstants.faculty,
        'year': AppConstants.academicYear,
        'selectedCourses': <String>[],
        'courseRatings': <String, dynamic>{},
        'onboardingCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return cred;
  }

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

    return await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth?.signOut();
  }

  Future<void> updateUserProfile({
    String? faculty,
    String? year,
    List<String>? selectedCourses,
    Map<String, int>? courseRatings,
    bool? onboardingCompleted,
  }) async {
    final uid = currentUser?.uid;
    final firestore = _firestore;
    if (uid == null || firestore == null) return;

    final updates = <String, dynamic>{};
    if (faculty != null) updates['faculty'] = faculty;
    if (year != null) updates['year'] = year;
    if (selectedCourses != null) updates['selectedCourses'] = selectedCourses;
    if (courseRatings != null) updates['courseRatings'] = courseRatings;
    if (onboardingCompleted != null) updates['onboardingCompleted'] = onboardingCompleted;

    await firestore.collection('users').doc(uid).update(updates);
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
  final auth = ref.watch(authServiceProvider);
  if (auth.currentUser == null) return Stream.value(null);
  return auth.getUserProfileStream();
});
