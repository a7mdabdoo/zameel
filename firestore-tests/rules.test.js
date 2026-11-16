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

  test('معاملة ناجحة 1-أ: حجز جلسة 30 دقيقة مطابقة حرفياً لكتابات bookSessionWithEscrow (status: pending وأقفال الطرفين)', async () => {
    const learnerId = 'learner_real_30m';
    const teacherId = 'teacher_real_30m';
    const sessionId = 'session_book_30m';
    const txId = `${sessionId}_booking`;
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);
    const epochMs = scheduledAt.getTime();

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'learner30@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'teacher30@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    // المعاملة الذرية لحجز الجلسة مطابقة حرفياً لـ bookSessionWithEscrow في TimeBankRepository
    await assertSucceeds(
      learnerDb.runTransaction(async (t) => {
        // 1. خصم العملة من المتعلم مع ربط الجلسة
        t.update(learnerDb.collection('users').doc(learnerId), {
          timeCoins: 1,
          lastSessionId: sessionId,
        });

        // 2. إنشاء الجلسة بحالة معلقة (pending) وضمان معلق (held)
        t.set(learnerDb.collection('sessions').doc(sessionId), {
          id: sessionId,
          learnerId: learnerId,
          teacherId: teacherId,
          courseId: 'math101',
          courseName: 'الجبر الخطي',
          courseCode: 'MATH101',
          durationMinutes: 30,
          costCoins: 1,
          escrowStatus: 'held',
          status: 'pending',
          scheduledAt: scheduledAt,
        });

        // 3. قيد حركة المحفظة (حجز الضمان)
        t.set(learnerDb.collection('transactions').doc(txId), {
          id: txId,
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          isNegative: true,
          type: 'booking',
        });

        // 4. أقفال الموعد للمتعلم والمعلم (حصة واحدة 30 دقيقة = قفلين)
        t.set(learnerDb.collection('slotLocks').doc(`${learnerId}_${epochMs}`), {
          uid: learnerId,
          slotEpochMs: epochMs,
          sessionId: sessionId,
          status: 'active',
        });
        t.set(learnerDb.collection('slotLocks').doc(`${teacherId}_${epochMs}`), {
          uid: teacherId,
          slotEpochMs: epochMs,
          sessionId: sessionId,
          status: 'active',
        });
      })
    );
  });

  test('معاملة ناجحة 1-ب: حجز جلسة 60 دقيقة مطابقة حرفياً لكتابات bookSessionWithEscrow (4 أقفال والتحقق من حدود القواعد)', async () => {
    const learnerId = 'learner_real_60m';
    const teacherId = 'teacher_real_60m';
    const sessionId = 'session_book_60m';
    const txId = `${sessionId}_booking`;
    const scheduledAt = new Date(Date.now() + 48 * 3600 * 1000);
    const epoch1 = scheduledAt.getTime();
    const epoch2 = epoch1 + 30 * 60 * 1000;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'learner60@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'teacher60@gmail.com',
        timeCoins: 2,
        completedSessions: 0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    await assertSucceeds(
      learnerDb.runTransaction(async (t) => {
        // 1. خصم العملة من المتعلم
        t.update(learnerDb.collection('users').doc(learnerId), {
          timeCoins: 1,
          lastSessionId: sessionId,
        });

        // 2. إنشاء مستند الجلسة 60 دقيقة
        t.set(learnerDb.collection('sessions').doc(sessionId), {
          id: sessionId,
          learnerId: learnerId,
          teacherId: teacherId,
          courseId: 'cs101',
          courseName: 'هياكل البيانات',
          durationMinutes: 60,
          costCoins: 1,
          escrowStatus: 'held',
          status: 'pending',
          scheduledAt: scheduledAt,
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

        // 4. أقفال الموعد للشريحتين (2 للمتعلم + 2 للمعلم = 4 أقفال ذرية)
        t.set(learnerDb.collection('slotLocks').doc(`${learnerId}_${epoch1}`), {
          uid: learnerId,
          slotEpochMs: epoch1,
          sessionId: sessionId,
          status: 'active',
        });
        t.set(learnerDb.collection('slotLocks').doc(`${teacherId}_${epoch1}`), {
          uid: teacherId,
          slotEpochMs: epoch1,
          sessionId: sessionId,
          status: 'active',
        });
        t.set(learnerDb.collection('slotLocks').doc(`${learnerId}_${epoch2}`), {
          uid: learnerId,
          slotEpochMs: epoch2,
          sessionId: sessionId,
          status: 'active',
        });
        t.set(learnerDb.collection('slotLocks').doc(`${teacherId}_${epoch2}`), {
          uid: teacherId,
          slotEpochMs: epoch2,
          sessionId: sessionId,
          status: 'active',
        });
      })
    );
  });

  test('معاملة ناجحة 2: إتمام الجلسة وإطلاق الضمان للمعلم (completeSessionAndReleaseEscrow)', async () => {
    const learnerId = 'learner_real';
    const teacherId = 'teacher_real';
    const sessionId = 'session_complete_real_2';
    const txId = `${sessionId}_release`;
    const scheduledTime = new Date(Date.now() - 3600000); // الجلسة انتهى موعدها مسبقاً وتخضع للإتمام

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
        const schedTime = new Date(Date.now() + 86400000);
        t.set(learnerDb.collection('sessions').doc(sessionId), {
          id: sessionId,
          learnerId: learnerId,
          teacherId: teacherId,
          costCoins: 1,
          status: 'pending',
          escrowStatus: 'held',
          rating: null,
          scheduledAt: schedTime,
        });
        t.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
          id: `${sessionId}_booking`,
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          isNegative: true,
          type: 'booking',
        });
        t.set(learnerDb.collection('slotLocks').doc(`${teacherId}_${schedTime.getTime()}`), {
          uid: teacherId,
          slotEpochMs: schedTime.getTime(),
          sessionId: sessionId,
          status: 'active',
        });
      })
    );
  });

  test('نزاهة التقييم 2: عند إتمام الجلسة يزيد ratingCount بـ 1 و ratingSum بقيمة التقييم بدقة', async () => {
    const learnerId = 'learner_rating_comp';
    const teacherId = 'teacher_rating_comp';
    const sessionId = 'session_rating_comp_1';
    const txId = `${sessionId}_release`;
    const scheduledTime = new Date(Date.now() - 3600000); // الجلسة انتهى موعدها مسبقاً وتخضع للإتمام والتقييم

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
      status: 'pending',
      scheduledAt: validScheduledAt,
    });

    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'booking',
    });

    batch.set(learnerDb.collection('slotLocks').doc(`${teacherId}_${validScheduledAt.getTime()}`), {
      uid: teacherId,
      slotEpochMs: validScheduledAt.getTime(),
      sessionId: sessionId,
      status: 'active',
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
      status: 'pending',
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
      status: 'pending',
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
      status: 'pending',
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
      status: 'pending',
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
      status: 'pending',
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
      status: 'pending',
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

  // =========================================================================
  // قبول المعلم والاعتذار وإلغاء المتعلم (Teacher Acceptance & Rejection)
  // =========================================================================
  test('قبول المعلم 1: المعلم يقبل جلسة معلقة (pending -> confirmed) بدون أي حركة مالية', async () => {
    const teacherId = 'teacher_accept_ok';
    const learnerId = 'learner_accept_ok';
    const sessionId = 'session_accept_ok';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        scheduledAt: scheduledAt,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    await assertSucceeds(
      teacherDb.collection('sessions').doc(sessionId).update({
        status: 'confirmed',
      })
    );
  });

  test('قبول المعلم 2: رفض قبول الجلسة من قِبل المتعلم أو طرف غريب', async () => {
    const teacherId = 'teacher_accept_bad';
    const learnerId = 'learner_accept_bad';
    const strangerId = 'stranger_accept_bad';
    const sessionId = 'session_accept_bad';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        scheduledAt: scheduledAt,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const strangerDb = testEnv.authenticatedContext(strangerId, { email_verified: true }).firestore();

    await assertFails(learnerDb.collection('sessions').doc(sessionId).update({ status: 'confirmed' }));
    await assertFails(strangerDb.collection('sessions').doc(sessionId).update({ status: 'confirmed' }));
  });

  test('اعتذار المعلم 3: المعلم يعتذر عن جلسة معلقة (pending -> rejected) مع رد العملة للمتعلم', async () => {
    const teacherId = 'teacher_reject_ok';
    const learnerId = 'learner_reject_ok';
    const sessionId = 'session_reject_ok';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);
    const epochMs = scheduledAt.getTime();

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({ timeCoins: 1, completedSessions: 0 });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        scheduledAt: scheduledAt,
      });
      await adminDb.collection('slotLocks').doc(`${learnerId}_${epochMs}`).set({
        uid: learnerId,
        slotEpochMs: epochMs,
        sessionId: sessionId,
        status: 'active',
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    const batch = teacherDb.batch();

    batch.update(teacherDb.collection('users').doc(learnerId), {
      timeCoins: 2,
      lastSessionId: sessionId,
    });

    batch.update(teacherDb.collection('sessions').doc(sessionId), {
      status: 'rejected',
      escrowStatus: 'refunded_to_learner',
    });

    batch.set(teacherDb.collection('transactions').doc(`${sessionId}_refund`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'refund',
    });

    batch.update(teacherDb.collection('slotLocks').doc(`${learnerId}_${epochMs}`), {
      status: 'released',
    });

    await assertSucceeds(batch.commit());
  });

  test('إلغاء المتعلم قبل القبول 4: المتعلم يلغي جلسة معلقة (pending -> cancelled_by_learner) مع رد العملة', async () => {
    const teacherId = 'teacher_cancel_pending_ok';
    const learnerId = 'learner_cancel_pending_ok';
    const sessionId = 'session_cancel_pending_ok';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);
    const epochMs = scheduledAt.getTime();

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({ timeCoins: 1, completedSessions: 0 });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        scheduledAt: scheduledAt,
      });
      await adminDb.collection('slotLocks').doc(`${learnerId}_${epochMs}`).set({
        uid: learnerId,
        slotEpochMs: epochMs,
        sessionId: sessionId,
        status: 'active',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const batch = learnerDb.batch();

    batch.update(learnerDb.collection('users').doc(learnerId), {
      timeCoins: 2,
      lastSessionId: sessionId,
    });

    batch.update(learnerDb.collection('sessions').doc(sessionId), {
      status: 'cancelled_by_learner',
      escrowStatus: 'refunded_to_learner',
      cancelledBy: learnerId,
    });

    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_refund`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'refund',
    });

    batch.update(learnerDb.collection('slotLocks').doc(`${learnerId}_${epochMs}`), {
      status: 'released',
    });

    await assertSucceeds(batch.commit());
  });

  // =========================================================================
  // تم الشرح والإتمام بعد حلول الموعد (Teacher Done & ScheduledAt Completion)
  // =========================================================================
  test('تم الشرح 1: المعلم يسجل "تم الشرح" (teacherMarkedDoneAt) بعد حلول موعد الجلسة', async () => {
    const teacherId = 'teacher_done_ok';
    const learnerId = 'learner_done_ok';
    const sessionId = 'session_done_ok';
    // موعد في الماضي (قبل دقيقة واحدة)
    const pastScheduledAt = new Date(Date.now() - 60 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: pastScheduledAt,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    await assertSucceeds(
      teacherDb.collection('sessions').doc(sessionId).update({
        teacherMarkedDoneAt: new Date(),
      })
    );
  });

  test('تم الشرح 2: رفض تسجيل "تم الشرح" من قِبل المعلم قبل حلول موعد الجلسة', async () => {
    const teacherId = 'teacher_done_too_early';
    const learnerId = 'learner_done_too_early';
    const sessionId = 'session_done_too_early';
    // موعد في المستقبل (بعد ساعتين)
    const futureScheduledAt = new Date(Date.now() + 2 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: futureScheduledAt,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    await assertFails(
      teacherDb.collection('sessions').doc(sessionId).update({
        teacherMarkedDoneAt: new Date(),
      })
    );
  });

  test('إتمام الجلسة 3: رفض إتمام الجلسة وإطلاق الضمان من قِبل المتعلم قبل حلول موعد الجلسة', async () => {
    const teacherId = 'teacher_complete_too_early';
    const learnerId = 'learner_complete_too_early';
    const sessionId = 'session_complete_too_early';
    // موعد مستقبلي
    const futureScheduledAt = new Date(Date.now() + 2 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(teacherId).set({
        timeCoins: 2,
        completedSessions: 0,
        ratingSum: 0,
        ratingCount: 0,
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: futureScheduledAt,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const batch = learnerDb.batch();

    batch.update(learnerDb.collection('users').doc(teacherId), {
      timeCoins: 3,
      completedSessions: 1,
      ratingSum: 5,
      ratingCount: 1,
      lastSessionId: sessionId,
    });

    batch.update(learnerDb.collection('sessions').doc(sessionId), {
      status: 'completed',
      escrowStatus: 'released_to_teacher',
      rating: 5,
    });

    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_release`), {
      userId: teacherId,
      sessionId: sessionId,
      amount: 1,
      type: 'release',
    });

    await assertFails(batch.commit());
  });

  // =========================================================================
  // حماية الضمان ومنع تعليق العملة (No Stuck Escrow - Item 6)
  // =========================================================================
  test('انتهاء المهلة 1: نجاح استرداد المتعلم عند مرور أكثر من 24 ساعة على الطلب وهو معلق', async () => {
    const teacherId = 'teacher_exp_1';
    const learnerId = 'learner_exp_1';
    const sessionId = 'session_exp_1';
    const slotEpoch = 1800000000000;
    const createdAtOld = new Date(Date.now() - 25 * 3600 * 1000); // 25 hours ago
    const futureScheduled = new Date(Date.now() + 48 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        timeCoins: 2,
        email: 'learner_exp_1@test.com',
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        createdAt: createdAtOld,
        scheduledAt: futureScheduled,
      });
      await adminDb.collection('slotLocks').doc(`${learnerId}_${slotEpoch}`).set({
        uid: learnerId,
        slotEpochMs: slotEpoch,
        sessionId: sessionId,
        status: 'active',
      });
      await adminDb.collection('slotLocks').doc(`${teacherId}_${slotEpoch}`).set({
        uid: teacherId,
        slotEpochMs: slotEpoch,
        sessionId: sessionId,
        status: 'active',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const batch = learnerDb.batch();

    batch.update(learnerDb.collection('users').doc(learnerId), {
      timeCoins: 3,
      lastSessionId: sessionId,
    });
    batch.update(learnerDb.collection('sessions').doc(sessionId), {
      status: 'expired',
      escrowStatus: 'refunded_to_learner',
    });
    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_refund`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'refund',
    });
    batch.update(learnerDb.collection('slotLocks').doc(`${learnerId}_${slotEpoch}`), {
      status: 'released',
    });
    batch.update(learnerDb.collection('slotLocks').doc(`${teacherId}_${slotEpoch}`), {
      status: 'released',
    });

    await assertSucceeds(batch.commit());
  });

  test('انتهاء المهلة 2: نجاح استرداد المتعلم عند حلول موعد الجلسة والطلب لا يزال معلقاً', async () => {
    const teacherId = 'teacher_exp_2';
    const learnerId = 'learner_exp_2';
    const sessionId = 'session_exp_2';
    const slotEpoch = 1800000000001;
    const createdAtRecent = new Date(Date.now() - 3600 * 1000); // 1 hour ago
    const pastScheduled = new Date(Date.now() - 60 * 1000); // 1 min in past

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        timeCoins: 2,
        email: 'learner_exp_2@test.com',
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        createdAt: createdAtRecent,
        scheduledAt: pastScheduled,
      });
      await adminDb.collection('slotLocks').doc(`${learnerId}_${slotEpoch}`).set({
        uid: learnerId,
        slotEpochMs: slotEpoch,
        sessionId: sessionId,
        status: 'active',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const batch = learnerDb.batch();

    batch.update(learnerDb.collection('users').doc(learnerId), {
      timeCoins: 3,
      lastSessionId: sessionId,
    });
    batch.update(learnerDb.collection('sessions').doc(sessionId), {
      status: 'expired',
      escrowStatus: 'refunded_to_learner',
    });
    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_refund`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'refund',
    });
    batch.update(learnerDb.collection('slotLocks').doc(`${learnerId}_${slotEpoch}`), {
      status: 'released',
    });

    await assertSucceeds(batch.commit());
  });

  test('انتهاء المهلة 3: رفض استرداد المتعلم قبل مرور 24 ساعة وقبل حلول موعد الجلسة', async () => {
    const teacherId = 'teacher_exp_3';
    const learnerId = 'learner_exp_3';
    const sessionId = 'session_exp_3';
    const slotEpoch = 1800000000002;
    const createdAtRecent = new Date(Date.now() - 5 * 3600 * 1000); // 5 hours ago
    const futureScheduled = new Date(Date.now() + 24 * 3600 * 1000); // in 24 hours

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        timeCoins: 2,
        email: 'learner_exp_3@test.com',
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        createdAt: createdAtRecent,
        scheduledAt: futureScheduled,
      });
      await adminDb.collection('slotLocks').doc(`${learnerId}_${slotEpoch}`).set({
        uid: learnerId,
        slotEpochMs: slotEpoch,
        sessionId: sessionId,
        status: 'active',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const batch = learnerDb.batch();

    batch.update(learnerDb.collection('users').doc(learnerId), {
      timeCoins: 3,
      lastSessionId: sessionId,
    });
    batch.update(learnerDb.collection('sessions').doc(sessionId), {
      status: 'expired',
      escrowStatus: 'refunded_to_learner',
    });
    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_refund`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'refund',
    });
    batch.update(learnerDb.collection('slotLocks').doc(`${learnerId}_${slotEpoch}`), {
      status: 'released',
    });

    await assertFails(batch.commit());
  });

  test('انتهاء المهلة 4: رفض استرداد المعلم بدلاً من المتعلم عند انتهاء مهلة الرد', async () => {
    const teacherId = 'teacher_exp_4';
    const learnerId = 'learner_exp_4';
    const sessionId = 'session_exp_4';
    const createdAtOld = new Date(Date.now() - 30 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(teacherId).set({
        timeCoins: 2,
        email: 'teacher_exp_4@test.com',
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        createdAt: createdAtOld,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    const batch = teacherDb.batch();

    batch.update(teacherDb.collection('users').doc(teacherId), {
      timeCoins: 3,
      lastSessionId: sessionId,
    });
    batch.update(teacherDb.collection('sessions').doc(sessionId), {
      status: 'expired',
      escrowStatus: 'refunded_to_learner',
    });

    await assertFails(batch.commit());
  });

  test('تحرير تلقائي 1: نجاح مطالبة المعلم بالعملة بعد مرور 48 ساعة على الموعد مع تسجيل تم الشرح وصمت المتعلم', async () => {
    const teacherId = 'teacher_auto_1';
    const learnerId = 'learner_auto_1';
    const sessionId = 'session_auto_1';
    const slotEpoch = 1800000000003;
    const pastScheduled = new Date(Date.now() - 49 * 3600 * 1000); // 49 hours in past
    const doneAt = new Date(Date.now() - 48 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(teacherId).set({
        timeCoins: 5,
        completedSessions: 2,
        ratingSum: 10,
        ratingCount: 2,
        email: 'teacher_auto_1@test.com',
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: pastScheduled,
        teacherMarkedDoneAt: doneAt,
      });
      await adminDb.collection('slotLocks').doc(`${teacherId}_${slotEpoch}`).set({
        uid: teacherId,
        slotEpochMs: slotEpoch,
        sessionId: sessionId,
        status: 'active',
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    const batch = teacherDb.batch();

    batch.update(teacherDb.collection('users').doc(teacherId), {
      timeCoins: 6,
      completedSessions: 3,
      lastSessionId: sessionId,
    });
    batch.update(teacherDb.collection('sessions').doc(sessionId), {
      status: 'completed_auto',
      escrowStatus: 'released_to_teacher',
    });
    batch.set(teacherDb.collection('transactions').doc(`${sessionId}_release`), {
      userId: teacherId,
      sessionId: sessionId,
      amount: 1,
      type: 'release',
    });
    batch.update(teacherDb.collection('slotLocks').doc(`${teacherId}_${slotEpoch}`), {
      status: 'used',
    });

    await assertSucceeds(batch.commit());
  });

  test('تحرير تلقائي 2: رفض مطالبة المعلم بالعملة قبل مرور 48 ساعة على موعد الجلسة', async () => {
    const teacherId = 'teacher_auto_2';
    const learnerId = 'learner_auto_2';
    const sessionId = 'session_auto_2';
    const pastScheduled = new Date(Date.now() - 20 * 3600 * 1000); // only 20 hours ago
    const doneAt = new Date(Date.now() - 19 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(teacherId).set({
        timeCoins: 5,
        completedSessions: 2,
        email: 'teacher_auto_2@test.com',
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: pastScheduled,
        teacherMarkedDoneAt: doneAt,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    const batch = teacherDb.batch();

    batch.update(teacherDb.collection('users').doc(teacherId), {
      timeCoins: 6,
      completedSessions: 3,
      lastSessionId: sessionId,
    });
    batch.update(teacherDb.collection('sessions').doc(sessionId), {
      status: 'completed_auto',
      escrowStatus: 'released_to_teacher',
    });
    batch.set(teacherDb.collection('transactions').doc(`${sessionId}_release`), {
      userId: teacherId,
      sessionId: sessionId,
      amount: 1,
      type: 'release',
    });

    await assertFails(batch.commit());
  });

  test('تحرير تلقائي 3: رفض مطالبة المعلم بالعملة إذا لم يسجل "تم الشرح"', async () => {
    const teacherId = 'teacher_auto_3';
    const learnerId = 'learner_auto_3';
    const sessionId = 'session_auto_3';
    const pastScheduled = new Date(Date.now() - 50 * 3600 * 1000); // 50 hours ago but no teacherMarkedDoneAt

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(teacherId).set({
        timeCoins: 5,
        completedSessions: 2,
        email: 'teacher_auto_3@test.com',
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: pastScheduled,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    const batch = teacherDb.batch();

    batch.update(teacherDb.collection('users').doc(teacherId), {
      timeCoins: 6,
      completedSessions: 3,
      lastSessionId: sessionId,
    });
    batch.update(teacherDb.collection('sessions').doc(sessionId), {
      status: 'completed_auto',
      escrowStatus: 'released_to_teacher',
    });

    await assertFails(batch.commit());
  });

  test('تحرير تلقائي 4: رفض تعديل تقييم المعلم (ratingCount/ratingSum) أثناء التحرير التلقائي', async () => {
    const teacherId = 'teacher_auto_4';
    const learnerId = 'learner_auto_4';
    const sessionId = 'session_auto_4';
    const pastScheduled = new Date(Date.now() - 50 * 3600 * 1000);
    const doneAt = new Date(Date.now() - 49 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(teacherId).set({
        timeCoins: 5,
        completedSessions: 2,
        ratingSum: 10,
        ratingCount: 2,
        email: 'teacher_auto_4@test.com',
      });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: pastScheduled,
        teacherMarkedDoneAt: doneAt,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    const batch = teacherDb.batch();

    // محاولة غير مشروعة لزيادة التقييم في completed_auto
    batch.update(teacherDb.collection('users').doc(teacherId), {
      timeCoins: 6,
      completedSessions: 3,
      ratingSum: 15,
      ratingCount: 3,
      lastSessionId: sessionId,
    });
    batch.update(teacherDb.collection('sessions').doc(sessionId), {
      status: 'completed_auto',
      escrowStatus: 'released_to_teacher',
    });
    batch.set(teacherDb.collection('transactions').doc(`${sessionId}_release`), {
      userId: teacherId,
      sessionId: sessionId,
      amount: 1,
      type: 'release',
    });

    await assertFails(batch.commit());
  });

  test('فتح نزاع 1: نجاح المتعلم في فتح نزاع بعد قيام المعلم بتسجيل "تم الشرح"', async () => {
    const teacherId = 'teacher_disp_1';
    const learnerId = 'learner_disp_1';
    const sessionId = 'session_disp_1';
    const doneAt = new Date(Date.now() - 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: new Date(Date.now() - 2 * 3600 * 1000),
        teacherMarkedDoneAt: doneAt,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    await assertSucceeds(
      learnerDb.collection('sessions').doc(sessionId).update({
        status: 'disputed',
        disputedAt: new Date(),
        disputeReason: 'المعلم لم يحضر في الموعد المحدد',
      })
    );
  });

  test('فتح نزاع 2: رفض فتح نزاع من قِبل المتعلم قبل تسجيل المعلم "تم الشرح"', async () => {
    const teacherId = 'teacher_disp_2';
    const learnerId = 'learner_disp_2';
    const sessionId = 'session_disp_2';

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: new Date(Date.now() - 2 * 3600 * 1000),
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    await assertFails(
      learnerDb.collection('sessions').doc(sessionId).update({
        status: 'disputed',
        disputedAt: new Date(),
        disputeReason: 'اعتراض استباقي',
      })
    );
  });

  test('فتح نزاع 3: رفض مطالبة المعلم بالتحرير التلقائي طالما الجلسة في حالة نزاع (disputed)', async () => {
    const teacherId = 'teacher_disp_3';
    const learnerId = 'learner_disp_3';
    const sessionId = 'session_disp_3';
    const pastScheduled = new Date(Date.now() - 50 * 3600 * 1000);
    const doneAt = new Date(Date.now() - 49 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(teacherId).set({
        timeCoins: 5,
        completedSessions: 2,
        email: 'teacher_disp_3@test.com',
      });
      // الجلسة متنازع عليها
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'disputed',
        scheduledAt: pastScheduled,
        teacherMarkedDoneAt: doneAt,
        disputeReason: 'النزاع قيد المراجعة اليدوية',
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    const batch = teacherDb.batch();

    batch.update(teacherDb.collection('users').doc(teacherId), {
      timeCoins: 6,
      completedSessions: 3,
      lastSessionId: sessionId,
    });
    batch.update(teacherDb.collection('sessions').doc(sessionId), {
      status: 'completed_auto',
      escrowStatus: 'released_to_teacher',
    });
    batch.set(teacherDb.collection('transactions').doc(`${sessionId}_release`), {
      userId: teacherId,
      sessionId: sessionId,
      amount: 1,
      type: 'release',
    });

    await assertFails(batch.commit());
  });

  // =========================================================================
  // القسم 16: حماية العملات ومنع التوليد الذاتي والتحقق من حقول المذاكرة (Item A)
  // =========================================================================

  test('بند أ (سلبي): منع صاحب الحساب من زيادة timeCoins بنفسه بأي قيمة (+1 أو غيرها)', async () => {
    const userId = 'user_mint_test';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        email: 'user_mint@test.com',
        timeCoins: 2,
        completedSessions: 0,
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();
    // محاولة رفع الرصيد بـ +1
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        timeCoins: 3,
      })
    );
    // محاولة رفع الرصيد بـ +10
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        timeCoins: 12,
      })
    );
  });

  test('بند أ (سلبي): منع المستخدم غير الموثق بريده من زيادة العملات أو إنشاء معاملات', async () => {
    const userId = 'unverified_user';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        email: 'unverified@test.com',
        timeCoins: 2,
        completedSessions: 0,
      });
    });

    const unverifiedDb = testEnv.authenticatedContext(userId, { email_verified: false }).firestore();
    await assertFails(
      unverifiedDb.collection('users').doc(userId).update({
        timeCoins: 3,
      })
    );
    await assertFails(
      unverifiedDb.collection('transactions').doc('tx_unverified').set({
        userId: userId,
        amount: 1,
        type: 'study_reward',
      })
    );
  });

  test('بند أ (سلبي): منع إنشاء حركة محفظة من نوع study_reward منعاً باتاً', async () => {
    const userId = 'user_reward_forger';
    const txId = 'tx_study_forged_123';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        email: 'forger@test.com',
        timeCoins: 2,
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();
    await assertFails(
      authedDb.collection('transactions').doc(txId).set({
        userId: userId,
        amount: 1,
        type: 'study_reward',
      })
    );
  });

  test('بند أ (سلبي): منع صاحب الحساب من تعديل studyPoints أو studyHours مباشرة', async () => {
    const userId = 'user_study_fields';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        email: 'study@test.com',
        timeCoins: 2,
        studyPoints: 0,
        studyHours: 0,
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        studyPoints: 10,
      })
    );
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        studyHours: 5,
      })
    );
  });

  test('بند أ (سلبي): منع تحديث completedBlockIds مع حقول إضافية في نفس العملية', async () => {
    const userId = 'user_extra_fields';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        email: 'extra@test.com',
        timeCoins: 2,
        completedBlockIds: ['block_1'],
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        completedBlockIds: ['block_1', 'block_2'],
        studyPoints: 1, // حقل إضافي مرفوض
      })
    );
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        completedBlockIds: ['block_1', 'block_2'],
        displayName: 'Hacked Name', // حقل إضافي
      })
    );
  });

  test('بند أ (سلبي): منع تحديث completedBlockIds بنوع بيانات غير مصفوفة', async () => {
    const userId = 'user_wrong_type';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        email: 'wrong@test.com',
        timeCoins: 2,
        completedBlockIds: [],
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        completedBlockIds: 'not_a_list',
      })
    );
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        completedBlockIds: { block_1: true },
      })
    );
  });

  test('بند أ (سلبي): منع تجاوز الحد الأقصى 500 عنصر في completedBlockIds', async () => {
    const userId = 'user_oversized_blocks';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        email: 'oversized@test.com',
        timeCoins: 2,
        completedBlockIds: [],
      });
    });

    const oversizedList = Array.from({ length: 501 }, (_, i) => `block_${i}`);
    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();
    await assertFails(
      authedDb.collection('users').doc(userId).update({
        completedBlockIds: oversizedList,
      })
    );
  });

  test('بند أ (إيجابي): نجاح تحديث completedBlockIds بصورة شرعية بمفردها بمصفوفة صالحة', async () => {
    const userId = 'user_normal_block';
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(userId).set({
        uid: userId,
        email: 'normal@test.com',
        timeCoins: 2,
        completedBlockIds: ['block_101'],
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();
    await assertSucceeds(
      authedDb.collection('users').doc(userId).update({
        completedBlockIds: ['block_101', 'block_102'],
      })
    );
  });

  // =========================================================================
  // القسم 17: عقد الحجز ومسار الحجز الكامل وفحوصات المطابقة (Hotfix Item 1)
  // =========================================================================

  test('بند 1 (عقد سلبي): فشل إنشاء جلسة بحالة confirmed (مسموح فقط بـ pending)', async () => {
    const learnerId = 'learner_contract_err';
    const teacherId = 'teacher_contract_err';
    const sessionId = 'session_contract_err';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({ timeCoins: 2, email: 'learner@test.com' });
      await adminDb.collection('users').doc(teacherId).set({ timeCoins: 2, email: 'teacher@test.com' });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
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
          escrowStatus: 'held',
          status: 'confirmed', // غير مسموح عند الإنشاء!
          scheduledAt: scheduledAt,
        });
        t.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          type: 'booking',
        });
      })
    );
  });

  test('بند 1 (المسار الذهبي الكامل): حجز -> قبول -> تم الشرح -> إتمام مع التقييم والأقفال', async () => {
    const learnerId = 'learner_golden';
    const teacherId = 'teacher_golden';
    const sessionId = 'session_golden_full';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);
    const epochMs = scheduledAt.getTime();
    const learnerLockId = `${learnerId}_${epochMs}`;
    const teacherLockId = `${teacherId}_${epochMs}`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({
        uid: learnerId,
        email: 'learner@golden.com',
        timeCoins: 2,
        completedSessions: 0,
      });
      await adminDb.collection('users').doc(teacherId).set({
        uid: teacherId,
        email: 'teacher@golden.com',
        timeCoins: 2,
        completedSessions: 0,
        teacherRating: 0.0,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    // 1. الحجز بواسطة المتعلم مع قيد الضمان وأقفال الموعد (status: pending)
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
          courseName: 'الجبر الخطي',
          durationMinutes: 30,
          costCoins: 1,
          escrowStatus: 'held',
          status: 'pending',
          scheduledAt: scheduledAt,
        });
        t.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          type: 'booking',
        });
        t.set(learnerDb.collection('slotLocks').doc(learnerLockId), {
          uid: learnerId,
          slotEpochMs: epochMs,
          sessionId: sessionId,
          status: 'active',
        });
        t.set(learnerDb.collection('slotLocks').doc(teacherLockId), {
          uid: teacherId,
          slotEpochMs: epochMs,
          sessionId: sessionId,
          status: 'active',
        });
      })
    );

    // 2. قبول المعلم للجلسة (pending -> confirmed)
    await assertSucceeds(
      teacherDb.collection('sessions').doc(sessionId).update({
        status: 'confirmed',
        confirmedAt: new Date(),
      })
    );

    // محاكاة حلول موعد الجلسة وانتهائها (تقديم موعد الجلسة للماضي حتى يسمح بتم الشرح والإتمام)
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).update({
        scheduledAt: new Date(Date.now() - 3600 * 1000),
      });
    });

    // 3. تأكيد المعلم إتمام الشرح (teacherMarkedDoneAt)
    await assertSucceeds(
      teacherDb.collection('sessions').doc(sessionId).update({
        teacherMarkedDoneAt: new Date(),
      })
    );

    // 4. إتمام المتعلم للجلسة مع التقييم، تحرير الضمان، وتحويل الأقفال إلى used
    await assertSucceeds(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(teacherId), {
          timeCoins: 3,
          completedSessions: 1,
          ratingSum: 5,
          ratingCount: 1,
          lastSessionId: sessionId,
        });
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          status: 'completed',
          escrowStatus: 'released_to_teacher',
          rating: 5,
          reviewComment: 'شرح ممتاز جداً',
          completedAt: new Date(),
        });
        t.set(learnerDb.collection('transactions').doc(`${sessionId}_release`), {
          userId: teacherId,
          sessionId: sessionId,
          amount: 1,
          type: 'release',
        });
        t.update(learnerDb.collection('slotLocks').doc(learnerLockId), {
          status: 'used',
        });
        t.update(learnerDb.collection('slotLocks').doc(teacherLockId), {
          status: 'used',
        });
      })
    );
  });

  test('بند 1 (مسار استرداد عند الرفض): رفض المعلم يحول الضمان إلى refunded والأقفال إلى released', async () => {
    const learnerId = 'learner_reject';
    const teacherId = 'teacher_reject';
    const sessionId = 'session_reject';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);
    const epochMs = scheduledAt.getTime();
    const learnerLockId = `${learnerId}_${epochMs}`;
    const teacherLockId = `${teacherId}_${epochMs}`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({ timeCoins: 1, completedSessions: 0 });
      await adminDb.collection('users').doc(teacherId).set({ timeCoins: 2, completedSessions: 0 });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        scheduledAt: scheduledAt,
      });
      await adminDb.collection('slotLocks').doc(learnerLockId).set({
        uid: learnerId,
        slotEpochMs: epochMs,
        sessionId: sessionId,
        status: 'active',
      });
      await adminDb.collection('slotLocks').doc(teacherLockId).set({
        uid: teacherId,
        slotEpochMs: epochMs,
        sessionId: sessionId,
        status: 'active',
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();

    await assertSucceeds(
      teacherDb.runTransaction(async (t) => {
        t.update(teacherDb.collection('users').doc(learnerId), {
          timeCoins: 2,
          lastSessionId: sessionId,
        });
        t.update(teacherDb.collection('sessions').doc(sessionId), {
          status: 'rejected',
          escrowStatus: 'refunded_to_learner',
          rejectedAt: new Date(),
        });
        t.set(teacherDb.collection('transactions').doc(`${sessionId}_refund`), {
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          type: 'refund',
        });
        t.update(teacherDb.collection('slotLocks').doc(learnerLockId), {
          uid: learnerId,
          slotEpochMs: epochMs,
          sessionId: sessionId,
          status: 'released',
        });
        t.update(teacherDb.collection('slotLocks').doc(teacherLockId), {
          uid: teacherId,
          slotEpochMs: epochMs,
          sessionId: sessionId,
          status: 'released',
        });
      })
    );
  });

  test('بند 1 (مسار استرداد عند الإلغاء المبكر): إلغاء المتعلم للجلسة المعلقة يسترد العملة ويحرر الأقفال', async () => {
    const learnerId = 'learner_cancel_pending';
    const teacherId = 'teacher_cancel_pending';
    const sessionId = 'session_cancel_pending';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);
    const epochMs = scheduledAt.getTime();
    const learnerLockId = `${learnerId}_${epochMs}`;
    const teacherLockId = `${teacherId}_${epochMs}`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({ timeCoins: 1, completedSessions: 0 });
      await adminDb.collection('users').doc(teacherId).set({ timeCoins: 2, completedSessions: 0 });
      await adminDb.collection('sessions').doc(sessionId).set({
        id: sessionId,
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        scheduledAt: scheduledAt,
      });
      await adminDb.collection('slotLocks').doc(learnerLockId).set({
        uid: learnerId,
        slotEpochMs: epochMs,
        sessionId: sessionId,
        status: 'active',
      });
      await adminDb.collection('slotLocks').doc(teacherLockId).set({
        uid: teacherId,
        slotEpochMs: epochMs,
        sessionId: sessionId,
        status: 'active',
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();

    await assertSucceeds(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(learnerId), {
          timeCoins: 2,
          lastSessionId: sessionId,
        });
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          status: 'cancelled_by_learner',
          escrowStatus: 'refunded_to_learner',
          cancelledBy: learnerId,
          cancelledAt: new Date(),
        });
        t.set(learnerDb.collection('transactions').doc(`${sessionId}_refund`), {
          userId: learnerId,
          sessionId: sessionId,
          amount: 1,
          type: 'refund',
        });
        t.update(learnerDb.collection('slotLocks').doc(learnerLockId), {
          uid: learnerId,
          slotEpochMs: epochMs,
          sessionId: sessionId,
          status: 'released',
        });
        t.update(learnerDb.collection('slotLocks').doc(teacherLockId), {
          uid: teacherId,
          slotEpochMs: epochMs,
          sessionId: sessionId,
          status: 'released',
        });
      })
    );
  });

  // =========================================================================
  // القسم 18: تحصين أقفال المواعيد ومنع التلاعب وحظر التخطي (Hotfix Item 2)
  // =========================================================================

  test('بند 2 (سلبي 1 - Griefing): منع إنشاء أقفال مواعيد لمستخدمين آخرين دون جلسة حقيقية للمنشئ', async () => {
    const maliciousUid = 'attacker_1';
    const victimUid = 'victim_1';
    const epoch = Math.floor((Date.now() + 24 * 3600 * 1000) / 1800000) * 1800000;
    const lockId = `${victimUid}_${epoch}`;

    const attackerDb = testEnv.authenticatedContext(maliciousUid, { email_verified: true }).firestore();
    await assertFails(
      attackerDb.collection('slotLocks').doc(lockId).set({
        uid: victimUid,
        slotEpochMs: epoch,
        sessionId: 'fake_session_123',
        status: 'active',
      })
    );
  });

  test('بند 2 (سلبي 2 - Skipping Locks): فشل إنشاء الجلسة في حال تخطي إنشاء قفل موعد المعلم', async () => {
    const learnerId = 'learner_skip_lock';
    const teacherId = 'teacher_skip_lock';
    const sessionId = 'session_skipped_locks';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({ timeCoins: 2, completedSessions: 0 });
      await adminDb.collection('users').doc(teacherId).set({ timeCoins: 2, completedSessions: 0 });
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
      status: 'pending',
      scheduledAt: scheduledAt,
    });
    batch.set(learnerDb.collection('transactions').doc(`${sessionId}_booking`), {
      userId: learnerId,
      sessionId: sessionId,
      amount: 1,
      type: 'booking',
    });
    // تم تخطي قفل المعلم عمداً هنا
    await assertFails(batch.commit());
  });

  test('بند 2 (سلبي 3 - Other Session): منع إنشاء قفل بالربط مع جلسة موجودة مسبقاً لمستخدم آخر', async () => {
    const maliciousUid = 'attacker_lock_session';
    const victimLearner = 'victim_learner_existing';
    const victimTeacher = 'victim_teacher_existing';
    const existingSessionId = 'session_already_exists';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);
    const epoch = scheduledAt.getTime();

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(existingSessionId).set({
        id: existingSessionId,
        learnerId: victimLearner,
        teacherId: victimTeacher,
        status: 'pending',
        escrowStatus: 'held',
        scheduledAt: scheduledAt,
        durationMinutes: 30,
        costCoins: 1,
      });
    });

    const attackerDb = testEnv.authenticatedContext(maliciousUid, { email_verified: true }).firestore();
    await assertFails(
      attackerDb.collection('slotLocks').doc(`${victimTeacher}_${epoch}`).set({
        uid: victimTeacher,
        slotEpochMs: epoch,
        sessionId: existingSessionId,
        status: 'active',
      })
    );
  });

  test('بند 2 (سلبي 4 - Reactivate Released): منع إعادة تنشيط قفل released إلى active دون معاملة جلسة جديدة', async () => {
    const userId = 'user_released_lock';
    const epoch = Math.floor((Date.now() + 24 * 3600 * 1000) / 1800000) * 1800000;
    const lockId = `${userId}_${epoch}`;

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('slotLocks').doc(lockId).set({
        uid: userId,
        slotEpochMs: epoch,
        sessionId: 'session_old_cancelled',
        status: 'released',
      });
    });

    const authedDb = testEnv.authenticatedContext(userId, { email_verified: true }).firestore();
    // محاولة إعادة التنشيط مباشرة بدون إنشاء جلسة جديدة تفشل
    await assertFails(
      authedDb.collection('slotLocks').doc(lockId).update({
        status: 'active',
      })
    );
  });

  // =========================================================================
  // القسم 19: تحصين تحديثات الجلسات وقوائم الحقول المسموحة (Hotfix Item 3)
  // =========================================================================

  test('بند 3 (سلبي 1 - Accept Past ScheduledAt): رفض قبول المعلم للجلسة بعد حلول موعدها (request.time >= scheduledAt)', async () => {
    const teacherId = 'teacher_accept_late';
    const learnerId = 'learner_accept_late';
    const sessionId = 'session_accept_late';
    const pastScheduledAt = new Date(Date.now() - 3600 * 1000); // قبل ساعة

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        scheduledAt: pastScheduledAt,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    await assertFails(
      teacherDb.collection('sessions').doc(sessionId).update({
        status: 'confirmed',
      })
    );
  });

  test('بند 3 (سلبي 2 - Accept Forbidden Field): رفض تعديل رابط الاجتماع أو حقول ممنوعة أثناء قبول المعلم', async () => {
    const teacherId = 'teacher_accept_harden';
    const learnerId = 'learner_accept_harden';
    const sessionId = 'session_accept_harden';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'pending',
        scheduledAt: scheduledAt,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    // محاولة تغيير meetingUrl مع القبول تفشل لمخالفتها hasOnly(['status', 'confirmedAt'])
    await assertFails(
      teacherDb.collection('sessions').doc(sessionId).update({
        status: 'confirmed',
        meetingUrl: 'https://meet.google.com/abc-defg-hij',
      })
    );
  });

  test('بند 3 (سلبي 3 - Complete Forbidden Field teacherMarkedDoneAt): منع المتعلم من لمس teacherMarkedDoneAt أثناء الإتمام', async () => {
    const learnerId = 'learner_comp_harden';
    const teacherId = 'teacher_comp_harden';
    const sessionId = 'session_comp_harden';
    const scheduledAt = new Date(Date.now() - 3600 * 1000); // موعد حل بالفعل

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(teacherId).set({ timeCoins: 1, completedSessions: 0 });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledAt,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    await assertFails(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(teacherId), { timeCoins: 2, lastSessionId: sessionId });
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          status: 'completed',
          escrowStatus: 'released_to_teacher',
          rating: 5,
          teacherMarkedDoneAt: new Date(),
        });
      })
    );
  });

  test('بند 3 (سلبي 4 - Complete Forbidden Field meetingUrl): منع تعديل meetingUrl أثناء إتمام الجلسة', async () => {
    const learnerId = 'learner_comp_url';
    const teacherId = 'teacher_comp_url';
    const sessionId = 'session_comp_url';
    const scheduledAt = new Date(Date.now() - 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(teacherId).set({ timeCoins: 1, completedSessions: 0 });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledAt,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    await assertFails(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(teacherId), { timeCoins: 2, lastSessionId: sessionId });
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          status: 'completed',
          escrowStatus: 'released_to_teacher',
          rating: 5,
          meetingUrl: 'https://meet.google.com/new-link-hacked',
        });
      })
    );
  });

  test('بند 3 (سلبي 5 - Cancel Forbidden Field rating): منع تزوير التقييم rating أثناء إلغاء الجلسة', async () => {
    const learnerId = 'learner_cancel_rating';
    const teacherId = 'teacher_cancel_rating';
    const sessionId = 'session_cancel_rating';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({ timeCoins: 1, completedSessions: 0 });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledAt,
      });
    });

    const learnerDb = testEnv.authenticatedContext(learnerId, { email_verified: true }).firestore();
    // محاولة إرسال rating مع الإلغاء المبكر تفشل لمخالفتها hasOnly
    await assertFails(
      learnerDb.runTransaction(async (t) => {
        t.update(learnerDb.collection('users').doc(learnerId), { timeCoins: 2, lastSessionId: sessionId });
        t.update(learnerDb.collection('sessions').doc(sessionId), {
          status: 'cancelled_by_learner',
          escrowStatus: 'refunded_to_learner',
          cancelledBy: learnerId,
          rating: 1, // ممنوع أثناء الإلغاء!
        });
      })
    );
  });

  test('بند 3 (سلبي 6 - Cancel Forbidden Field costCoins): منع التلاعب بقيمة costCoins أثناء الإلغاء', async () => {
    const teacherId = 'teacher_cancel_coins';
    const learnerId = 'learner_cancel_coins';
    const sessionId = 'session_cancel_coins';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('users').doc(learnerId).set({ timeCoins: 1, completedSessions: 0 });
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledAt,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    await assertFails(
      teacherDb.runTransaction(async (t) => {
        t.update(teacherDb.collection('users').doc(learnerId), { timeCoins: 2, lastSessionId: sessionId });
        t.update(teacherDb.collection('sessions').doc(sessionId), {
          status: 'cancelled_by_teacher',
          escrowStatus: 'refunded_to_learner',
          cancelledBy: teacherId,
          costCoins: 5, // ممنوع!
        });
      })
    );
  });

  test('بند 3 (سلبي 7 - Invalid meetingUrl): منع المعلم من حفظ رابط اجتماع مشبوه أو غير معتمد', async () => {
    const teacherId = 'teacher_fake_meet';
    const learnerId = 'learner_fake_meet';
    const sessionId = 'session_fake_meet';
    const scheduledAt = new Date(Date.now() + 24 * 3600 * 1000);

    await testEnv.withSecurityRulesDisabled(async (context) => {
      const adminDb = context.firestore();
      await adminDb.collection('sessions').doc(sessionId).set({
        learnerId: learnerId,
        teacherId: teacherId,
        costCoins: 1,
        escrowStatus: 'held',
        status: 'confirmed',
        scheduledAt: scheduledAt,
      });
    });

    const teacherDb = testEnv.authenticatedContext(teacherId, { email_verified: true }).firestore();
    await assertFails(
      teacherDb.collection('sessions').doc(sessionId).update({
        meetingUrl: 'https://phishing-site.com/session-room',
      })
    );
  });
});
