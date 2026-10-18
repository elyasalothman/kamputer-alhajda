# نظام «الهجدة» (Alhajda OS)

توزيعة لينكس شخصية مبنية على **Ubuntu 24.04 LTS (Noble)**، عربية بالكامل من أول إقلاع.

> هذا المجلد `os/` مستقل عن تطبيق ويندوز «كمبيوتر الهجدة» الموجود في بقية المستودع، ولا يغيّر أي ملف منه.

## ماذا يحتوي النظام

| البند | التفاصيل |
|---|---|
| الأساس | Ubuntu 24.04 LTS، نواة `linux-generic` |
| سطح المكتب | XFCE خفيف (Xubuntu core) + LightDM |
| اللغة | العربية افتراضياً (`ar_SA.UTF-8`) والواجهة من اليمين لليسار، والإنجليزية متوفرة |
| الخطوط | Noto Naskh Arabic، Noto Kufi Arabic، Noto Sans Arabic UI، Noto Color Emoji |
| لوحة المفاتيح | عربي (`ara`) + إنجليزي (`us`)، التبديل بـ **Alt+Shift** |
| المنطقة الزمنية | Asia/Riyadh |
| المتصفح | Firefox (حزمة deb من Mozilla، بدون Snap) بواجهة عربية، الصفحة الرئيسية alhajda.com وشريط إشارات «الهجدة» |
| برامج ويندوز | Wine (64 و32 بت) + winetricks، و **Bottles** يُثبَّت تلقائياً من Flathub عند أول اتصال بالإنترنت (أو مدمج إذا بُني بخيار `bottles_preinstall`) |
| اختصارات | «الهجدة» alhajda.com، «سوق الهجدة» market.alhajda.com، «أخبار الهجدة» news.alhajda.com، «برامج ويندوز (Bottles)» — على سطح المكتب وفي القائمة |
| الهوية | الاسم في `/etc/os-release` (`NAME="الهجدة"`, `ID=alhajda`, `ID_LIKE="ubuntu debian"`)، خلفية الهجدة، شعار في شاشة الإقلاع (Plymouth)، اسم «Alhajda» في قائمة GRUB |

## طرق التثبيت بدون فلاشة USB

### 1) الطريقة الموصى بها: جهاز افتراضي بخطوة واحدة (آمنة تماماً)

