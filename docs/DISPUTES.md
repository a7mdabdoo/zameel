# دليل المعالجة اليدوية للنزاعات المالية (Manual Dispute Resolution via Firebase Console)

في حال قيام المتعلّم بفتح نزاع (`status: 'disputed'`) اعتراضاً على قيام الشارح بتسجيل "تم الشرح" دون تقديم المحاضرة، تظل عملة الوقت محتجزة بأمان في نظام الضمان (`escrowStatus: 'held'`).
ونظراً للالتزام بخطة Spark المجانية (بدون Cloud Functions)، تتم تسوية النزاعات يدوياً من قِبل إدارة التطبيق عبر **Firebase Console**.

---

## 1. استعراض وفحص النزاع
1. افتح **Firebase Console** -> مشروع `zameel` -> **Cloud Firestore** -> علامة تبويب **Data**.
2. توجّه إلى مجموعة `sessions` واستعرض المستندات التي قيمتها `status == 'disputed'`.
3. افحص بيانات النزاع في مستند الجلسة:
   - `disputeReason`: سبب اعتراض المتعلم.
   - `disputedAt`: توقيت فتح النزاع.
   - `teacherMarkedDoneAt`: توقيت ادعاء الشارح بتقديم الشرح.
   - `scheduledAt`: موعد الجلسة المجدول.
   - `learnerId` و `teacherId`.
4. افتح المجموعة الفرعية `sessions/{sessionId}/messages` لمراجعة سجل المحادثة والتنسيق بين الطرفين للتأكد من الواقعة.

---

## 2. مسار الحل الأول: إقرار حق المتعلم واسترداد العملة (Refund to Learner)
يُطبق هذا الخيار إذا ثبت تغيب المعلم أو عدم تقديم الشرح:
1. **تحديث رصيد المتعلم (`/users/{learnerId}`):**
   - قم بزيادة حقل `timeCoins` بمقدار 1 عملة (مثال: من 2 إلى 3).
   - قم بتحديث حقل `lastSessionId` إلى معرف الجلسة `{sessionId}`.
2. **تسجيل القيد المحاسبي (`/transactions`):**
   - أنشئ مستنداً جديداً بالمعرف الحتمي: `{sessionId}_refund`.
   - املأ الحقول التالية:
     ```json
     {
       "id": "{sessionId}_refund",
       "userId": "{learnerId}",
       "sessionId": "{sessionId}",
       "title": "استرداد إداري بعد مراجعة النزاع",
       "amount": 1,
       "isNegative": false,
       "type": "refund",
       "createdAt": [Firestore Server Timestamp]
     }
     ```
3. **تحرير أقفال المواعيد (`/slotLocks`):**
   - ابحث في مجموعة `slotLocks` عن المستندات الخاصة بالجلسة (`sessionId == {sessionId}`).
   - غيّر حقل `status` إلى `'released'`.
4. **تسوية الجلسة (`/sessions/{sessionId}`):**
   - عدّل حقل `status` إلى `'resolved_refunded'`.
   - عدّل حقل `escrowStatus` إلى `'refunded_to_learner'`.
   - أضف حقل `resolvedAt`: الطابع الزمني الحالي.
   - أضف حقل `resolutionNote`: "تم استرداد العملة للمتعلم بعد ثبوت عدم تقديم الشرح".

---

## 3. مسار الحل الثاني: إقرار حق الشارح وتحرير العملة (Release to Teacher)
يُطبق هذا الخيار إذا ثبت التزام الشارح بالحضور وتقديم الشرح:
1. **تحديث رصيد الشارح (`/users/{teacherId}`):**
   - قم بزيادة حقل `timeCoins` بمقدار 1 عملة.
   - قم بزيادة حقل `completedSessions` بمقدار 1.
   - قم بتحديث حقل `lastSessionId` إلى معرف الجلسة `{sessionId}`.
   - *(تنبيه: لا تقم بتعديل ratingSum أو ratingCount لعدم وجود تقييم من المتعلم)*.
2. **تسجيل القيد المحاسبي (`/transactions`):**
   - أنشئ مستنداً جديداً بالمعرف الحتمي: `{sessionId}_release`.
   - املأ الحقول التالية:
     ```json
     {
       "id": "{sessionId}_release",
       "userId": "{teacherId}",
       "sessionId": "{sessionId}",
       "title": "تحرير إداري لمكافأة الشرح بعد مراجعة النزاع",
       "amount": 1,
       "isNegative": false,
       "type": "release",
       "createdAt": [Firestore Server Timestamp]
     }
     ```
3. **تثبيت أقفال المواعيد (`/slotLocks`):**
   - ابحث في مجموعة `slotLocks` عن أقفال الجلسة وحوّل `status` إلى `'used'`.
4. **تسوية الجلسة (`/sessions/{sessionId}`):**
   - عدّل حقل `status` إلى `'resolved_released'`.
   - عدّل حقل `escrowStatus` إلى `'released_to_teacher'`.
   - أضف حقل `resolvedAt`: الطابع الزمني الحالي.
   - أضف حقل `resolutionNote`: "تم تحرير العملة للشارح بعد ثبوت تقديم الشرح".
