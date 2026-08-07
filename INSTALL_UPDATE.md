# تثبيت تحديث Wasl Mobile 2.6.0+35

الأفضل استخدام حزمة المشروع الكاملة. لاستخدام هذه الحزمة الجزئية:

1. خذ نسخة احتياطية من المشروع.
2. انسخ جميع الملفات والمجلدات من هذه الحزمة فوق جذر المشروع الحالي.
3. احذف الملف المولّد القديم إن كان موجودًا:

`android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`

4. احذف مجلدات `.dart_tool`, `build`, `android/.gradle` إن كانت موجودة.
5. نفّذ `flutter pub get` حتى تتولد تسجيلات إضافات الفيديو والملفات الجديدة.
6. شغّل `CHECK_PROJECT.cmd` ثم `RUN_ANDROID.cmd`.
7. جهّز `firebase_defines.json` إن كنت تريد Push Notifications خارج التطبيق.

مجلد iOS غير موجود في المشروع الأصلي، لذلك لا تشمل الحزمة إعدادات Xcode أو APNs.
