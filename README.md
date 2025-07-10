# 📦 Frigate Alerts Backup Script

> 🎁 This script is a small gift — created with the help of ChatGPT — for the Frigate community.  
> It is provided "as is", with no guarantees. Use at your own risk.

---

## 🔍 What does it do?

This Bash script creates daily backups of Frigate alerts, saving both:

- 🎥 **Alert footage** – Frigate records videos as a series of short 10-second clips. This script copies the raw 10-second fragments that cover the alert period, not a single continuous video.

- 🗂 **Metadata** – Event ID, camera name, timestamp, and clip availability.

It pulls data directly from the Frigate SQLite database and copies the corresponding video fragments to a mounted destination folder of your choice (e.g., USB drive, network share, or any accessible storage).

---

## ⚙️ How it works

1. Creates a backup of your Frigate SQLite database.  
2. Parses today's alerts, identifying which have video clips.  
3. Finds the 10-second video fragments closest to the alert start time.  
4. Copies those fragments to the configured destination folder.

This script runs manually by default, but it can be automated easily with tools like `cron` or `systemd`.

---

## 📂 File Overview

- `backup_alerts.sh` → original version in **Spanish**  
- `backup_alerts_en.sh` → translated and cleaned-up **English version**

---

## ✅ Requirements

- A working Frigate setup (with recording enabled)  
- SQLite3 installed  
- USB or storage destination mounted  
- Basic Linux shell environment

---

## 🧪 Tested With

- ✅ 4 camera setup  
- ✅ Local Frigate instance  
- ✅ Daily manual execution

---

## 🚀 Example usage (manual)

```bash
bash backup_alerts_en.sh

📬 Feedback

If you find it useful, feel free to ⭐ the repo or share it with others.
Pull requests and improvements are welcome!
🙏 Thanks

Huge thanks to the Frigate project and its community for the tools and inspiration.
