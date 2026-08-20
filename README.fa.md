# openwrt-iran-split-tunnel

<p align="center">
  <a href="README.md">English</a> | <strong>فارسی</strong>
</p>

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
