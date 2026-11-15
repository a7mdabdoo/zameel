/**
 * اختبارات قواعد أمان Cloud Firestore باستخدام @firebase/rules-unit-testing
 * تغطي:
 * 1. إثبات صد كافة الثغرات السابقة (Replay, Unbacked Booking, Zero Balance, Rating Forgery, Self-Release).
 * 2. التحقق من قفل الدفع التبادلي (Bidirectional Payment-Locking).
 * 3. اختبارات المعاملات متعددة المستندات (Multi-document Transactions) كما يستدعيها TimeBankRepository.
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

describe('قواعد أمان زَميل المحصنة - Zameel Hardened Security Rules', () => {
  let testEnv;

  beforeAll(async () => {
    const rules = fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8');
    testEnv = await initializeTestEnvironment({
      projectId: 'zameel-security-test',
      firestore: {
        rules: rules,
      },
    });
  });

  afterAll(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
    }
  });

  // =========================================================================
  // القسم الأول: اختبارات صد الثغرات والتلاعب بالعملات (Vulnerability Prevention)
  // =========================================================================

  test('ثغرة 1: منع المستخدم من تعديل timeCoins مباشرة دون معاملة جلسة مطابقة', async () => {
    const userId = 'student_ali';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        email: 'ali@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        timeCoins: 999,
      })
    );
  });

  test('ثغرة 2: منع حجز جلسة إذا كان رصيد المتعلم صفر (منع الرصيد السالب)', async () => {
    const learnerId = 'learner_broke';
    const teacherId = 'teacher_omar';
    const sessionId = 'session_zero_bal';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'broke@gmail.com',
        timeCoins: 0,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'omar@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    await assertFails(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(learnerId), {
          timeCoins: -1,
          lastSessionId: sessionId,
        });
        t.set(learnerDb.collection('sessions').doc(sessionId), {
          id: sessionId,
          learnerId: learnerId,
          teacherId: teacherId,
          costCoins: 1,
          escrowStatus: 'held',
          status: 'confirmed',
          scheduledAt: new Date(Date.now() + 86400000),
        });
      })
    );
  });

  test('ثغرة 3: منع إنشاء الجلسة دون خصم عملة من حساب المتعلم في نفس المعاملة (الحجز بلا خصم)', async () => {
    const learnerId = 'learner_cheat';
    const teacherId = 'teacher_omar';
    const sessionId = 'session_no_deduct';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'cheat@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // محاولة إنشاء الجلسة بمفردها دون خصم العملة من المستخدم
    await assertFails(
      learnerDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: new Date(Date.now() + 86400000),
      })
    );
  });

  test('ثغرة 4: منع المعلم من تحرير الضمان لنفسه دون تأكيد المتعلم', async () => {
    const learnerId = 'learner_user';
    const teacherId = 'teacher_hacker';
    const sessionId = 'session_self_release';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: new Date(Date.now() + 86400000),
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'hacker@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    await assertFails(
      teacherDb.collection('sessions').doc(sessionId).update({
        escrowStatus: 'released_to_teacher',
        status: 'completed',
      })
    );
  });

  test('ثغرة 5: منع هجوم التكرار (Replay Attack) لمحاولة زيادة الرصيد بجلسة محررة مسبقاً', async () => {
    const learnerId = 'learner_user';
    const teacherId = 'teacher_user';
    const sessionId = 'session_already_finished';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      // جلسة كانت قد أُطلقت للمعلم بالفعل
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'released_to_teacher',
        status: 'completed',
        scheduledAt: new Date(),
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'teacher@gmail.com',
        timeCoins: 3,
        completedSessions: 1,
        teacherRating: 5.0,
        lastSessionId: sessionId,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // محاولة تكرار إضافة عملة للمعلم بالاعتماد على الجلسة القديمة المنتهية
    await assertFails(
      learnerDb.collection('users').doc(teacherId).update({
        timeCoins: 4,
        completedSessions: 2,
        teacherRating: 5.0,
        lastSessionId: sessionId,
      })
    );
  });

  test('ثغرة 6: منع استرداد العملة للمتعلم إذا ألغى قبل الموعد بأقل من ساعتين', async () => {
    const learnerId = 'learner_late';
    const teacherId = 'teacher_user';
    const sessionId = 'session_late_cancel';

    // موعد الجلسة بعد 30 دقيقة فقط من الآن (< ساعتين)
    const sessionDate = new Date(Date.now() + 30 * 60 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: sessionDate,
      });
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'late@gmail.com',
        timeCoins: 1,
        completedSessions: 0,
        teacherRating: 0.0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // محاولة استرداد العملة للمتعلم بالرغم من أن الإلغاء متأخر
    await assertFails(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(learnerId), {
          timeCoins: 2,
          lastSessionId: sessionId,
        });
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          escrowStatus: 'refunded_to_learner',
          status: 'cancelled_by_learner',
          cancelledBy: learnerId,
        });
      })
    );
  });

  test('ثغرة 7: منع تزوير التقييم وعدد الجلسات عند إنشاء الحساب', async () => {
    const userId = 'fake_rater';
    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();

    // محاولة إنشاء حساب بتقييم أولي 5 وجلسات منتهية 10
    await assertFails(
      authedDb.collection('users').doc(userId).set({
        uid: userId,
        email: 'fake@gmail.com',
        timeCoins: 2,
        completedSessions: 10,
        teacherRating: 5.0,
      })
    );
  });

  test('ثغرة 8: منع إنشاء حركة محفظة دون ربطها بجلسة حقيقية وموثقة', async () => {
    const userId = 'student_anon';
    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();

    await assertFails(
      authedDb.collection('transactions').doc('tx_fake').set({
        id: 'tx_fake',
        userId: userId,
        amount: 1,
        isNegative: false,
        type: 'magic_gift',
      })
    );
  });

  test('ثغرة 9: فشل انتقال حالة الجلسة إلى completed دون زيادة رصيد المعلم بـ 1 في نفس المعاملة (قفل الدفع)', async () => {
    const learnerId = 'learner_user';
    const teacherId = 'teacher_user';
    const sessionId = 'session_unlocked_update';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'learner@gmail.com',
        timeCoins: 1,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'teacher@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: new Date(Date.now() + 86400000),
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // المتعلم يحاول تحديث الجلسة إلى منتهية ومحررة دون زيادة رصيد المعلم
    await assertFails(
      learnerDb.collection('sessions').doc(sessionId).update({
        status: 'completed',
        escrowStatus: 'released_to_teacher',
      })
    );
  });

  // =========================================================================
  // القسم الثاني: اختبارات المعاملات الحقيقية كما يستدعيها TimeBankRepository
  // =========================================================================

  test('معاملة ناجحة 1: حجز جلسة مع حجز العملة في الضمان (bookSessionWithEscrow)', async () => {
    const learnerId = 'learner_real';
    const teacherId = 'teacher_real';
    const sessionId = 'session_book_real_1';
    const txId = `${sessionId}_booking`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'learner@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'teacher@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // المعاملة الذرية لحجز الجلسة مطابقة لـ TimeBankRepository.bookSessionWithEscrow
    await assertSucceeds(
      learnerDb.runTransaction(async (t) => {
        // 1. خصم العملة من المتعلم
        t.update(learnerDb.collection('users').doc(learnerId), {
          timeCoins: 1,
          lastSessionId: sessionId,
        });

        // 2. إنشاء الجلسة بضمان معلّق (held)
        t.set(learnerDb.collection('sessions').doc(sessionId), {
          id: sessionId,
          learnerId: learnerId,
          teacherId: teacherId,
          courseName: 'الجبر الخطي',
          costCoins: 1,
          escrowStatus: 'held',
          status: 'confirmed',
          scheduledAt: new Date(Date.now() + 86400000),
        });

        // 3. قيد حركة المحفظة
        t.set(learnerDb.collection('transactions').doc(txId), {
          id: txId,
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          isNegative: true,
          type: 'booking',
        });
      })
    );
  });

  test('معاملة ناجحة 2: إتمام الجلسة وإطلاق الضمان للمعلم (completeSessionAndReleaseEscrow)', async () => {
    const learnerId = 'learner_real';
    const teacherId = 'teacher_real';
    const sessionId = 'session_complete_real_2';
    const txId = `${sessionId}_release`;
    const scheduledTime = new Date(Date.now() + 86400000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'learner@gmail.com',
        timeCoins: 1,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'teacher@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        courseName: 'قواعد البيانات',
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // المعاملة الذرية لإتمام الجلسة مطابقة لـ TimeBankRepository.completeSessionAndReleaseEscrow
    await assertSucceeds(
      learnerDb.runTransaction(async (t) => {
        // 1. زيادة رصيد المعلم وتحديث تقييمه
        t.update(learnerDb.collection('users').doc(teacherId), {
          timeCoins: 3,
          completedSessions: 1,
          ratingSum: 5,
          ratingCount: 1,
          lastSessionId: sessionId,
        });

        // 2. تحديث الجلسة لمنتهية وإطلاق الضمان
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          learnerId: learnerId,
          teacherId: teacherId,
          costCoins: 1,
          scheduledAt: scheduledTime,
          status: 'completed',
          escrowStatus: 'released_to_teacher',
          rating: 5,
          reviewComment: 'شرح متميز جداً',
        });

        // 3. قيد حركة المحفظة للمعلم
        t.set(learnerDb.collection('transactions').doc(txId), {
          id: txId,
          userId: teacherId,
          sessionId: sessionId,
          amount: 1,
          isNegative: false,
          type: 'release',
        });
      })
    );
  });

  test('معاملة ناجحة 3: إلغاء مبكر من المتعلم قبل الموعد بـ 24 ساعة واسترداد العملة (cancelSessionWithEscrow)', async () => {
    const learnerId = 'learner_real';
    const teacherId = 'teacher_real';
    const sessionId = 'session_early_cancel_3';
    const txId = `${sessionId}_refund`;
    const scheduledTime = new Date(Date.now() + 24 * 3600 * 1000); // بعد 24 ساعة (> ساعتين)

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'learner@gmail.com',
        timeCoins: 1,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'teacher@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    await assertSucceeds(
      learnerDb.runTransaction(async (t) => {
        // 1. إعادة العملة لرصيد المتعلم
        t.update(learnerDb.collection('users').doc(learnerId), {
          timeCoins: 2,
          lastSessionId: sessionId,
        });

        // 2. تحديث الجلسة إلى مستردة للمتعلم
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          learnerId: learnerId,
          teacherId: teacherId,
          costCoins: 1,
          scheduledAt: scheduledTime,
          status: 'cancelled_by_learner',
          escrowStatus: 'refunded_to_learner',
          cancellationReason: 'اعتذار مبكر لظرف طارئ',
          cancelledBy: learnerId,
        });

        // 3. قيد حركة الاسترداد
        t.set(learnerDb.collection('transactions').doc(txId), {
          id: txId,
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          isNegative: false,
          type: 'refund',
        });
      })
    );
  });

  test('معاملة ناجحة 4: إلغاء متأخر من المتعلم (< ساعتين) وتحويل العملة كتعويض للمعلم (cancelSessionWithEscrow)', async () => {
    const learnerId = 'learner_real';
    const teacherId = 'teacher_real';
    const sessionId = 'session_late_cancel_4';
    const txId = `${sessionId}_compensation`;
    const scheduledTime = new Date(Date.now() + 30 * 60 * 1000); // بعد 30 دقيقة (أقل من ساعتين)

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'learner@gmail.com',
        timeCoins: 1,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'teacher@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    await assertSucceeds(
      learnerDb.runTransaction(async (t) => {
        // 1. تعويض المعلم بالعملة
        t.update(learnerDb.collection('users').doc(teacherId), {
          timeCoins: 3,
          lastSessionId: sessionId,
        });

        // 2. تحديث الجلسة كملغاة مع إطلاق العملة للمعلم
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          learnerId: learnerId,
          teacherId: teacherId,
          costCoins: 1,
          scheduledAt: scheduledTime,
          status: 'cancelled_by_learner',
          escrowStatus: 'released_to_teacher',
          cancellationReason: 'إلغاء متأخر',
          cancelledBy: learnerId,
        });

        // 3. قيد حركة التعويض
        t.set(learnerDb.collection('transactions').doc(txId), {
          id: txId,
          userId: teacherId,
          sessionId: sessionId,
          amount: 1,
          isNegative: false,
          type: 'compensation',
        });
      })
    );
  });

  test('معاملة ناجحة 5: إلغاء الجلسة من المعلم في أي وقت واسترداد العملة للمتعلم (cancelSessionWithEscrow)', async () => {
    const learnerId = 'learner_real';
    const teacherId = 'teacher_real';
    const sessionId = 'session_teacher_cancel_5';
    const txId = `${sessionId}_refund`;
    const scheduledTime = new Date(Date.now() + 30 * 60 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'learner@gmail.com',
        timeCoins: 1,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'teacher@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    await assertSucceeds(
      teacherDb.runTransaction(async (t) => {
        // 1. إعادة العملة لرصيد المتعلم
        t.update(teacherDb.collection('users').doc(learnerId), {
          timeCoins: 2,
          lastSessionId: sessionId,
        });

        // 2. تحديث الجلسة إلى مستردة للمتعلم بسبب المعلم
        t.update(teacherDb.collection('sessions').doc(sessionId), {
          learnerId: learnerId,
          teacherId: teacherId,
          costCoins: 1,
          scheduledAt: scheduledTime,
          status: 'cancelled_by_teacher',
          escrowStatus: 'refunded_to_learner',
          cancellationReason: 'اعتذار المعلم لظرف طارئ',
          cancelledBy: teacherId,
        });

        // 3. قيد حركة الاسترداد للمتعلم
        t.set(teacherDb.collection('transactions').doc(txId), {
          id: txId,
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          isNegative: false,
          type: 'refund',
        });
      })
    );
  });

  test('تعديل الحساب الشخصي: نجاح المستخدم بتعديل اسمه وبياناته دون المساس بالرصيد أو الإحصائيات', async () => {
    const userId = 'student_ali';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        name: 'علي القديم',
        email: 'ali@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();

    // تعديل الاسم مسموح به
    await assertSucceeds(
      authedDb.collection('users').doc(userId).update({
        name: 'علي أحمد الجديد',
      })
    );
  });

  test('خصوصية المستخدمين 1: السماح بقراءة مستند مستخدم فردي ومنع سرد (list) كافة المستخدمين', async () => {
    const userId = 'target_user_1';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('users').doc(userId).set({
        uid: userId,
        name: 'طالب مستهدف',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
    });

    const authedDb = testEnv.authenticatedContext('any_auth_user', { email_verified: true }).firestore();

    // قراءة مستند مفرد (get) مسموحة
    await assertSucceeds(
      authedDb.collection('users').doc(userId).get()
    );

    // سرد كل المستخدمين (list) ممنوع لحماية الخصوصية ومنع سحب البيانات
    await assertFails(
      authedDb.collection('users').get()
    );
  });

  test('خصوصية المستخدمين 2: نجاح إنشاء حساب مستخدم بدون تخزين الإيميل في Firestore', async () => {
    const newUid = 'fresh_signup_uid';
    const newDb = testEnv.authenticatedContext(newUid, { email_verified: false }).firestore();

    await assertSucceeds(
      newDb.collection('users').doc(newUid).set({
        uid: newUid,
        name: 'طالب جديد',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      })
    );
  });

  test('أسماء المستخدمين (موقوفة): منع أي قراءة أو كتابة على مجموعة usernames المحذوفة', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    const authedDb = testEnv.authenticatedContext('student_ali', { email_verified: true }).firestore();

    await assertFails(
      unauthedDb.collection('usernames').doc('ali_coder').get()
    );

    await assertFails(
      authedDb.collection('usernames').doc('ali_coder').set({
        uid: 'student_ali',
        email: 'ali@gmail.com',
      })
    );
  });

  // =========================================================================
  // القسم السادس: أمان محادثات ورسائل الجلسات (Session Messages Security)
  // =========================================================================

  test('رسائل الجلسة 1: نجاح قراءة وإنشاء رسالة من أطراف الجلسة (المتعلم والمعلم)', async () => {
    const sessionId = 'session_msg_test_1';
    const learnerId = 'learner_msg_1';
    const teacherId = 'teacher_msg_1';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        status: 'confirmed',
        escrowStatus: 'held',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    // المتعلم يرسل رسالة
    await assertSucceeds(
      learnerDb.collection('sessions').doc(sessionId).collection('messages').doc('msg_1').set({
        senderId: learnerId,
        senderName: 'Learner',
        text: 'أهلاً يا باشمهندس، ميعادنا تمام؟',
        createdAt: new Date().toISOString(),
      })
    );

    // المعلم يستطيع قراءة الرسالة
    await assertSucceeds(
      teacherDb.collection('sessions').doc(sessionId).collection('messages').doc('msg_1').get()
    );

    // المعلم يرد برسالة
    await assertSucceeds(
      teacherDb.collection('sessions').doc(sessionId).collection('messages').doc('msg_2').set({
        senderId: teacherId,
        senderName: 'Teacher',
        text: 'تمام جداً وفي انتظارك في قاعة الاستذكار',
        createdAt: new Date().toISOString(),
      })
    );
  });

  test('رسائل الجلسة 2: منع طرف ثالث غريب من قراءة أو كتابة رسائل الجلسة', async () => {
    const sessionId = 'session_msg_test_2';
    const learnerId = 'learner_msg_2';
    const teacherId = 'teacher_msg_2';
    const outsiderId = 'outsider_user';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        status: 'confirmed',
        escrowStatus: 'held',
      });
      await adminDb.collection('sessions').doc(sessionId).collection('messages').doc('secret_msg').set({
        senderId: learnerId,
        senderName: 'Learner',
        text: 'سر بيننا',
        createdAt: new Date().toISOString(),
      });
    });

    const outsiderDb = testEnv.authenticatedContext(outsiderId, { email_verified: true }).firestore();

    // محاولة الغريب قراءة الرسالة
    await assertFails(
      outsiderDb.collection('sessions').doc(sessionId).collection('messages').doc('secret_msg').get()
    );

    // محاولة الغريب إرسال رسالة في الجلسة
    await assertFails(
      outsiderDb.collection('sessions').doc(sessionId).collection('messages').doc('hacked_msg').set({
        senderId: outsiderId,
        senderName: 'Outsider',
        text: 'رسالة غير مصرح بها',
        createdAt: new Date().toISOString(),
      })
    );
  });

  test('رسائل الجلسة 3: منع تزوير senderId، منع النصوص الفارغة أو الطويلة جداً، ومنع التعديل والحذف', async () => {
    const sessionId = 'session_msg_test_3';
    const learnerId = 'learner_msg_3';
    const teacherId = 'teacher_msg_3';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        status: 'confirmed',
        escrowStatus: 'held',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // تزوير senderId
    await assertFails(
      learnerDb.collection('sessions').doc(sessionId).collection('messages').doc('fake_sender').set({
        senderId: teacherId, // ينتحل شخصية المعلم
        senderName: 'Fake Teacher',
        text: 'أنا المعلم',
        createdAt: new Date().toISOString(),
      })
    );

    // نص فارغ
    await assertFails(
      learnerDb.collection('sessions').doc(sessionId).collection('messages').doc('empty_text').set({
        senderId: learnerId,
        senderName: 'Learner',
        text: '',
        createdAt: new Date().toISOString(),
      })
    );

    // نص يتجاوز 1000 حرف
    await assertFails(
      learnerDb.collection('sessions').doc(sessionId).collection('messages').doc('huge_text').set({
        senderId: learnerId,
        senderName: 'Learner',
        text: 'a'.repeat(1001),
        createdAt: new Date().toISOString(),
      })
    );

    // منع الحذف والتعديل
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().collection('sessions').doc(sessionId).collection('messages').doc('msg_immutable').set({
        senderId: learnerId,
        senderName: 'Learner',
        text: 'رسالة أصلية',
        createdAt: new Date().toISOString(),
      });
    });

    await assertFails(
      learnerDb.collection('sessions').doc(sessionId).collection('messages').doc('msg_immutable').update({
        text: 'رسالة معدلة',
      })
    );

    await assertFails(
      learnerDb.collection('sessions').doc(sessionId).collection('messages').doc('msg_immutable').delete()
    );
  });

  test('رسائل الجلسة 4: منع القراءة والكتابة في مجموعة messages العامة في الجذر', async () => {
    const authedDb = testEnv.authenticatedContext('any_user', { email_verified: true }).firestore();

    await assertFails(
      authedDb.collection('messages').doc('any_msg').get()
    );

    await assertFails(
      authedDb.collection('messages').doc('any_msg').set({
        text: 'hello',
      })
    );
  });

  // =========================================================================
  // القسم السابع: اشتراط تأكيد البريد الإلكتروني (Email Verification Tests)
  // =========================================================================

  test('تأكيد البريد 1: المستخدم غير المؤكد يفشل في نشر عرض شرح، والمؤكد ينجح', async () => {
    const unverifiedUid = 'unverified_teacher';
    const verifiedUid = 'verified_teacher';

    const unverifiedDb = testEnv.authenticatedContext(unverifiedUid, { email_verified: false }).firestore();
    const verifiedDb = testEnv.authenticatedContext(verifiedUid, { email_verified: true }).firestore();

    const offerData = (uid) => ({
      teacherId: uid,
      teacherName: 'Teacher',
      courseId: 'cs201',
      courseName: 'OOP',
      courseCode: 'CS201',
      topic: 'Classes',
      day: 'الأحد',
      time: '12:00 م',
      durationMinutes: 60,
      location: 'مكتبة',
      slots: [{ weekday: 1, startMin: 600, endMin: 720 }],
      isAvailable: true,
    });

    // غير المؤكد يفشل
    await assertFails(
      unverifiedDb.collection('offers').doc('offer_unver').set(offerData(unverifiedUid))
    );

    // المؤكد ينجح
    await assertSucceeds(
      verifiedDb.collection('offers').doc('offer_ver').set(offerData(verifiedUid))
    );
  });

  test('تأكيد البريد 2: المستخدم غير المؤكد يفشل في إرسال رسالة في الجلسة، والمؤكد ينجح', async () => {
    const sessionId = 'session_verify_chat';
    const unverifiedLearner = 'unverified_learner_chat';
    const verifiedLearner = 'verified_learner_chat';
    const teacherId = 'teacher_chat';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: unverifiedLearner,
        teacherId: teacherId,
        costCoins: 1,
        status: 'confirmed',
        escrowStatus: 'held',
      });
      await adminDb.collection('sessions').doc('session_verify_chat_2').set({
        learnerId: verifiedLearner,
        teacherId: teacherId,
        costCoins: 1,
        status: 'confirmed',
        escrowStatus: 'held',
      });
    });

    const unverifiedDb = testEnv.authenticatedContext(unverifiedLearner, { email_verified: false }).firestore();
    const verifiedDb = testEnv.authenticatedContext(verifiedLearner, { email_verified: true }).firestore();

    // غير المؤكد يفشل
    await assertFails(
      unverifiedDb.collection('sessions').doc(sessionId).collection('messages').doc('msg_fail').set({
        senderId: unverifiedLearner,
        senderName: 'Learner',
        text: 'رسالة من بريد غير مؤكد',
        createdAt: new Date().toISOString(),
      })
    );

    // المؤكد ينجح
    await assertSucceeds(
      verifiedDb.collection('sessions').doc('session_verify_chat_2').collection('messages').doc('msg_pass').set({
        senderId: verifiedLearner,
        senderName: 'Learner',
        text: 'رسالة من بريد مؤكد',
        createdAt: new Date().toISOString(),
      })
    );
  });

  // =========================================================================
  // القسم الثامن: نزاهة نظام التقييم (Rating Integrity Tests)
  // =========================================================================

  test('نزاهة التقييم 1: منع حجز جلسة بقيمة تقييم ابتدائية (rating must be null at booking)', async () => {
    const learnerId = 'learner_rating_book';
    const teacherId = 'teacher_rating_book';
    const sessionId = 'session_rating_book_1';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        timeCoins: 2,
        completedSessions: 0,
        ratingSum: 0,
        ratingCount: 0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        timeCoins: 2,
        completedSessions: 0,
        ratingSum: 0,
        ratingCount: 0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // محاولة حجز جلسة مع إرسال rating = 5 تفشل
    await assertFails(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(learnerId), {
          timeCoins: 1,
          lastSessionId: sessionId,
        });
        t.set(learnerDb.collection('sessions').doc(sessionId), {
          id: sessionId,
          learnerId: learnerId,
          teacherId: teacherId,
          costCoins: 1,
          status: 'confirmed',
          escrowStatus: 'held',
          rating: 5,
          scheduledAt: new Date(Date.now() + 86400000),
        });
        t.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
          id: `${sessionId}_booking`,
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          isNegative: true,
          type: 'booking',
        });
      })
    );

    // الحجز بدون تقييم (rating: null أو غير موجود) ينجح
    await assertSucceeds(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(learnerId), {
          timeCoins: 1,
          lastSessionId: sessionId,
        });
        t.set(learnerDb.collection('sessions').doc(sessionId), {
          id: sessionId,
          learnerId: learnerId,
          teacherId: teacherId,
          costCoins: 1,
          status: 'confirmed',
          escrowStatus: 'held',
          rating: null,
          scheduledAt: new Date(Date.now() + 86400000),
        });
        t.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
          id: `${sessionId}_booking`,
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          isNegative: true,
          type: 'booking',
        });
      })
    );
  });

  test('نزاهة التقييم 2: عند إتمام الجلسة يزيد ratingCount بـ 1 و ratingSum بقيمة التقييم بدقة', async () => {
    const learnerId = 'learner_rating_comp';
    const teacherId = 'teacher_rating_comp';
    const sessionId = 'session_rating_comp_1';
    const txId = `${sessionId}_release`;
    const scheduledTime = new Date(Date.now() + 2 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        timeCoins: 1,
        completedSessions: 0,
        ratingSum: 0,
        ratingCount: 0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        timeCoins: 2,
        completedSessions: 1,
        ratingSum: 5,
        ratingCount: 1,
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // تقييم 4 نجوم: يجب أن يصبح ratingSum = 5 + 4 = 9 و ratingCount = 1 + 1 = 2
    await assertSucceeds(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(teacherId), {
          timeCoins: 3,
          completedSessions: 2,
          ratingSum: 9,
          ratingCount: 2,
          lastSessionId: sessionId,
        });
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          learnerId: learnerId,
          teacherId: teacherId,
          costCoins: 1,
          scheduledAt: scheduledTime,
          status: 'completed',
          escrowStatus: 'released_to_teacher',
          rating: 4,
          reviewComment: 'شرح ممتاز',
        });
        t.set(learnerDb.collection('transactions').doc(txId), {
          id: txId,
          userId: teacherId,
          sessionId: sessionId,
          amount: 1,
          isNegative: false,
          type: 'release',
        });
      })
    );
  });

  test('نزاهة التقييم 3: فشل المعاملة إذا تلاعب العميل بمجموع التقييم (ratingSum mismatch)', async () => {
    const learnerId = 'learner_rating_cheat';
    const teacherId = 'teacher_rating_cheat';
    const sessionId = 'session_rating_cheat_1';
    const txId = `${sessionId}_release`;
    const scheduledTime = new Date(Date.now() + 2 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        timeCoins: 1,
        completedSessions: 0,
        ratingSum: 0,
        ratingCount: 0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        timeCoins: 2,
        completedSessions: 0,
        ratingSum: 0,
        ratingCount: 0,
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // التقييم في الجلسة هو 3 ولكن العميل يحاول إضافة 5 إلى ratingSum
    await assertFails(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(teacherId), {
          timeCoins: 3,
          completedSessions: 1,
          ratingSum: 5, // غير مطابق للجلسة (3)
          ratingCount: 1,
          lastSessionId: sessionId,
        });
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          learnerId: learnerId,
          teacherId: teacherId,
          costCoins: 1,
          scheduledAt: scheduledTime,
          status: 'completed',
          escrowStatus: 'released_to_teacher',
          rating: 3,
          reviewComment: 'جيد',
        });
        t.set(learnerDb.collection('transactions').doc(txId), {
          id: txId,
          userId: teacherId,
          sessionId: sessionId,
          amount: 1,
          isNegative: false,
          type: 'release',
        });
      })
    );
  });

  test('نزاهة التقييم 4: منع أي مستخدم من تعديل تقييمه التراكمي ratingSum / ratingCount مباشرة', async () => {
    const userId = 'user_self_rate';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        timeCoins: 2,
        completedSessions: 0,
        ratingSum: 0,
        ratingCount: 0,
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();

    // محاولة تزوير التقييم
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        ratingSum: 50,
        ratingCount: 10,
      })
    );
  });

  // =========================================================================
  // القسم التاسع: نزاهة دفتر الأستاذ المحاسبي (Ledger Integrity Tests)
  // =========================================================================

  test('نزاهة دفتر الأستاذ 1: رفض قيد الحركة إذا لم يكن المعرف حتمياً ومطابقاً لـ ${sessionId}_${kind}', async () => {
    const learnerId = 'ledger_learner_1';
    const teacherId = 'ledger_teacher_1';
    const sessionId = 'session_ledger_1';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        timeCoins: 2,
        completedSessions: 0,
        ratingSum: 0,
        ratingCount: 0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        timeCoins: 2,
        completedSessions: 0,
        ratingSum: 0,
        ratingCount: 0,
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        status: 'confirmed',
        escrowStatus: 'held',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // معرف عشوائي tx_12345 بدلاً من session_ledger_1_booking -> يفشل
    await assertFails(
      learnerDb.collection('transactions').doc('tx_random_12345').set({
        id: 'tx_random_12345',
        userId: learnerId,
        sessionId: sessionId,
        amount: 1,
        isNegative: true,
        type: 'booking',
      })
    );
  });

  test('نزاهة دفتر الأستاذ 2: رفض تكرار إنشاء قيد المعاملة إذا كان موجوداً مسبقاً (!exists)', async () => {
    const learnerId = 'ledger_learner_2';
    const teacherId = 'ledger_teacher_2';
    const sessionId = 'session_ledger_2';
    const txId = `${sessionId}_booking`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        timeCoins: 2,
        completedSessions: 0,
        ratingSum: 0,
        ratingCount: 0,
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        status: 'confirmed',
        escrowStatus: 'held',
      });
      // قيد موجود بالفعل في قاعدة البيانات
      await adminDb.collection('transactions').doc(txId).set({
        id: txId,
        userId: learnerId,
        sessionId: sessionId,
        amount: 1,
        isNegative: true,
        type: 'booking',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // محاولة إعادة إنشاء نفس المعاملة الموجودة مسبقاً -> تفشل
    await assertFails(
      learnerDb.collection('transactions').doc(txId).set({
        id: txId,
        userId: learnerId,
        sessionId: sessionId,
        amount: 1,
        isNegative: true,
        type: 'booking',
      })
    );
  });

  test('نزاهة دفتر الأستاذ 3: رفض قيد الحركة إذا لم يطابق userId انتقال الجلسة (booking ينسب لغير المتعلم)', async () => {
    const learnerId = 'ledger_learner_3';
    const teacherId = 'ledger_teacher_3';
    const sessionId = 'session_ledger_3';
    const txId = `${sessionId}_booking`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        status: 'confirmed',
        escrowStatus: 'held',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // حركة booking ولكن منسوبة للمعلم بدلاً من المتعلم -> تفشل
    await assertFails(
      learnerDb.collection('transactions').doc(txId).set({
        id: txId,
        userId: teacherId, // غير مطابق لـ session.learnerId
        sessionId: sessionId,
        amount: 1,
        isNegative: true,
        type: 'booking',
      })
    );
  });

  test('نزاهة دفتر الأستاذ 4: رفض قيد الحركة إذا لم يطابق amount تكلفة الجلسة costCoins', async () => {
    const learnerId = 'ledger_learner_4';
    const teacherId = 'ledger_teacher_4';
    const sessionId = 'session_ledger_4';
    const txId = `${sessionId}_booking`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        status: 'confirmed',
        escrowStatus: 'held',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // amount: 2 بينما costCoins = 1 -> تفشل
    await assertFails(
      learnerDb.collection('transactions').doc(txId).set({
        id: txId,
        userId: learnerId,
        sessionId: sessionId,
        amount: 2,
        isNegative: true,
        type: 'booking',
      })
    );
  });

  test('نزاهة دفتر الأستاذ 5: حظر تعديل أو حذف أي قيد في دفتر الأستاذ (Immutable Ledger)', async () => {
    const userId = 'ledger_user_5';
    const txId = 'session_immut_booking';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('transactions').doc(txId).set({
        id: txId,
        userId: userId,
        sessionId: 'session_immut',
        amount: 1,
        isNegative: true,
        type: 'booking',
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();

    // تعديل القيد مرفوض
    await assertFails(
      authedDb.collection('transactions').doc(txId).update({
        amount: 0,
      })
    );

    // حذف القيد مرفوض
    await assertFails(
      authedDb.collection('transactions').doc(txId).delete()
    );
  });

  // =========================================================================
  // القسم العاشر: قواعد عروض الشرح (Offers Rules Tests)
  // =========================================================================

  test('قواعد العروض 1: نجاح إنشاء عرض شرح وتحديثه مع durationMinutes في {30, 60}', async () => {
    const teacherId = 'offer_teacher_valid';
    const offerId = 'offer_valid_1';
    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    const offerData = {
      teacherId: teacherId,
      teacherName: 'أحمد',
      courseId: 'math101',
      courseName: 'تفاضل وتكامل',
      courseCode: 'MATH101',
      topic: 'قواعد الاشتقاق',
      day: 'الاثنين',
      time: '01:00 ظهراً',
      durationMinutes: 30,
      location: 'مكتبة الكلية',
      slots: [{ weekday: 2, startMin: 780, endMin: 840 }],
      isAvailable: true,
    };

    // إنشاء بنجاح
    await assertSucceeds(
      teacherDb.collection('offers').doc(offerId).set(offerData)
    );

    // تحديث بنجاح مع تغيير المدة إلى 60
    await assertSucceeds(
      teacherDb.collection('offers').doc(offerId).update({
        durationMinutes: 60,
        topic: 'تطبيقات على القيم العظمى',
      })
    );
  });

  test('قواعد العروض 2: حظر تعديل teacherId عند تحديث العرض (teacherId is immutable)', async () => {
    const teacherId = 'offer_teacher_orig';
    const offerId = 'offer_immutable_teacher';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('offers').doc(offerId).set({
        teacherId: teacherId,
        teacherName: 'المعلم الأصلي',
        courseId: 'cs101',
        courseName: 'برمجة 1',
        courseCode: 'CS101',
        topic: 'المصفوفات',
        day: 'الثلاثاء',
        time: '02:00 م',
        durationMinutes: 60,
        location: 'معمل الحاسب',
        slots: [{ weekday: 3, startMin: 840, endMin: 900 }],
        isAvailable: true,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    // محاولة تغيير teacherId لشخص آخر تفشل
    await assertFails(
      teacherDb.collection('offers').doc(offerId).update({
        teacherId: 'hacker_teacher',
      })
    );
  });

  test('قواعد العروض 3: رفض إنشاء عرض بمدة غير مقبولة (durationMinutes not in {30, 60})', async () => {
    const teacherId = 'offer_teacher_duration';
    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    const invalidOffer = {
      teacherId: teacherId,
      teacherName: 'معلم',
      courseId: 'cs102',
      courseName: 'هياكل بيانات',
      courseCode: 'CS102',
      topic: 'الأشجار',
      day: 'الأربعاء',
      time: '11:00 ص',
      durationMinutes: 45, // غير مسموح
      location: 'مكتبة',
      slots: [{ weekday: 4, startMin: 660, endMin: 720 }],
      isAvailable: true,
    };

    await assertFails(
      teacherDb.collection('offers').doc('offer_invalid_dur').set(invalidOffer)
    );
  });

  test('قواعد العروض 4: رفض إنشاء عرض بحقول مطلوبة ناقصة أو فارغة', async () => {
    const teacherId = 'offer_teacher_missing';
    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    const missingTopicOffer = {
      teacherId: teacherId,
      teacherName: 'معلم',
      courseId: 'cs103',
      courseName: 'قواعد بيانات',
      courseCode: 'CS103',
      topic: '', // فارغ
      day: 'الخميس',
      time: '12:00 م',
      durationMinutes: 60,
      location: 'مكتبة',
      slots: [{ weekday: 5, startMin: 720, endMin: 780 }],
      isAvailable: true,
    };

    await assertFails(
      teacherDb.collection('offers').doc('offer_missing_topic').set(missingTopicOffer)
    );
  });

  test('قواعد العروض 5: حظر تخزين رابط الاجتماع في عروض الشرح (No meeting link in offers)', async () => {
    const teacherId = 'offer_teacher_link';
    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    // محاولة إرفاق meetingUrl في العرض العام تفشل
    await assertFails(
      teacherDb.collection('offers').doc('offer_with_link').set({
        teacherId: teacherId,
        teacherName: 'معلم',
        courseId: 'cs104',
        courseName: 'شبكات',
        courseCode: 'CS104',
        topic: 'بروتوكولات',
        day: 'الأحد',
        time: '10:00 ص',
        durationMinutes: 60,
        location: 'أونلاين',
        slots: [{ weekday: 1, startMin: 600, endMin: 720 }],
        meetingUrl: 'https://meet.google.com/abc-defg-hij',
        isAvailable: true,
      })
    );
  });

  test('قواعد العروض 6: التحقق من فترات الإتاحة slots - إنشاء عرض بـ slots صالحة ينجح', async () => {
    const teacherId = 'offer_teacher_slots_ok';
    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    const validOfferWithSlots = {
      teacherId: teacherId,
      teacherName: 'معلم السلوتس',
      courseId: 'cs201',
      courseName: 'برمجة كائنية',
      courseCode: 'CS201',
      topic: 'الوراثة والتعددية',
      durationMinutes: 60,
      location: 'المكتبة المركزية',
      slots: [
        { weekday: 0, startMin: 600, endMin: 720 }, // السبت 10:00 - 12:00
        { weekday: 1, startMin: 780, endMin: 900 }, // الأحد 13:00 - 15:00
      ],
      isAvailable: true,
    };

    await assertSucceeds(
      teacherDb.collection('offers').doc('offer_slots_ok').set(validOfferWithSlots)
    );
  });

  test('قواعد العروض 7: التحقق من فترات الإتاحة slots - إنشاء عرض بدون slots أو بقائمة فارغة يفشل', async () => {
    const teacherId = 'offer_teacher_no_slots';
    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    // 1. بدون slots
    await assertFails(
      teacherDb.collection('offers').doc('offer_no_slots').set({
        teacherId: teacherId,
        teacherName: 'معلم',
        courseId: 'cs201',
        courseName: 'برمجة كائنية',
        courseCode: 'CS201',
        topic: 'شرح موضوع',
        durationMinutes: 60,
        location: 'معمل',
        isAvailable: true,
      })
    );

    // 2. مع slots فارغة
    await assertFails(
      teacherDb.collection('offers').doc('offer_empty_slots').set({
        teacherId: teacherId,
        teacherName: 'معلم',
        courseId: 'cs201',
        courseName: 'برمجة كائنية',
        courseCode: 'CS201',
        topic: 'شرح موضوع',
        durationMinutes: 60,
        location: 'معمل',
        slots: [],
        isAvailable: true,
      })
    );
  });

  test('قواعد العروض 8: التحقق من فترات الإتاحة slots - إنشاء عرض بـ weekday خارج 0-6 أو endMin <= startMin يفشل', async () => {
    const teacherId = 'offer_teacher_bad_slots';
    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    // 1. weekday = 7 (خارج 0-6)
    await assertFails(
      teacherDb.collection('offers').doc('offer_bad_weekday').set({
        teacherId: teacherId,
        teacherName: 'معلم',
        courseId: 'cs201',
        courseName: 'برمجة كائنية',
        courseCode: 'CS201',
        topic: 'شرح موضوع',
        durationMinutes: 60,
        location: 'معمل',
        slots: [{ weekday: 7, startMin: 600, endMin: 720 }],
        isAvailable: true,
      })
    );

    // 2. endMin <= startMin
    await assertFails(
      teacherDb.collection('offers').doc('offer_bad_times').set({
        teacherId: teacherId,
        teacherName: 'معلم',
        courseId: 'cs201',
        courseName: 'برمجة كائنية',
        courseCode: 'CS201',
        topic: 'شرح موضوع',
        durationMinutes: 60,
        location: 'معمل',
        slots: [{ weekday: 1, startMin: 720, endMin: 600 }],
        isAvailable: true,
      })
    );
  });

  // =========================================================================
  // القسم الحادي عشر: خصوصية رابط الاجتماع وتحديثه (Meeting Link Privacy Tests)
  // =========================================================================

  test('خصوصية رابط الاجتماع 1: المعلم يمكنه تحديث رابط الاجتماع في جلسة نشطة ومعلقة بالضمان (Google Meet)', async () => {
    const sessionId = 'session_meeting_valid_1';
    const learnerId = 'learner_meeting_1';
    const teacherId = 'teacher_meeting_1';
    const scheduledTime = new Date(Date.now() + 86400000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        mode: 'online',
        location: 'عبر الإنترنت (أونلاين)',
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    // المعلم يضيف رابط Google Meet صالح
    await assertSucceeds(
      teacherDb.collection('sessions').doc(sessionId).update({
        meetingUrl: 'https://meet.google.com/abc-defg-hij',
        meetingUpdatedAt: new Date().toISOString(),
      })
    );
  });

  test('خصوصية رابط الاجتماع 2: المعلم يمكنه تحديث رابط الاجتماع برابط Zoom أو MS Teams', async () => {
    const sessionId = 'session_meeting_zoom_1';
    const learnerId = 'learner_meeting_2';
    const teacherId = 'teacher_meeting_2';
    const scheduledTime = new Date(Date.now() + 86400000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        mode: 'online',
        location: 'عبر الإنترنت (أونلاين)',
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    // رابط Zoom صالح
    await assertSucceeds(
      teacherDb.collection('sessions').doc(sessionId).update({
        meetingUrl: 'https://us04web.zoom.us/j/1234567890?pwd=test',
        meetingUpdatedAt: new Date().toISOString(),
      })
    );
  });

  test('خصوصية رابط الاجتماع 3: المتعلم أو مستخدم غريب لا يمكنه تعديل رابط الاجتماع', async () => {
    const sessionId = 'session_meeting_learner_block';
    const learnerId = 'learner_meeting_3';
    const teacherId = 'teacher_meeting_3';
    const outsiderId = 'outsider_meeting_3';
    const scheduledTime = new Date(Date.now() + 86400000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        mode: 'online',
        location: 'عبر الإنترنت (أونلاين)',
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const outsiderDb = testEnv.authenticatedContext(outsiderId, { email_verified: true }).firestore();

    // المتعلم يفشل
    await assertFails(
      learnerDb.collection('sessions').doc(sessionId).update({
        meetingUrl: 'https://meet.google.com/xyz-hack-fake',
      })
    );

    // المستخدم الغريب يفشل
    await assertFails(
      outsiderDb.collection('sessions').doc(sessionId).update({
        meetingUrl: 'https://meet.google.com/xyz-hack-fake',
      })
    );
  });

  test('خصوصية رابط الاجتماع 4: رفض الروابط بنطاقات خبيثة أو غير مسموحة أو بدون https', async () => {
    const sessionId = 'session_meeting_malicious';
    const learnerId = 'learner_meeting_4';
    const teacherId = 'teacher_meeting_4';
    const scheduledTime = new Date(Date.now() + 86400000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        mode: 'online',
        location: 'عبر الإنترنت (أونلاين)',
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    // بدون https
    await assertFails(
      teacherDb.collection('sessions').doc(sessionId).update({
        meetingUrl: 'http://meet.google.com/xyz-1234',
      })
    );

    // نطاق خبيث
    await assertFails(
      teacherDb.collection('sessions').doc(sessionId).update({
        meetingUrl: 'https://phishing-site.com/fake-meet',
      })
    );
  });

  test('خصوصية رابط الاجتماع 5: المعلم لا يمكنه التلاعب بحالة الجلسة أو المبالغ أثناء تعديل الرابط', async () => {
    const sessionId = 'session_meeting_cheat';
    const learnerId = 'learner_meeting_5';
    const teacherId = 'teacher_meeting_5';
    const scheduledTime = new Date(Date.now() + 86400000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        mode: 'online',
        location: 'عبر الإنترنت (أونلاين)',
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledTime,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    // محاولة تغيير status إلى completed تزامناً مع meetingUrl
    await assertFails(
      teacherDb.collection('sessions').doc(sessionId).update({
        meetingUrl: 'https://meet.google.com/valid-meeting-link',
        status: 'completed',
      })
    );
  });

  // =========================================================================
  // القسم الثاني عشر: الحجز بموعد محدد نافذة 2 ساعة إلى 14 يوماً (Concrete Slot Window Tests)
  // =========================================================================

  test('حجز بموعد محدد 1: إنشاء جلسة بموعد مستقبلي محدد (24 ساعة قادمة) ينجح', async () => {
    const learnerId = 'learner_concrete_ok';
    const teacherId = 'teacher_concrete_ok';
    const sessionId = 'session_concrete_ok';
    const validScheduledAt = new Date(Date.now() + 24 * 3600 * 1000); // 24 ساعة

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        timeCoins: 2,
        completedSessions: 0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const batch = learnerDb.batch();

    batch.update(learnerDb.collection('users').doc(learnerId), {
      timeCoins: 1,
      lastSessionId: sessionId,
    });

    batch.set(learnerDb.collection('sessions').doc(sessionId), {
      learnerId: learnerId,
      teacherId: teacherId,
      costCoins: 1,
      escrowStatus: 'held',
      status: 'confirmed',
      scheduledAt: validScheduledAt,
    });

    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'booking',
    });

    await assertSucceeds(batch.commit());
  });

  test('حجز بموعد محدد 2: رفض إنشاء جلسة بموعد أقل من ساعتين قادمة (scheduledAt < 2 hours)', async () => {
    const learnerId = 'learner_concrete_too_soon';
    const teacherId = 'teacher_concrete_too_soon';
    const sessionId = 'session_concrete_too_soon';
    const tooSoonScheduledAt = new Date(Date.now() + 30 * 60 * 1000); // نصف ساعة فقط

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        timeCoins: 2,
        completedSessions: 0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const batch = learnerDb.batch();

    batch.update(learnerDb.collection('users').doc(learnerId), {
      timeCoins: 1,
      lastSessionId: sessionId,
    });

    batch.set(learnerDb.collection('sessions').doc(sessionId), {
      learnerId: learnerId,
      teacherId: teacherId,
      costCoins: 1,
      escrowStatus: 'held',
      status: 'confirmed',
      scheduledAt: tooSoonScheduledAt,
    });

    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'booking',
    });

    await assertFails(batch.commit());
  });

  test('حجز بموعد محدد 3: رفض إنشاء جلسة بموعد أبعد من 15 يوماً (scheduledAt > 15 days)', async () => {
    const learnerId = 'learner_concrete_too_far';
    const teacherId = 'teacher_concrete_too_far';
    const sessionId = 'session_concrete_too_far';
    const tooFarScheduledAt = new Date(Date.now() + 20 * 24 * 3600 * 1000); // 20 يوماً

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        timeCoins: 2,
        completedSessions: 0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const batch = learnerDb.batch();

    batch.update(learnerDb.collection('users').doc(learnerId), {
      timeCoins: 1,
      lastSessionId: sessionId,
    });

    batch.set(learnerDb.collection('sessions').doc(sessionId), {
      learnerId: learnerId,
      teacherId: teacherId,
      costCoins: 1,
      escrowStatus: 'held',
      status: 'confirmed',
      scheduledAt: tooFarScheduledAt,
    });

    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'booking',
    });

    await assertFails(batch.commit());
  });

  // =========================================================================
  // أقفال المواعيد وحظر الحجز المزدوج (Double Booking & Slot Locks)
  // =========================================================================
  test('أقفال المواعيد 1: إنشاء قفل موعد بالتزامن مع إنشاء جلسة ينجح', async () => {
    const learnerId = 'learner_lock_ok';
    const teacherId = 'teacher_lock_ok';
    const sessionId = 'session_lock_ok';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);
    const epochMs = scheduledAt.getTime();
    const learnerLockId = `${learnerId}_${epochMs}`;
    const teacherLockId = `${teacherId}_${epochMs}`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        timeCoins: 2,
        completedSessions: 0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const batch = learnerDb.batch();

    batch.update(learnerDb.collection('users').doc(learnerId), {
      timeCoins: 1,
      lastSessionId: sessionId,
    });

    batch.set(learnerDb.collection('sessions').doc(sessionId), {
      learnerId: learnerId,
      teacherId: teacherId,
      costCoins: 1,
      escrowStatus: 'held',
      status: 'confirmed',
      scheduledAt: scheduledAt,
    });

    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'booking',
    });

    batch.set(learnerDb.collection('slotLocks').doc(learnerLockId), {
      uid: learnerId,
      slotEpochMs: epochMs,
      sessionId: sessionId,
      status: 'active',
    });

    batch.set(learnerDb.collection('slotLocks').doc(teacherLockId), {
      uid: teacherId,
      slotEpochMs: epochMs,
      sessionId: sessionId,
      status: 'active',
    });

    await assertSucceeds(batch.commit());
  });

  test('أقفال المواعيد 2: رفض إنشاء قفل موعد منفرد بدون وجود جلسة (existsAfter violation)', async () => {
    const learnerId = 'learner_lock_solo';
    const epochMs = Date.now() + 24 * 3600 * 1000;
    const lockId = `${learnerId}_${epochMs}`;

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    await assertFails(
      learnerDb.collection('slotLocks').doc(lockId).set({
        uid: learnerId,
        slotEpochMs: epochMs,
        sessionId: 'non_existent_session',
        status: 'active',
      })
    );
  });

  test('أقفال المواعيد 3: رفض إنشاء قفل موعد بمعرف غير مطابق للصيغة {uid}_{slotEpochMs}', async () => {
    const learnerId = 'learner_bad_lock_id';
    const teacherId = 'teacher_bad_lock_id';
    const sessionId = 'session_bad_lock_id';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);
    const epochMs = scheduledAt.getTime();
    const wrongLockId = 'wrong_lock_id_123';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        timeCoins: 2,
        completedSessions: 0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const batch = learnerDb.batch();

    batch.update(learnerDb.collection('users').doc(learnerId), {
      timeCoins: 1,
      lastSessionId: sessionId,
    });

    batch.set(learnerDb.collection('sessions').doc(sessionId), {
      learnerId: learnerId,
      teacherId: teacherId,
      costCoins: 1,
      escrowStatus: 'held',
      status: 'confirmed',
      scheduledAt: scheduledAt,
    });

    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'booking',
    });

    batch.set(learnerDb.collection('slotLocks').doc(wrongLockId), {
      uid: learnerId,
      slotEpochMs: epochMs,
      sessionId: sessionId,
      status: 'active',
    });

    await assertFails(batch.commit());
  });

  test('أقفال المواعيد 4: حظر حذف قفل الموعد إطلاقاً (allow delete: if false)', async () => {
    const learnerId = 'learner_lock_del';
    const epochMs = 123456789;
    const lockId = `${learnerId}_${epochMs}`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('slotLocks').doc(lockId).set({
        uid: learnerId,
        slotEpochMs: epochMs,
        sessionId: 'session_old',
        status: 'used',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    await assertFails(learnerDb.collection('slotLocks').doc(lockId).delete());
  });

  test('أقفال المواعيد 5: سباق حجزين متزامنين لنفس المعلم ونفس الموعد (ينجح أحدهما ويفشل الآخر حتماً)', async () => {
    const teacherId = 'teacher_race_slot';
    const learnerA = 'learner_race_a';
    const learnerB = 'learner_race_b';
    const sessionA = 'session_race_a';
    const sessionB = 'session_race_b';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);
    const epochMs = scheduledAt.getTime();
    const teacherLockId = `${teacherId}_${epochMs}`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerA).set({ timeCoins: 2, completedSessions: 0 });
      await adminDb.collection('users').doc(learnerB).set({ timeCoins: 2, completedSessions: 0 });
    });

    const dbA = testEnv.authenticatedContext(learnerA, { email_verified: true }).firestore();
    const dbB = testEnv.authenticatedContext(learnerB, { email_verified: true }).firestore();

    // الحجز الأول (A)
    const batchA = dbA.batch();
    batchA.update(dbA.collection('users').doc(learnerA), { timeCoins: 1, lastSessionId: sessionA });
    batchA.set(dbA.collection('sessions').doc(sessionA), {
      learnerId: learnerA,
      teacherId: teacherId,
      costCoins: 1,
      escrowStatus: 'held',
      status: 'confirmed',
      scheduledAt: scheduledAt,
    });
    batchA.set(dbA.collection('transactions').doc(`${sessionA}_booking`), {
      userId: learnerA,
      sessionId: sessionA,
      amount: 1,
      type: 'booking',
    });
    batchA.set(dbA.collection('slotLocks').doc(`${learnerA}_${epochMs}`), {
      uid: learnerA,
      slotEpochMs: epochMs,
      sessionId: sessionA,
      status: 'active',
    });
    batchA.set(dbA.collection('slotLocks').doc(teacherLockId), {
      uid: teacherId,
      slotEpochMs: epochMs,
      sessionId: sessionA,
      status: 'active',
    });

    // الحجز الثاني (B) على نفس موعد المعلم بالضبط
    const batchB = dbB.batch();
    batchB.update(dbB.collection('users').doc(learnerB), { timeCoins: 1, lastSessionId: sessionB });
    batchB.set(dbB.collection('sessions').doc(sessionB), {
      learnerId: learnerB,
      teacherId: teacherId,
      costCoins: 1,
      escrowStatus: 'held',
      status: 'confirmed',
      scheduledAt: scheduledAt,
    });
    batchB.set(dbB.collection('transactions').doc(`${sessionB}_booking`), {
      userId: learnerB,
      sessionId: sessionB,
      amount: 1,
      type: 'booking',
    });
    batchB.set(dbB.collection('slotLocks').doc(`${learnerB}_${epochMs}`), {
      uid: learnerB,
      slotEpochMs: epochMs,
      sessionId: sessionB,
      status: 'active',
    });
    batchB.set(dbB.collection('slotLocks').doc(teacherLockId), {
      uid: teacherId,
      slotEpochMs: epochMs,
      sessionId: sessionB,
      status: 'active',
    });

    // تنفيذ الحجز الأول ينجح
    await assertSucceeds(batchA.commit());

    // تنفيذ الحجز الثاني على نفس القفل يفشل حتماً لمنع الحجز المزدوج
    await assertFails(batchB.commit());
  });
});
