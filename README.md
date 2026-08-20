# openwrt-iran-split-tunnel

تفکیک خودکار ترافیک **ایران / خارج** روی OpenWrt با استفاده از **Momo + sing-box + Hysteria2**.

این پروژه برای کسانی ساخته شده که می‌خواهند:

- سایت‌ها و IPهای ایرانی مستقیم از اینترنت خودشان باز شوند.
- ترافیک خارج از ایران از Hysteria2 عبور کند.
- تنظیمات تا جای ممکن خودکار باشد.
- روی مدل‌های مختلف روتر OpenWrt قابل استفاده باشد و به یک دستگاه خاص وابسته نباشد.

> وضعیت پروژه: نسخه عمومی اولیه `0.1.x`. بهتر است قبل از استفاده روی روتر اصلی، روی دستگاهی که امکان بازیابی آن را دارید تست کنید.

---

## این پروژه دقیقاً چه کاری انجام می‌دهد؟

بعد از نصب، مسیر ترافیک به شکل زیر خواهد بود:

```text
دستگاه‌های LAN / Wi‑Fi
        |
        v
      Momo
        |
        v
    sing-box
      /   \
     /     \
 ایران      خارج
 DIRECT    Hysteria2
```

به زبان ساده:

- IPها و دامنه‌های ایرانی → **DIRECT**
- سایر ترافیک IPv4 → **Hysteria2**
- TCP → از طریق Momo Redirect وارد sing-box می‌شود.
- UDP → از طریق Momo TPROXY وارد sing-box می‌شود.
- DNS سایت‌های خارجی → Cloudflare DoH از داخل Hysteria2
- DNS سایت‌های ایرانی → مستقیم
- پنل گرافیکی Momo در LuCI باقی می‌ماند.

لیست IP و دامنه‌های ایران از پروژه زیر دریافت می‌شود:

