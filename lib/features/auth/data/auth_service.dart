// مطور 1
// خدمة المصادقة وحسابات المستخدمين عبر Firebase Auth & Cloud Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (cred.user != null) {
      await cred.user!.updateDisplayName(name.trim());
      // إنشاء مستند المستخدم الأولي برصيد 3 عملات وقت ترحيبية
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'name': name.trim(),
        'email': email.trim(),
        'timeCoins': 3,
        'faculty': 'كلية الحاسبات والذكاء الاصطناعي',
        'year': 'الفرقة الثانية',
        'selectedCourses': <String>[],
        'courseRatings': <String, dynamic>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return cred;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateUserProfile({
    String? faculty,
    String? year,
    List<String>? selectedCourses,
    Map<String, int>? courseRatings,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final updates = <String, dynamic>{};
    if (faculty != null) updates['faculty'] = faculty;
    if (year != null) updates['year'] = year;
    if (selectedCourses != null) updates['selectedCourses'] = selectedCourses;
    if (courseRatings != null) updates['courseRatings'] = courseRatings;

    await _firestore.collection('users').doc(uid).update(updates);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserProfileStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore.collection('users').doc(uid).snapshots();
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final userProfileStreamProvider = StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final auth = ref.watch(authServiceProvider);
  if (auth.currentUser == null) return Stream.value(null);
  return auth.getUserProfileStream();
});
