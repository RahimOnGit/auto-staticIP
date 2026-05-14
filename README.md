# AutoStaticIP

**Automatically apply static IP and DNS settings when connecting to specific Wi‑Fi networks (e.g., mobile hotspots).**

Now with **dynamic SSID scanning**, **multi‑profile support**, and a completely rewritten backend for reliability.

![AutoStaticIP GUI](screenshots/gui.png)  <!-- Optional: add a screenshot -->

---

## Features

- 🔍 **Scan & pick** – The app scans nearby Wi‑Fi networks so you can choose your hotspot without typing the SSID.
- 👥 **Multiple profiles** – Save a profile for each hotspot (work iPhone, personal Android, travel router, etc.).
- ⚡ **Auto‑detection** – The background task automatically matches the current Wi‑Fi to the right profile and applies the settings.
- 🛡 **Safe route management** – Only the default gateway is replaced; VPN routes and other static routes are left untouched.
- 🧠 **Smart apply** – Skips network changes if the correct IP is already configured, avoiding useless reconfiguration.
- 🚦 **Admin elevation check** – Tells you right away if you forgot to run as Administrator.
- 📝 **Full logging** – All actions (including DHCP resets) are logged to a file for troubleshooting.
- 🌐 **Built‑in connectivity tester** – Check if a URL is reachable after applying settings.
- 💻 **GUI + console** – Use `AutoStaticIP.exe` for everyday use, or `Manage‑App.ps1` for scripting.

---

## Requirements

- **Windows 10 / Windows 11**
- **PowerShell 5.1** (pre‑installed) or PowerShell 7
- **Administrator privileges** – the app changes network adapter settings

No additional installation required. The `.exe` is self‑contained.

---

## Quick start (GUI)

1. Download `AutoStaticIP.exe` from the [latest release](https://github.com/YourUsername/AutoStaticIP/releases/latest).
2. Right‑click `AutoStaticIP.exe` → **Run as administrator**.
3. Click **+ Add** to scan nearby Wi‑Fi networks.
4. Select your hotspot’s SSID, choose the device type (iPhone, Android, etc.), and adjust the IP if needed.
5. Click **Save**.
6. Click **Turn ON** to register the background task.
7. (Optional) Click **Apply Now** to force the static IP right now.
8. You’re done! Every time you connect to that Wi‑Fi, the correct IP is applied automatically.

---