[Chocolate4U/Iran-sing-box-rules](https://github.com/Chocolate4U/Iran-sing-box-rules)

فایل‌های اصلی مورد استفاده:

```text
geoip-ir.srs
geosite-ir.srs
```

---

## مناسب چه کسانی است؟

اگر OpenWrt دارید و می‌خواهید مثلاً:

```text
digikala.com  → اینترنت مستقیم
varzesh3.com  → اینترنت مستقیم
سایت‌های بانکی → اینترنت مستقیم

YouTube       → Hysteria2
Facebook      → Hysteria2
سایت‌های خارجی → Hysteria2
```

این پروژه برای همین سناریو ساخته شده است.

نیازی نیست برای هر دامنه به‌صورت دستی Rule بسازید.

---

## سیستم‌های پشتیبانی‌شده

Installer فعلاً برای این محیط‌ها طراحی شده است:

- OpenWrt 24.10 با `opkg`
- OpenWrt 25.12 با `apk`
- نسخه‌های سازگار OpenWrt SNAPSHOT
- `firewall4`
- `nftables`
- معماری‌هایی که Momo برای آن‌ها پکیج رسمی منتشر کرده باشد

Installer تلاش می‌کند این موارد را خودش تشخیص دهد:

- نسخه OpenWrt
- `apk` یا `opkg`
- معماری CPU از `DISTRIB_ARCH`
- فایل مناسب Momo برای همان معماری
- شبکه LAN
- مقدار RAM
- فضای آزاد Overlay
- وجود firewall4 و nftables

بنابراین پروژه به مدل خاصی مثل Linksys، TP-Link، Xiaomi یا دستگاه x86 محدود نشده است.

البته دستگاه باید RAM و Flash کافی برای اجرای Momo و sing-box داشته باشد. روی سخت‌افزارهای بسیار قدیمی با حافظه بسیار کم، معجزه‌ای در کار نیست.

---

# نصب

ابتدا با SSH وارد OpenWrt شوید:

```sh
ssh root@192.168.1.1
```

اگر IP روتر شما چیز دیگری است، همان IP را وارد کنید.

سپس این دستور را اجرا کنید:

```sh
wget -O /tmp/iran-split-install.sh \
  https://raw.githubusercontent.com/MehrooExplains/openwrt-iran-split-tunnel/main/install.sh && \
sh /tmp/iran-split-install.sh
```

Installer در طول نصب از شما لینک Hysteria2 می‌خواهد:

```text
Paste your Hysteria2 URI:
```

مثال ساختار لینک:

```text
hysteria2://password@example.com:443?...
```

لینک واقعی، پسورد و اطلاعات سرور شما **در GitHub آپلود نمی‌شود** و فقط روی خود روتر پردازش می‌شود.

---

## نصب بدون سؤال Interactive

اگر می‌خواهید لینک را مستقیم به Installer بدهید:

```sh
HY2_URI='hysteria2://...' sh /tmp/iran-split-install.sh
```

لینک واقعی خودتان را به جای `hysteria2://...` قرار دهید.

---

# DNS چگونه تنظیم می‌شود؟

یکی از مشکلات رایج این است که VPN وصل است و IP خارجی نمایش داده می‌شود، ولی سایت‌هایی مثل YouTube باز نمی‌شوند.

دلیل معمول این مشکل DNS مستقیم یا آلوده است.

این پروژه برای IPv4 یک DNS inbound روی این آدرس ایجاد می‌کند:

```text
0.0.0.0:1053
```

سپس Momo درخواست‌های DNS دستگاه‌های LAN را به آن هدایت می‌کند.

مسیر DNS به شکل زیر است:

```text
DNS دستگاه
    |
    v
Momo DNS Hijack
    |
    v
sing-box
   /   \
  /     \
ایران   خارج
Direct  Cloudflare DoH
        از داخل HS2
```

به این ترتیب سایت خارجی با IP اشتباه یا DNS فیلترشده Resolve نمی‌شود.

---

## نکته مهم درباره DNS Redirect در OpenWrt

اگر Firmware شما در این مسیر گزینه‌ای به نام **DNS Redirect** دارد:

```text
Network → DHCP and DNS → DNS Redirect
```

هنگام استفاده از DNS Hijack خود Momo بهتر است Redirect دوم را همزمان فعال نکنید.

داشتن دو سیستم مختلف برای Hijack کردن DNS می‌تواند باعث رفتار عجیب، DNS pollution یا Route اشتباه شود.

---

# Ruleهای ایران

Ruleها روی خود روتر ذخیره می‌شوند:

```text
/etc/momo/rules/geosite-ir.srs
/etc/momo/rules/geoip-ir.srs
```

این Ruleها مشخص می‌کنند کدام دامنه‌ها و IPها مربوط به ایران هستند و باید مستقیم باز شوند.

---

## آپدیت خودکار Rule ایران

Installer یک Cron هفتگی ایجاد می‌کند.

زمان پیش‌فرض:

```text
یکشنبه ساعت 04:17
```

آپدیت به‌صورت امن انجام می‌شود:

```text
دانلود فایل جدید
      ↓
تست و Validation
      ↓
در صورت سالم بودن
      ↓
جایگزینی Rule قبلی
```

اگر فایل دانلودشده خراب باشد، Rule سالم فعلی حذف نمی‌شود.

برای آپدیت دستی:

```sh
openwrt-iran-split-update
```

---

# بررسی سلامت نصب

بعد از نصب می‌توانید این دستور را اجرا کنید:

```sh
openwrt-iran-split-health
```

این ابزار موارد اصلی را بررسی می‌کند، از جمله:

- وضعیت Momo
- وضعیت sing-box
- جدول nftables مربوط به Momo
- TPROXY routing
- DNS listener
- Redirect listener
- TPROXY listener

---

## تست IP از یک دستگاه متصل به روتر

روی کامپیوتر متصل به LAN یا Wi‑Fi روتر:

```sh
curl -4 https://api.ipify.org
```

برای ترافیک خارجی باید IP سرور Hysteria2 نمایش داده شود.

سپس یک سایت ایرانی و یک سایت خارجی را تست کنید.

---

# IPv6

در نسخه `0.1.x`، Proxy کردن IPv6 و IPv6 DNS Hijack به‌صورت پیش‌فرض خاموش است.

دلیلش ساده است: تنظیم IPv6 در شبکه‌های مختلف OpenWrt یکسان نیست و فعال کردن ناقص آن می‌تواند باعث IPv6 leak شود.

نسخه فعلی پروژه روی IPv4 تمرکز دارد تا رفتار قابل پیش‌بینی‌تری داشته باشد.

اگر شبکه شما IPv6 عمومی دارد، قبل از اتکا به تونل برای IPv6 باید تنظیمات Dual Stack را جداگانه بررسی کنید.

---

# روترهای با RAM کم

Installer مقدار RAM دستگاه را بررسی می‌کند و برای روترهای ضعیف‌تر محدودیت‌های مناسب Go را روی Momo اعمال می‌کند تا مصرف حافظه کنترل شود.

پروژه به‌صورت خودکار:

- دیسک شما را پارتیشن‌بندی نمی‌کند.
- فلش USB را Format نمی‌کند.
- Swap ایجاد نمی‌کند.

چون اسکریپتی که خودسرانه Storage کاربر را فرمت کند، بیشتر شبیه حادثه است تا Installer.

---

# Backup

قبل از تغییر تنظیمات موجود Momo، Installer از فایل‌های مهم نسخه پشتیبان تهیه می‌کند.

Backupها در این مسیر قرار می‌گیرند:

```text
/etc/openwrt-iran-split-tunnel/backups/
```

---

# حذف پروژه

برای حذف تنظیمات ایجادشده توسط این پروژه:

```sh
wget -O /tmp/iran-split-uninstall.sh \
  https://raw.githubusercontent.com/MehrooExplains/openwrt-iran-split-tunnel/main/uninstall.sh && \
sh /tmp/iran-split-uninstall.sh
```

Uninstaller به‌صورت عمدی پکیج‌های زیر را حذف نمی‌کند:

```text
momo
luci-app-momo
sing-box
```

چون ممکن است کاربر برای کار دیگری هم از آن‌ها استفاده کند.

---

# امنیت

هیچ‌وقت این موارد را داخل Issue، Commit یا فایل عمومی GitHub قرار ندهید:

```text
Hysteria2 URI واقعی
Password
Certificate
API Token
Backup کامل روتر
```

Momo از Releaseهای رسمی این پروژه دانلود می‌شود:

[nikkinikki-org/OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo)

Ruleهای ایران از این پروژه دریافت می‌شوند:

[Chocolate4U/Iran-sing-box-rules](https://github.com/Chocolate4U/Iran-sing-box-rules)

---

# محدوده پروژه

این پروژه عمداً روی یک سناریوی مشخص تمرکز دارد:

```text
OpenWrt
 + Momo
 + sing-box
 + Hysteria2
 + Iran DIRECT
 + Foreign Proxy
```

فعلاً OpenVPN، OpenConnect و چندین Backend مختلف به پروژه اضافه نشده‌اند تا پروژه ساده، قابل فهم و قابل نگهداری باقی بماند.

---

# گزارش مشکل

اگر روی دستگاهی Installer کار نکرد، هنگام باز کردن Issue بهتر است این اطلاعات را ارسال کنید:

```sh
cat /etc/openwrt_release
uname -a
free -m
```

همچنین خروجی این دستور مفید است:

```sh
openwrt-iran-split-health
```

**اطلاعات Hysteria2، پسورد یا Secretهای خود را قبل از ارسال پاک کنید.**

---

# License

این پروژه تحت **MIT License** منتشر شده است.

می‌توانید:

- رایگان استفاده کنید.
- تغییرش دهید.
- Fork کنید.
- دوباره منتشر کنید.
- در پروژه‌های شخصی یا تجاری استفاده کنید.

فقط شرایط ساده MIT License را رعایت کنید.

---

# پروژه‌های اصلی مورد استفاده

- [OpenWrt-momo](https://github.com/nikkinikki-org/OpenWrt-momo)
- [sing-box](https://github.com/SagerNet/sing-box)
- [Iran-sing-box-rules](https://github.com/Chocolate4U/Iran-sing-box-rules)

---

## English summary

`openwrt-iran-split-tunnel` automatically configures **Iran DIRECT / international Hysteria2** split tunneling on compatible OpenWrt systems using **Momo + sing-box**.

Main features:

- Automatic OpenWrt/package architecture detection
- `apk` and `opkg` detection
- Iran IP/domain routing to DIRECT
- Foreign IPv4 traffic through Hysteria2
- TCP Redirect + UDP TPROXY
- DNS anti-pollution design
- Automatic Iran rule updates
- Low-memory tuning
- Backup and health-check helpers

Install:

```sh
wget -O /tmp/iran-split-install.sh \
  https://raw.githubusercontent.com/MehrooExplains/openwrt-iran-split-tunnel/main/install.sh && \
sh /tmp/iran-split-install.sh
```

Status: early public release (`0.1.x`). Test on recoverable hardware first.