لا تلمس أقسام القرص ولا مدير الإقلاع. افتح **PowerShell كمسؤول** (Run as Administrator) والصق:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
iwr https://raw.githubusercontent.com/elyasalothman/kamputer-alhajda/main/os/windows/install-alhajda-vm.ps1 -OutFile $env:TEMP\install-alhajda-vm.ps1
& $env:TEMP\install-alhajda-vm.ps1
```

السكربت `os/windows/install-alhajda-vm.ps1`:
1. يتحقق من Hyper-V ويفعّله إن كان معطّلاً (ويندوز Pro/Enterprise/Education). بعد التفعيل يطلب إعادة التشغيل **ويكمل تلقائياً** بعد تسجيل الدخول.
2. على **ويندوز Home** (لا يوجد Hyper-V) يستخدم VirtualBox، ويعرض تثبيته عبر `winget` إن لم يكن موجوداً.
3. ينزّل أحدث إصدار `os-v*` من [Releases](https://github.com/elyasalothman/kamputer-alhajda/releases)، يدمج الأجزاء `.partNN` ويتحقق من SHA256.
4. ينشئ الجهاز (Hyper-V الجيل 2 / UEFI) ويكبّر القرص إلى 40 GB (يتوسع النظام تلقائياً في أول إقلاع) ثم يشغّله.

خيارات مفيدة:

```powershell
& $env:TEMP\install-alhajda-vm.ps1 -MemoryGB 6 -CPUCount 4 -DiskGB 80
& $env:TEMP\install-alhajda-vm.ps1 -Hypervisor VirtualBox
& $env:TEMP\install-alhajda-vm.ps1 -LocalImage D:\alhajda-1.0.0-hyperv.vhdx.zip   # بدون تحميل
& $env:TEMP\install-alhajda-vm.ps1 -Force       # استبدال جهاز موجود بنفس الاسم
```

**بيانات الدخول في الجهاز الافتراضي:** المستخدم `alhajda` وكلمة المرور `alhajda` (دخول تلقائي). **غيّرها** بالأمر `passwd`.

### 2) مسار متقدّم وخطِر: الإقلاع من القرص الداخلي (Dual-boot) بدون فلاشة

> ⚠️ **تحذير:** أي تعديل على الإقلاع قد يمنع ويندوز من الإقلاع إن حدث خطأ. **خذ نسخة احتياطية كاملة**، واحفظ **مفتاح استرداد BitLocker** خارج الجهاز. السكربتات هنا **لا تغيّر الأقسام تلقائياً أبداً**.

التفاصيل الكاملة خطوة بخطوة: [`docs/DUALBOOT-ar.md`](docs/DUALBOOT-ar.md). باختصار:

1. `os/windows/prepare-alhajda-dualboot.ps1` (كمسؤول) يفحص الجهاز (UEFI، BitLocker، Fast Startup، المساحة)، ينزّل ملف ISO إلى `C:\alhajda\alhajda.iso`، ويكتب مدخل GRUB جاهزاً (`grub2win-alhajda-entry.cfg`).
2. تثبّت **Grub2Win** بنفسك وتضيف المدخل كـ Custom code ← تقلع إلى «الهجدة» الحي من ملف ISO (GRUB loopback).
3. (اختياري) للتثبيت الدائم: تنشئ قسماً **فارغاً** يدوياً من «إدارة الأقراص» في ويندوز، ثم من داخل الجلسة الحية:
   `sudo alhajda-install-disk --target /dev/<القسم>` — يرفض أي قسم فيه NTFS/BitLocker/EFI، ويطلب كتابة اسم القسم حرفياً قبل المسح، ويضيف GRUB في `\EFI\ubuntu` دون لمس ملفات ويندوز. **تجريبي ولم يُختبر على جهاز حقيقي بعد.**

### 3) ملف ISO

ملف `alhajda-<الإصدار>-amd64.iso` قابل للإقلاع BIOS وUEFI (جلسة حية Live). يمكن استخدامه في أي برنامج أجهزة افتراضية، أو بالمسار المتقدّم أعلاه، أو على فلاشة لمن يريد.
إذا كان الملف مقسوماً (`.part00`, `.part01`…) فادمجه في ويندوز:

```bat
copy /b alhajda-1.0.0-amd64.iso.part00 + alhajda-1.0.0-amd64.iso.part01 alhajda-1.0.0-amd64.iso
```

## الملفات الناتجة

| الملف | الاستخدام |
|---|---|
| `alhajda-<v>-amd64.iso` | جلسة حية (Live) BIOS/UEFI |
| `alhajda-<v>-hyperv.vhdx.zip` | قرص Hyper-V (الجيل 2، UEFI) |
| `alhajda-<v>-virtualbox.vmdk` | قرص VirtualBox (streamOptimized؛ السكربت يحوّله إلى VDI) |
| `alhajda-<v>.qcow2` | QEMU/KVM، UTM، Proxmox |
| `SHA256SUMS` | بصمات الملفات **الكاملة** (قبل التقسيم) |

GitHub يحدّ كل ملف في الإصدارات بـ 2 GB، لذلك أي ملف أكبر يُقسَّم إلى أجزاء 1900 MB، والسكربتات تدمجها تلقائياً.

## البناء (GitHub Actions)

الملف: `.github/workflows/os-build.yml` — يعمل يدوياً فقط (workflow_dispatch) من تبويب **Actions ← Build Alhajda OS ← Run workflow**:

- `version`: رقم الإصدار (افتراضي 1.0.0)
- `publish`: نشر إصدار تجريبي `os-v<version>` بالملفات (يلزم لسكربتات ويندوز)
- `bottles_preinstall`: دمج Bottles داخل الصورة (+1.5 GB تقريباً)

مراحل البناء:

1. `os/build/build-rootfs.sh` — `debootstrap` لـ noble ثم `chroot-setup.sh` (الحزم، اللغة، الهوية).
2. `os/build/build-iso.sh` — squashfs (xz) + casper + `grub-mkrescue` (BIOS+UEFI).
3. `os/build/build-disk.sh` — قرص GPT (BIOS boot + EFI + ext4)، GRUB لـ BIOS وUEFI (shim موقّع)، ثم تحويل إلى VHDX/VMDK/qcow2.
4. `os/build/smoke-test.sh` — إقلاع بدون شاشة في QEMU (القرص BIOS، VHDX عبر UEFI، ISO) وانتظار رسالة `ALHAJDA_BOOT_OK` على المنفذ التسلسلي (تعني أن LightDM يعمل)، مع لقطة شاشة لكل اختبار في artifact `alhajda-smoke-logs`.
5. `os/build/package.sh` — ضغط، SHA256، تقسيم.

البناء محلياً (Ubuntu 24.04، يحتاج ~40 GB):

```bash
sudo apt install debootstrap squashfs-tools xorriso mtools grub-pc-bin grub-efi-amd64-bin gdisk dosfstools qemu-utils qemu-system-x86 ovmf socat imagemagick zip rsync
export WORK=/srv/alhajda ALHAJDA_VERSION=1.0.0
sudo -E os/build/build-rootfs.sh && sudo -E os/build/build-iso.sh && sudo -E os/build/build-disk.sh
os/build/smoke-test.sh disk-bios bios disk $WORK/alhajda-1.0.0.raw raw
```

## هيكل المجلد

```
os/
  build/            سكربتات البناء والاختبار
  branding/         الشعار، الخلفية (SVG)، os-release، سياسات Firefox
  rootfs-overlay/   ملفات تُنسخ كما هي إلى النظام (خدمات systemd، الاختصارات، المثبّت)
  windows/          سكربتات PowerShell للتثبيت بدون فلاشة
  docs/             شرح الإقلاع المزدوج
```

## ملاحظات وحدود معروفة

- لا يوجد مثبّت رسومي (Ubiquity/Calamares) في هذا الإصدار الأول؛ الطريقة الأساسية هي القرص الافتراضي الجاهز، والتثبيت الدائم عبر `alhajda-install-disk` تجريبي.
- Chromium في أوبونتو متاح كـ Snap فقط، لذلك اعتمدنا Firefox (deb).
- Secure Boot: القرص الافتراضي يحمل shim موقّعاً من Microsoft، لكن السكربت يعطّل Secure Boot في Hyper-V للتوافق. ملف ISO غير موقّع (عطّل Secure Boot عند إقلاعه).
- Hyper-V «Enhanced Session» غير مدعوم؛ الدقة تُضبط من إعدادات العرض داخل النظام.
- قائمة GRUB تعرض «Alhajda» بالحروف اللاتينية لأن خطوط GRUB لا تدعم تشكيل العربية.
