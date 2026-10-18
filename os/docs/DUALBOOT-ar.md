# الإقلاع المزدوج بدون فلاشة (مسار متقدّم — خطِر)

> ⚠️ **اقرأ هذا أولاً**
> - هذا المسار يعدّل طريقة إقلاع جهازك. أي خطأ قد يجعل ويندوز لا يقلع حتى تصلحه.
> - **خذ نسخة احتياطية كاملة** (ملفاتك + صورة نظام إن أمكن) قبل البدء.
> - إن كان **BitLocker** مفعّلاً: احفظ مفتاح الاسترداد خارج الجهاز (حساب Microsoft أو ورقة). قد يطلبه ويندوز بعد تعديل الإقلاع.
> - السكربتات هنا **لا تنشئ ولا تحذف ولا تغيّر حجم أي قسم تلقائياً**. كل تعديل على الأقسام تفعله أنت يدوياً.
> - البديل الآمن تماماً هو **الجهاز الافتراضي** (`install-alhajda-vm.ps1`).

## الفكرة

بدلاً من فلاشة، نضع ملف ISO على قسم ويندوز (`C:\alhajda\alhajda.iso`) ونجعل GRUB يقلع منه مباشرة (loopback).
نظام casper في «الهجدة» يجد ملف ISO على قسم NTFS عبر `iso-scan/filename=` (مُضاف دعم `ntfs3` في initramfs).

## الخطوات

### 0) فحوصات
- ويندوز 10/11 بوضع **UEFI** (افتح `msinfo32` ← BIOS Mode = UEFI).
- **Secure Boot**: Grub2Win يحتاج غالباً تعطيله من إعدادات UEFI.
- **Fast Startup**: عطّله (السكربت يفعل ذلك بالخيار `-DisableFastStartup`).
- القسم الذي سيحمل ملف ISO **غير مشفّر** بـ BitLocker (إن كان C: مشفّراً استخدم قسم بيانات مثل D: عبر `-Drive D`).

### 1) تجهيز ملف ISO ومدخل GRUB (لا يغيّر شيئاً في الإقلاع)

PowerShell كمسؤول:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
iwr https://raw.githubusercontent.com/elyasalothman/kamputer-alhajda/main/os/windows/prepare-alhajda-dualboot.ps1 -OutFile $env:TEMP\prep.ps1
& $env:TEMP\prep.ps1 -DisableFastStartup
```

الناتج: `C:\alhajda\alhajda.iso` و `C:\alhajda\grub2win-alhajda-entry.cfg`.

### 2) إضافة قائمة إقلاع (يدوياً، على مسؤوليتك)

1. نزّل **Grub2Win** من https://sourceforge.net/projects/grub2win/ وثبّته (يضيف مدخلاً في مدير إقلاع ويندوز ولا يحذفه).
2. Grub2Win ← **Manage Boot Menu** ← **Add A New Entry** ← Type: **Custom code** ← الصق محتوى `grub2win-alhajda-entry.cfg`:

```
menuentry "Alhajda Live (ISO on Windows disk)" {
    insmod part_gpt
    insmod ntfs
    insmod iso9660
    insmod loopback
    set isofile="/alhajda/alhajda.iso"
    search --no-floppy --file --set=root $isofile
    loopback loop $isofile
    linux (loop)/casper/vmlinuz boot=casper iso-scan/filename=$isofile locale=ar_SA.UTF-8 quiet splash ---
    initrd (loop)/casper/initrd
}
```

3. احفظ وأعد التشغيل ← اختر **Grub2Win** ← **Alhajda Live**.

للتراجع: ألغِ تثبيت Grub2Win من «التطبيقات» واحذف `C:\alhajda`.

### 3) (اختياري) تثبيت دائم بجانب ويندوز — تجريبي

1. في ويندوز: «إدارة الأقراص» (`diskmgmt.msc`) ← زر يمين على C: ← **Shrink Volume** (25 GB أو أكثر).
2. زر يمين على المساحة غير المخصصة ← **New Simple Volume** ← اختر **Do not format this volume**.
3. أقلع إلى «الهجدة» الحي (الخطوة 2)، افتح الطرفية:

```bash
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME     # اعرف اسم القسم الجديد الفارغ (بدون FSTYPE)
sudo alhajda-install-disk --target /dev/nvme0n1p5
```

ضمانات المثبّت:
- يرفض الأقراص الكاملة، والأقسام المركّبة، وأي قسم فيه `ntfs` / `BitLocker` / `vfat` / `swap`.
- يطلب كتابة اسم القسم حرفياً قبل المسح.
- يضيف GRUB في `\EFI\ubuntu` في قسم EFI الموجود، ولا يلمس `\EFI\Microsoft`، ويضيف ويندوز إلى قائمة GRUB (os-prober).

> هذا المثبّت **لم يُختبر بعد على جهاز حقيقي**. جرّبه أولاً داخل جهاز افتراضي إن أمكن.
