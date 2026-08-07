# Wasl Mobile — Implementation Notes

## الهوية

- الاسم الظاهر: `Wasl`
- شاشة البداية: الشعار فقط.
- الشعار المستخدم: `assets/branding/wasl_logo.png`
- أيقونات Android محدثة في مجلدات `mipmap-*`.
- `applicationId` بقي كما هو: `com.supporthub.support_hub`.

## الشبكة

- رابط API الافتراضي: `https://go-wasl.com/api`
- يمكن تغييره وقت البناء عبر `API_BASE_URL`.
- لم تتغير endpoints أو عقود البيانات.

## الدردشات

- واجهة جوال جديدة للقائمة والتفاصيل.
- فتح فوري مع `ChatCache` ثم تحديث خلفي.
- انتقال الإشعار يمرر `initialConversationId` ويمنع مسح الاختيار أثناء تحميل قائمة مختلفة.
- الوقت وحالة الرسالة في صف مستقل أسفل المحتوى لتفادي التداخل.
- التخصيص محفوظ محليًا باستخدام `SharedPreferences`.

## الوسائط

- الصور: اختيار/كاميرا، رفع، عرض، وفتح كامل.
- الفيديو: اختيار، رفع، تشغيل، تقدم، وملء الشاشة.
- الصوت: تسجيل AAC/M4A، رفع، تشغيل، seek، ومنع تشغيل أكثر من مقطع في الوقت نفسه.
- الملفات: اختيار، رفع، تنزيل وفتح باستخدام تطبيقات الجهاز.

نجاح رفع الوسائط يعتمد على أن endpoint الموجود `/conversations/:id/media` يقبل نوع الملف وحجمه وأن الخادم يعيد `mediaUrl` صالحًا.

## الإشعارات

- يدعم `onMessage`, `onMessageOpenedApp`, `getInitialMessage` وbackground handler.
- تسجيل وتحديث device token على endpoint الموجود `/notifications/devices`.
- فتح الدردشة مباشرة باستخدام `conversationId` حتى بعد استعادة جلسة المستخدم.
- إعداد Android notification channel باسم `wasl_messages`.

الإشعارات الخارجية تحتاج قيم Firebase حقيقية في `firebase_defines.json`، كما يجب أن يرسل الخادم Push payload يحتوي على معرف الدردشة.

## التحقق المنفذ في بيئة التسليم

- فحص توازن الأقواس لكل ملفات Dart.
- فحص المسارات النسبية للاستيراد.
- تحليل XML الخاص بـAndroid.
- تحليل `pubspec.yaml`.
- فحص تغطية مفاتيح الترجمة العربية المستخدمة حرفيًا.

لم تتوفر Flutter SDK في بيئة التسليم، لذلك لم يتم تشغيل `flutter analyze`, `flutter test` أو إنتاج APK جديد هنا. يجب تشغيلها في Android Studio بعد `flutter pub get`.

## iOS

مجلد `ios/` غير موجود في المشروع المرفوع. يلزم استعادة المجلد الأصلي لإكمال:

- `Info.plist`
- Display Name وApp Icon
- Camera/Microphone/Photos descriptions
- Push Notifications capability
- Background modes
- APNs وFirebase iOS app
- Bundle Identifier الصحيح
