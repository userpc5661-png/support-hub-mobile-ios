# Wasl Mobile — 2.6.0+35

تطبيق موظفي خدمة العملاء بنظام Flutter، مرتبط افتراضيًا ببيئة الإنتاج:

`https://go-wasl.com/api`

## ما تم تجهيزه

- هوية **Wasl** مع الشعار المرفق وأيقونة Android وشاشة بداية تعرض الشعار فقط.
- واجهة دردشات جوال مألوفة وسريعة: قائمة، بحث، غير مقروء، فقاعات، حالات الرسالة، ومؤشر اتصال لحظي.
- فتح شاشة الدردشة مباشرة قبل اكتمال تحديث الشبكة باستخدام آخر نسخة مخزنة في الذاكرة.
- دعم إرسال وعرض الصور، الفيديو، التسجيلات الصوتية، والملفات عبر مسارات API الموجودة.
- إشعارات Firebase: تسجيل الجهاز، استقبال foreground/background/terminated، وفتح `conversationId` مباشرة.
- إضافة عميل ثم بدء دردشة وظهورها في القائمة مباشرة.
- ترجمة عربية/إنجليزية متناسقة، مع `Chats / Cancelled` و`الدردشات / الملغاة`.
- إعداد **Chat appearance / مظهر الدردشة** لتغيير الخلفية وألوان الفقاعات وحجم الخط والنمط.

## التشغيل في Android Studio

1. افتح مجلد المشروع الذي يحتوي على `pubspec.yaml`.
2. شغّل:

```powershell
flutter pub get
```

3. اختر جهاز Android ثم شغّل `lib/main.dart`، أو استخدم:

```powershell
RUN_ANDROID.cmd
```

## Firebase والإشعارات الخارجية

انسخ الملف:

`firebase_defines.example.json`

إلى:

`firebase_defines.json`

ثم ضع قيم مشروع Firebase الحقيقية. يدعم الملف قيمًا مشتركة أو قيم Android وiOS منفصلة. لا ترفع `firebase_defines.json` إلى Git.

شغّل التطبيق أو ابنِه باستخدام السكربتات المرفقة؛ فهي تمرّر الملف تلقائيًا عند وجوده.

يجب أن يحتوي Push payload القادم من الخادم على:

```json
{
  "data": {
    "conversationId": "CONVERSATION_ID"
  }
}
```

ويقبل التطبيق أيضًا المفاتيح: `conversation_id`, `chatId`, `chat_id`.

## بناء Android

لنسخة اختبار قابلة للتثبيت:

```powershell
BUILD_APK.cmd
```

لنسخة Release يلزم إعداد توقيع Android الحقيقي أولًا، ثم:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://go-wasl.com/api --dart-define-from-file=firebase_defines.json
```

## iOS

النسخة المرفوعة لا تحتوي على مجلد `ios/`. تعديلات Flutter المشتركة جاهزة لـAndroid وiOS، لكن اسم التطبيق الأصلي، App Icon، صلاحيات الكاميرا والميكروفون والصور، وAPNs تحتاج مجلد iOS الأصلي ومشروع Firebase الخاص بـiOS وجهاز macOS/Xcode. لا تشغّل `flutter create .` فوق المشروع قبل حفظ نسخة احتياطية.

## ملاحظات مهمة

- لم يتغير `applicationId` الخاص بـAndroid حتى لا تتغير هوية التطبيق الحالية.
- لا توجد أسرار Meta أو توكنات ثابتة داخل التطبيق.
- روابط الوسائط تستخدم طلبات مصادق عليها من `ApiClient`.
- ملف `pubspec.lock` سيُحدَّث تلقائيًا عند أول `flutter pub get` بسبب حزم الفيديو والملفات الجديدة.
