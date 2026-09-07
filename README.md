# كمبيوتر الهجدة (kamputer-alhajda)

مثبّت ويندوز وتطبيق سطح مكتب شخصي لإلياس بن عثمان العثمان فقط. ليس منتجاً عاماً.

تطبيق سطح مكتب شخصي يعرض لوحة ترحيب وحالة النظام (المعالج، الذاكرة، مدة التشغيل، …) بواجهة عربية من اليمين إلى اليسار. الاسم الظاهر في ويندوز هو **كمبيوتر الهجدة**. الملف التنفيذي المعبّأ هو `Kamputer-Alhajda.exe` — ليس `electron.exe`.

يُحزَّم للتوزيع كمثبّت NSIS (`Kamputer-Alhajda-<version>-Setup.exe`) أو حزمة محمولة (`Kamputer-Alhajda-<version>-win-x64.zip`).

## المتطلبات

- [Node.js](https://nodejs.org/) الإصدار 20 أو أحدث
- npm

## التشغيل على ويندوز (بعد التحميل)

من مجلد الحزمة المحمولة:

```bat
START.bat
```

أو انقر `Kamputer-Alhajda.exe`. اختياري: `put-shortcut.ps1` يضع اختصاراً باسم كمبيوتر الهجدة على سطح المكتب وقائمة ابدأ.

لا تشغّل `electron.exe`.

## التطوير

```bash
npm install     # تثبيت الاعتماديات
npm start       # تشغيل التطبيق (تطوير فقط)
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

الناتج في `dist/`:

- `Kamputer-Alhajda-1.0.0-Setup.exe` — المثبّت (يُثبِّت `Kamputer-Alhajda.exe`)
- `Kamputer-Alhajda-1.0.0-win-x64.zip` — الحزمة المحمولة (شغّل `START.bat` أو `Kamputer-Alhajda.exe`)

يوجد سير عمل GitHub Actions في `.github/workflows/build.yml` يبني المثبّت تلقائياً على `windows-latest` ويرفعه كأرتيفاكت.

## بنية المشروع

```
START.bat              تشغيل Kamputer-Alhajda.exe
put-shortcut.ps1       اختصارات سطح المكتب / قائمة ابدأ
scripts/afterPack.js   يرفض بقاء electron.exe بعد التعبئة
src/
  main/
    main.js       العملية الرئيسية + اسم التطبيق / AppUserModelId
    preload.js    جسر آمن (contextBridge)
  renderer/
    index.html    واجهة المستخدم (RTL)
    styles.css    التنسيقات
    renderer.js   منطق الواجهة
```

## التوزيع

يُنشر المثبّت النهائي عبر [إصدارات GitHub](https://github.com/elyasalothman/kamputer-alhajda/releases). راجع `DOWNLOAD.txt` لرابط التنزيل المباشر والبصمة (sha256).
