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
    const txId = 'tx_book_real_1';

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
          type: 'session_booking',
        });
      })
    );
  });

  test('معاملة ناجحة 2: إتمام الجلسة وإطلاق الضمان للمعلم (completeSessionAndReleaseEscrow)', async () => {
    const learnerId = 'learner_real';
    const teacherId = 'teacher_real';
    const sessionId = 'session_complete_real_2';
    const txId = 'tx_complete_real_2';
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
          teacherRating: 5.0,
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
          type: 'session_earning',
        });
      })
    );
  });

  test('معاملة ناجحة 3: إلغاء مبكر من المتعلم قبل الموعد بـ 24 ساعة واسترداد العملة (cancelSessionWithEscrow)', async () => {
    const learnerId = 'learner_real';
    const teacherId = 'teacher_real';
    const sessionId = 'session_early_cancel_3';
    const txId = 'tx_refund_early_3';
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
          type: 'cancellation_refund',
        });
      })
    );
  });

  test('معاملة ناجحة 4: إلغاء متأخر من المتعلم (< ساعتين) وتحويل العملة كتعويض للمعلم (cancelSessionWithEscrow)', async () => {
    const learnerId = 'learner_real';
    const teacherId = 'teacher_real';
    const sessionId = 'session_late_cancel_4';
    const txId = 'tx_comp_late_4';
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
          type: 'late_compensation',
        });
      })
    );
  });

  test('معاملة ناجحة 5: إلغاء الجلسة من المعلم في أي وقت واسترداد العملة للمتعلم (cancelSessionWithEscrow)', async () => {
    const learnerId = 'learner_real';
    const teacherId = 'teacher_real';
    const sessionId = 'session_teacher_cancel_5';
    const txId = 'tx_refund_teacher_5';
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
          type: 'cancellation_refund',
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

  test('أسماء المستخدمين 1: نجاح حجز اسم مستخدم فريد والقراءة العامة متاحة للجميع', async () => {
    const userId = 'student_ali';
    const email = 'ali@gmail.com';
    const username = 'ali_coder';

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true, email: email }).firestore();

    // حجز اسم مستخدم فريد
    await assertSucceeds(
      authedDb.collection('usernames').doc(username).set({
        uid: userId,
        email: email,
      })
    );

    // القراءة متاحة حتى بدون تسجيل دخول (لتسجيل الدخول به)
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      unauthedDb.collection('usernames').doc(username).get()
    );
  });

  test('أسماء المستخدمين 2: فشل حجز اسم مستخدم مأخوذ مسبقاً (منع التكرار)', async () => {
    const user1 = 'student_1';
    const user2 = 'student_2';
    const username = 'hero_coder';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('usernames').doc(username).set({
        uid: user1,
        email: 'user1@gmail.com',
      });
    });

    const user2Db = testEnv.authenticatedContext(user2, { email_verified: true, email: 'user2@gmail.com' }).firestore();

    // محاولة أخذ نفس الاسم المسجل
    await assertFails(
      user2Db.collection('usernames').doc(username).set({
        uid: user2,
        email: 'user2@gmail.com',
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
});
