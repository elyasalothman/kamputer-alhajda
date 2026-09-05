# كمبيوتر الهجدة (kamputer-alhajda)

مثبّت ويندوز وتطبيق سطح مكتب شخصي لإلياس بن عثمان العثمان فقط. ليس منتجاً عاماً.

تطبيق سطح مكتب مبني على **Electron**، يعرض لوحة ترحيب شخصية وحالة النظام (المعالج، الذاكرة، مدة التشغيل، …) بواجهة عربية من اليمين إلى اليسار. يُحزَّم للتوزيع كمثبّت ويندوز (NSIS) باسم `Kamputer-Alhajda-<version>-Setup.exe`.

## المتطلبات

- [Node.js](https://nodejs.org/) الإصدار 20 أو أحدث
- npm

## التطوير

```bash
npm install     # تثبيت الاعتماديات
npm start       # تشغيل التطبيق
```

على أنظمة Linux بدون شاشة (مثل خوادم CI أو بيئات الوكيل السحابي) شغّل عبر خادم عرض افتراضي:

```bash
xvfb-run -a npm start
```

## بناء مثبّت ويندوز

يُبنى المثبّت على نظام ويندوز (أو عبر GitHub Actions):

```bash
npm run dist:win
```

الناتج يوضع في مجلد `dist/` باسم `Kamputer-Alhajda-1.0.0-Setup.exe`.

يوجد سير عمل GitHub Actions في `.github/workflows/build.yml` يبني المثبّت تلقائياً على `windows-latest` ويرفعه كأرتيفاكت.

## بنية المشروع

```
src/
  main/
    main.js       عملية Electron الرئيسية + جمع معلومات النظام
    preload.js    جسر آمن (contextBridge) بين الواجهة والعملية الرئيسية
  renderer/
    index.html    واجهة المستخدم (RTL)
    styles.css    التنسيقات
    renderer.js   منطق الواجهة
```

## التوزيع

يُنشر المثبّت النهائي عبر [إصدارات GitHub](https://github.com/elyasalothman/kamputer-alhajda/releases). راجع `DOWNLOAD.txt` لرابط التنزيل المباشر والبصمة (sha256).
