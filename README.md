# Network Checker

<p align="center">
  <strong>Set of network tools curated for Iran's Internet situation.</strong><br>
  مجموعه ابزارهای شبکه برای وضعیت اینترنت ایران
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux-blue?style=flat-square" alt="Platform">
  <a href="https://github.com/mirarr-app/network-checker/releases">
    <img src="https://img.shields.io/github/v/release/mirarr-app/network-checker?style=flat-square&color=green" alt="Latest Release">
  </a>
  <a href="https://github.com/mirarr-app/network-checker/releases">
    <img alt="GitHub Downloads (all assets, all releases)" src="https://img.shields.io/github/downloads/mirarr-app/network-checker/total">
  </a>
</p>

---

## 📥 Download / دانلود

Available for Android, Windows, and Linux.  
برای اندروید، ویندوز و لینوکس در دسترس است.

<p align="left">
  <a href="https://github.com/mirarr-app/network-checker/releases">
    <img src="https://raw.githubusercontent.com/NeoApplications/Neo-Backup/034b226cea5c1b30eb4f6a6f313e4dadcbb0ece4/badge_github.png" width="180">
  </a>
</p>

---

## 📱 Screenshots / اسکرین‌شات‌ها

### Desktop
| Domain Checker | DNS Latency Test |
| :---: | :---: |
| ![Domain Checker](https://github.com/user-attachments/assets/a9107c04-254b-4185-978b-f43f08adf73d) | ![DNS Latency Test](https://github.com/user-attachments/assets/3ef00158-7a3f-4887-a68e-1fb9eb20dc9d) |
| **DNS Hunter** | **Edge IP Checker** |
| ![DNS Hunter](https://github.com/user-attachments/assets/a980bcea-b352-4670-ab30-29518ab877a3) | ![Edge IP Checker](https://github.com/user-attachments/assets/dc5e6700-5a07-4d4a-a659-9e7fba5a57f0) |
| **Vless Config Modifier** | **CDN Xray Scanner** |
| ![Vless Config Modifier](https://github.com/user-attachments/assets/095585cd-ff49-4ed1-bf91-cfe07126688b) | ![CDN Xray Scanner](https://github.com/user-attachments/assets/b35e1c31-83c6-4bc0-91cd-acf7c83aa564) |
| **Akamai IP Scan** | **SNI Spoof Check** |
| ![Akamai IP Scan](https://github.com/user-attachments/assets/3684149e-585d-4aca-ba52-608376f8b5d6) | ![SNI Spoof Check](https://github.com/user-attachments/assets/5307d6c7-5e69-4310-a29e-585e411909d0) |
| **Netlify Config** | **Diagnostics** |
| ![Netlify Config](https://github.com/user-attachments/assets/1eb37c67-ade1-420a-8b53-4d702ac95280) | ![Diagnostics](https://github.com/user-attachments/assets/8488cd39-c41b-4646-aa48-41a25f5caa2b) |


---

## ⚡ Features (English)

### Internet Diagnostics
A set of automated tests for different network protocols, DNS providers, websites accessibility and more. Ready to be analyzed with AI.

### IP info
Check your public IP address, its geolocation and ASN, an IP purity score (Tor exit, proxy and datacenter signals), per-website exit IPs for split-routing setups, median latency to popular services, and environment checks: DNS leak, IP leak, Cloudflare edge, global ping and whois.

### Domain Checker
Scan most visited domains to check which ones are accessible. With the ability to add custom ones!

### DNS Latency Test
Latency test famous DNS providers. Inspired by [DNS-XS](https://github.com/code3-dev/DNS-XS)

### DNS Hunter
Test to check what Iranian datacenters resolve dns requests to specific domains. Inspired by [DNS Hunter](https://github.com/30niorcrypto/DNS-Hunter)

### Edge IP Checker
Scan for accessible Cloudflare Edge IPs. Inspired by [CF Scan Tolid Melli](https://github.com/AghaFarokh/CF-Scan-TolidMelli)

> 💡 **Linux Note:** If you're scanning a lot of IPs on Linux, run this command before launching the app (it will reset after a reboot):
> ```bash
> ulimit -S -c unlimited -d unlimited -f unlimited -i unlimited -l unlimited -m unlimited -n 65535 -q unlimited -s unlimited -t unlimited -u 65535 -v unlimited -x unlimited
> ```

### Vless Config Modifier
Replace the IP address in a vless config with other IPs from a list or IP ranges and get all the vless configs back. Inspired by [v2ray config modifier](https://github.com/seramo/v2ray-config-modifier)

### CDN Xray Scanner
Scan CDN IP ranges using Xray core and your own json config. Inspired by the GOAT, [Morteza Bashsiz Scanner](https://github.com/MortezaBashsiz/CFScanner).  
* In order to prepare your json configuration for scanning [read this guide](https://github.com/mirarr-app/network-checker/blob/main/get_json_for_cdn_scan.md).

### Netlify Config Generator
Generate multiple netlify configurations from multiple SNIs and IPs. Inspired by `IR_NETLIFY`.

### Akamai Scanner
Scan Akamai IP ranges.

### SNI Spoof Check
Check if SNI spoofing is open. Inspired by [sni scanner](https://github.com/seramo/sni-scanner)

### 🤖 Android-Only Features
* **Config Encoder for SMS:** Normally sending configs via SMS is blocked. This tool lets you encode English text using Persian characters and decode it on the target device.

---

## ⚡ ویژگی‌ها (فارسی)

### تست کامل شبکه
تحلیل کامل پروتکل‌ها، شبکه‌های اجتماعی، وبسایت‌های معروف، دی‌ان‌اس‌های معروف و موارد دیگر آماده شده برای تحلیل با هوش مصنوعی.

### اطلاعات IP
بررسی آدرس IP عمومی، موقعیت جغرافیایی و ASN، امتیاز خلوص IP (خروجی Tor، پراکسی و دیتاسنتر)، آی‌پی خروجی هر وب‌سایت برای تنظیمات split-routing، میانگین تأخیر تا سرویس‌های معروف و بررسی‌های محیطی: نشت DNS، نشت IP، لبه کلودفلر، پینگ جهانی و whois.

### بررسی‌کننده دامنه
اسکن پربازدیدترین دامنه‌ها برای بررسی در دسترس بودن آن‌ها. با قابلیت اضافه کردن دامنه‌های دلخواه.

### تست تأخیر DNS
تست تأخیر ارائه‌دهندگان معروف DNS. الهام گرفته از [DNS-XS](https://github.com/code3-dev/DNS-XS)

### DNS Hunter
تست برای بررسی اینکه دیتاسنترهای ایرانی درخواست‌های DNS چه دامنه‌هایی را resolve می‌کنند. الهام گرفته از [DNS Hunter](https://github.com/30niorcrypto/DNS-Hunter)

### بررسی‌کننده Edge IP
اسکن برای یافتن IP های Edge کلودفلر که در دسترس هستند. الهام گرفته از [CF Scan Tolid Melli](https://github.com/AghaFarokh/CF-Scan-TolidMelli)

> ℹ️ **توضیحات تکمیلی:**
> * با این اسکن می‌توانید آی‌پی تمیز کلودفلر پیدا کنید. رنج‌های رسمی کلودفلر با دکمه دیفالت بررسی می‌شوند.
> * تمام رنج‌هایی که می‌توانید اسکن کنید رنج‌های رسمی نیستند. هر رنج آی‌پی که از سرویس کلودفلر استفاده می‌کند قابل استفاده است (حتی رنج‌های ایرانی).
> * از تنظیمات بالای صفحه می‌توانید دامنه برای اتصال را عوض کنید. پیش‌فرض دامنه چت‌جی‌پی‌تی انتخاب شده ولی هر دامنه‌ای که پشت کلودفلر باشد قابل استفاده است.
> * برای ورسل نیز می‌توانید از اسکنر استفاده کنید؛ اما در حال حاضر فقط دامنه اصلی ورسل برای اسکن قابل استفاده است.

### ویرایشگر کانفیگ Vless
جایگزینی آدرس IP در کانفیگ vless با IP های دیگر از یک لیست یا بازه IP و دریافت تمام کانفیگ‌های vless. الهام گرفته از [v2ray config modifier](https://github.com/seramo/v2ray-config-modifier)

### اسکنر CDN Xray
اسکن بازه‌های IP سی‌دی‌ان با استفاده از هسته Xray و کانفیگ json شخصی شما. الهام گرفته از استاد، [Morteza Bashsiz Scanner](https://github.com/MortezaBashsiz/CFScanner)  
* برای گرفتن json از کانفیگ خود برای اسکن [اینجا را مطالعه کنید](https://github.com/mirarr-app/network-checker/blob/main/get_json_for_cdn_scan_fa.md).

> ℹ️ **توضیحات تکمیلی:**
> * با این اسکن می‌توانید آی‌پی تمیز برای هر سی‌دی‌انی پیدا کنید. این اسکنر از هسته xray برای تست آی‌پی‌ها استفاده می‌کند، پس در صورت موفقیت آمیز بودن تست، آی‌پی حتماً در کانفیگ شما کار خواهد کرد.
> * از تنظیمات ‌می‌توانید تعداد اسکن همزمان را افزایش دهید.

### کانفیگ Netlify
تولید چندین کانفیگ netlify از چندین SNI و IP. الهام گرفته از `IR_NETLIFY`

### اسکنر Akamai
اسکن بازه‌های IP Akamai

### چک کردن sni spoof
چک کردن باز بودن sni spoof. الهام گرفته شده از [sni scanner](https://github.com/seramo/sni-scanner)

### 🤖 ویژگی‌های مخصوص اندروید
* **رمزگذار کانفیگ برای پیامک:** معمولاً ارسال کانفیگ‌ها از طریق پیامک مسدود است. این ابزار به شما امکان می‌دهد متن انگلیسی را با کاراکترهای فارسی رمزگذاری کنید و در دستگاه دیگر رمزگشایی کنید.
