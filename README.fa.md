Failed to create stream fd: Operation not permitted
Failed to create stream fd: Operation not permitted
Failed to create stream fd: Operation not permitted
# openwrt-iran-split-tunnel

<p align="center">
  <a href="README.md">🇬🇧 English</a>
  &nbsp;|&nbsp;
  <strong><img src="https://commons.wikimedia.org/wiki/Special:Redirect/file/State_flag_of_the_Imperial_State_of_Iran_(with_standardized_lion_and_sun).svg?width=48" width="28" alt="پرچم شیر و خورشید ایران"> فارسی</strong>
</p>

[![ShellCheck](https://github.com/MehrooExplains/openwrt-iran-split-tunnel/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/MehrooExplains/openwrt-iran-split-tunnel/actions/workflows/shellcheck.yml)

تفکیک خودکار ترافیک **ایران / خارج** روی OpenWrt با استفاده از **Momo + sing-box + Hysteria2**.

این پروژه برای سناریویی ساخته شده که در آن:

- دامنه‌ها و IPهای ایرانی مستقیماً از اینترنت اصلی باز شوند.
- ترافیک خارجی از Hysteria2 عبور کند.
- TCP و UDP هر دو پوشش داده شوند.
- DNS سایت‌های خارجی از داخل تونل Resolve شود تا DNS pollution باعث خراب شدن دسترسی نشود.
- نصب تا حد ممکن بین مدل‌ها و معماری‌های مختلف OpenWrt خودکار باشد.

> وضعیت پروژه: نسخه عمومی اولیه `0.1.x`. قبل از استفاده روی روتر اصلی، بهتر است روی دستگاهی که امکان بازیابی آن را دارید تست شود.

## نحوه کار

```text
LAN / Wi-Fi
     |
     v
    Momo
     |
     v
  sing-box
   /     \
  /       \
ایران      خارج
DIRECT    Hysteria2
```

مسیر کلی:

- IPها و دامنه‌های ایرانی → **DIRECT**
- سایر ترافیک IPv4 → **Hysteria2**
- TCP → Momo Redirect → sing-box
- UDP → Momo TPROXY → sing-box
- DNS ایران → مستقیم
- DNS خارج → Cloudflare DoH از داخل Hysteria2

Ruleهای ایران از پروژه [Chocolate4U/Iran-sing-box-rules](https://github.com/Chocolate4U/Iran-sing-box-rules) دریافت می‌شوند:

```text
geosite-ir.srs
geoip-ir.srs
```

## پشتیبانی سیستم

Installer برای این خانواده‌ها طراحی شده است:

- OpenWrt `24.10` با `opkg`
- OpenWrt `25.12` با `apk`
- Snapshotهای سازگار
- `firewall4`
- `nftables`
- معماری‌هایی که Momo برای آن‌ها پکیج رسمی منتشر کرده باشد

Installer به‌صورت خودکار تلاش می‌کند موارد زیر را تشخیص دهد:

- نسخه OpenWrt
- package manager یعنی `apk` یا `opkg`
- معماری پکیج OpenWrt از `DISTRIB_ARCH`
- مدل دستگاه
- RAM و فضای آزاد Overlay
- پکیج مناسب Momo برای معماری و نسخه OpenWrt

پروژه به مدل خاصی از Linksys، TP-Link، Xiaomi، GL.iNet یا x86 محدود نیست. دستگاه باید منابع کافی برای اجرای Momo و sing-box داشته باشد.

## پیش‌نیازها

- دسترسی SSH با کاربر root به روتر قابل‌بازیابی
- OpenWrt نسخه `24.10`، `25.12` یا Snapshot سازگار
- `firewall4` و جدول nftables با نام `inet fw4`
- معماری دارای فایل رسمی در Releaseهای Momo
- فضای Overlay کافی برای Momo، LuCI، sing-box و Ruleها
- URI معتبر با ابتدای `hysteria2://` یا `hy2://`
- اینترنت فعال هنگام نصب

پیش از نصب از روتر بکاپ بگیرید. نصب اولیه روی روتر دوردست بدون دسترسی Failsafe،
Serial یا Firmware Recovery توصیه نمی‌شود.

### ترتیب بررسی پیش‌نیازها

پیش از دانلود Momo، دریافت اطلاعات اتصال یا تغییر تنظیمات Tunnel، Installer:

۱. نسخه OpenWrt، معماری پکیج و فضای آزاد Overlay را اعتبارسنجی می‌کند.

۲. تک‌تک پکیج‌های لازم را با `apk` یا `opkg` بررسی می‌کند.

۳. فقط زمانی `curl` را به پیش‌نیازها اضافه می‌کند که Downloader دیگری موجود نباشد.

۴. فقط در صورت وجود پکیج مفقود، Package Index را به‌روزرسانی می‌کند.

۵. فقط پیش‌نیازهای مفقود را نصب می‌کند.

۶. Commandهای ضروری، Downloader، `firewall4` و جدول `inet fw4` را بررسی می‌کند.

۷. فقط پس از موفقیت همه بررسی‌ها وارد دانلود و پیکربندی Momo می‌شود.

شکست هر پیش‌نیاز باعث توقف Installer پیش از تغییر تنظیمات Momo خواهد شد.

## تغییراتی که Installer انجام می‌دهد

Installer:

- پیش‌نیازهای OpenWrt را بررسی و فقط موارد مفقود را نصب می‌کند؛ سپس فایل‌های رسمی Momo/LuCI را نصب می‌کند.
- پروفایل `/etc/momo/profiles/iran-split-hy2.json` را می‌سازد.
- Ruleهای ایران را در `/etc/momo/rules/` قرار می‌دهد.
- DNS Hijack، TCP Redirect و UDP TPROXY را برای LAN تشخیص‌داده‌شده تنظیم می‌کند.
- دستورهای `openwrt-iran-split-update` و `openwrt-iran-split-health` را نصب می‌کند.
- آپدیت هفتگی Ruleها را در Crontab کاربر root ثبت می‌کند.
- State و Backupها را در `/etc/openwrt-iran-split-tunnel/` نگه می‌دارد.

تنظیمات موجود Momo و فایل Profile پیش از جایگزینی پشتیبان‌گیری می‌شوند.

## نصب

با SSH وارد روتر شوید:

```sh
ssh root@192.168.1.1
```

اگر IP روتر شما متفاوت است، IP صحیح را جایگزین کنید.

سپس:

```sh
wget -O /tmp/iran-split-install.sh \
  https://raw.githubusercontent.com/MehrooExplains/openwrt-iran-split-tunnel/main/install.sh && \
sh /tmp/iran-split-install.sh
```

Installer در زمان نصب لینک Hysteria2 را درخواست می‌کند:

```text
Paste your Hysteria2 URI:
> hysteria2://...
```

URI واقعی، پسورد و اطلاعات خصوصی سرور شما در GitHub ذخیره نمی‌شود و فقط روی روتر پردازش می‌شود.

### نصب غیرتعاملی

```sh
HY2_URI='hysteria2://...' sh /tmp/iran-split-install.sh
```

## DNS

یکی از مشکلات رایج این است که تونل متصل است و IP خارجی دیده می‌شود، ولی سایت‌هایی مانند YouTube باز نمی‌شوند. معمولاً دلیل آن DNS مستقیم یا آلوده است.

پروژه برای IPv4 یک DNS inbound در sing-box ایجاد می‌کند:

```text
0.0.0.0:1053
```

Momo درخواست‌های DNS کلاینت‌های LAN را به این inbound هدایت می‌کند.

```text
Client DNS
    |
    v
Momo DNS Hijack
    |
    v
sing-box
   /     \
Iran   Foreign
Direct  Cloudflare DoH
        through Hysteria2
```

اگر در OpenWrt گزینه دیگری با عنوان **DNS Redirect** فعال باشد، بهتر است همزمان با DNS Hijack خود Momo استفاده نشود، چون دو سیستم Hijack همزمان می‌توانند باعث رفتار غیرقابل پیش‌بینی شوند.

## Ruleهای ایران

Ruleها روی روتر در این مسیرها قرار می‌گیرند:

```text
/etc/momo/rules/geosite-ir.srs
/etc/momo/rules/geoip-ir.srs
```

برای آپدیت دستی:

```sh
openwrt-iran-split-update
```

Updater ابتدا فایل جدید را دانلود و بررسی می‌کند و سپس Rule قبلی را جایگزین می‌کند. اگر دانلود یا اعتبارسنجی شکست بخورد، فایل سالم فعلی حفظ می‌شود.

## بررسی سلامت

بعد از نصب:

```sh
openwrt-iran-split-health
```

Health check موارد اصلی مانند Momo، sing-box، nftables، policy routing و listenerهای DNS/Redirect/TPROXY را بررسی می‌کند.

برای بررسی IP خروجی از یک دستگاه متصل به روتر:

```sh
curl -4 https://api.ipify.org
```

برای ترافیک خارجی باید IP خروجی Hysteria2 دیده شود.

دستورهای مفید برای بررسی Runtime:

```sh
/etc/init.d/momo status
logread | grep -i momo
nft list table inet momo
ip rule show
ip route show table 80
busybox netstat -lnptu | grep -E ':1053|:7891|:7892'
```

## IPv6

در نسخه `0.1.x`، Proxy کردن IPv6 و IPv6 DNS Hijack به‌صورت پیش‌فرض خاموش است. هدف فعلی پروژه یک مسیر IPv4 قابل پیش‌بینی و پایدار است.

اگر شبکه شما IPv6 عمومی دارد، قبل از اتکا به تونل برای IPv6 باید تنظیمات Dual Stack را جداگانه بررسی کنید.

## روترهای کم‌حافظه

Installer مقدار RAM و فضای Overlay را بررسی می‌کند. این پروژه عمداً:

- Storage را پارتیشن‌بندی نمی‌کند.
- USB را فرمت نمی‌کند.
- Swap را خودکار ایجاد نمی‌کند.

چون Installer شبکه قرار نیست به‌طور اتفاقی نقش ابزار بازیابی اطلاعات را هم به شما تحمیل کند.

## Backup

قبل از تغییر تنظیمات مهم، فایل‌های موجود در مسیر زیر پشتیبان‌گیری می‌شوند:

```text
/etc/openwrt-iran-split-tunnel/backups/
```

## حذف

```sh
wget -O /tmp/iran-split-uninstall.sh \
  https://raw.githubusercontent.com/MehrooExplains/openwrt-iran-split-tunnel/main/uninstall.sh && \
sh /tmp/iran-split-uninstall.sh
```

Uninstaller به‌صورت عمدی Momo، LuCI Momo و sing-box را حذف نمی‌کند، چون ممکن است برای تنظیمات دیگری نیز مورد استفاده باشند.

## رفع اشکال

### نسخه OpenWrt پشتیبانی نمی‌شود یا فایل Momo پیدا نمی‌شود

```sh
. /etc/openwrt_release
printf 'release=%s arch=%s\n' "$DISTRIB_RELEASE" "$DISTRIB_ARCH"
```

معماری و شاخه نسخه باید در Release رسمی Momo وجود داشته باشند. پکیج معماری
دیگر را روی روتر نصب نکنید.

### Momo اجرا نمی‌شود

```sh
/etc/init.d/momo status
logread | grep -iE 'momo|sing-box'
sing-box check -c /etc/momo/profiles/iran-split-hy2.json
```

آدرس سرور Hysteria2، پسورد، SNI، پارامترهای Obfuscation و ساعت روتر را بررسی
کنید. نادرست‌بودن زمان دستگاه می‌تواند TLS را خراب کند.

### ترافیک ایران از Proxy عبور می‌کند

```sh
openwrt-iran-split-update
ls -lh /etc/momo/rules/
logread | grep -iE 'momo|sing-box|rule'
```

آپدیت Ruleها را اجرا، وجود فایل‌ها را بررسی و Logها را مطالعه کنید.

### دامنه‌های خارجی باز نمی‌شوند

Listenerهای پورت `1053`، `7891` و `7892` را بررسی کنید. برنامه‌های Proxy یا DNS
Redirect رقیب را موقتاً غیرفعال کنید. مگر با تنظیم آگاهانه، فقط یک سرویس باید
DNS کلاینت‌های LAN را Hijack کند.

### بازگشت به وضعیت قبل

Uninstaller را اجرا کنید تا تنظیمات پروژه غیرفعال شوند. Backupها برای بازیابی
دستی در `/etc/openwrt-iran-split-tunnel/backups/` باقی می‌مانند. پکیج‌های Momo
و sing-box عمداً حذف نمی‌شوند.

## بررسی توسعه

```sh
shellcheck -s sh install.sh update-rules.sh health-check.sh uninstall.sh
sh -n install.sh update-rules.sh health-check.sh uninstall.sh
```

GitHub Actions در هر Push یا Pull Request مرتبط ShellCheck را اجرا می‌کند.

## امنیت

اطلاعات زیر را در Issue، Commit یا فایل عمومی قرار ندهید:

```text
Hysteria2 URI واقعی
Password
Certificate
API Token
Backup کامل روتر
```

Momo از Releaseهای رسمی [nikkinikki-org/OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo) دریافت می‌شود.

## محدوده پروژه

نسخه فعلی عمداً روی یک سناریوی مشخص تمرکز دارد:

```text
OpenWrt + Momo + sing-box + Hysteria2
Iran DIRECT / Foreign Proxy
```

## License

این پروژه تحت [MIT License](LICENSE) منتشر شده است.
