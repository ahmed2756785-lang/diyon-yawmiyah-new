# ديون يومية

تطبيق Flutter عربي لإدارة ديون العملاء والمدفوعات اليومية.

## الوظائف
- إضافة العملاء والبحث بالاسم أو رقم الهاتف.
- تسجيل الديون والمدفوعات وعرض كشف حساب كل عميل.
- إدخال صوتي باللغة العربية مع استخراج المبلغ ومحاولة تحديد ما إذا كانت العبارة ديناً أم سداداً.
- ملخص إجمالي الديون والمدفوعات والأرصدة.
- تصدير واستيراد نسخة احتياطية بصيغة JSON.
- تخزين محلي باستخدام SQLite.

## التشغيل محلياً
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## بناء APK عبر GitHub Actions
يبدأ البناء عند كل push إلى فرع `main` أو يدوياً من تبويب Actions. ينشئ سير العمل ملفات Android الأساسية، ويشغّل التحليل والاختبارات، ثم يرفع ملفاً باسم `Diyon-Yawmiyah.apk`.

لإنشاء APK إصدار موقّع، أضف أسرار المستودع التالية من Settings → Secrets and variables → Actions:
- `ANDROID_KEYSTORE_BASE64`: محتوى ملف keystore بعد تحويله إلى Base64.
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

إذا لم تُضف أسرار التوقيع، ينشئ سير العمل APK تجريبياً (debug) بدلاً من APK إصدار موقّع.

## متطلبات
- Flutter stable
- Android minSdk 23
