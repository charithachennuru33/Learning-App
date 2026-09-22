# Setup guide

This guide takes a fresh machine to running the backend and the mobile app on a virtual device.

| Folder | What it is |
|---|---|
| [`platform-infra/`](platform-infra) | Spring Boot backend: phone-OTP login, tokens, SMS (see its [README](platform-infra/README.md)) |
| [`mobile_app/`](mobile_app) | Flutter app for Android and iOS (see its [README](mobile_app/README.md)) |
| [`scripts/setup-windows.ps1`](scripts/setup-windows.ps1) | One-shot Windows installer for Flutter, Android SDK and emulator |

> **Avoid spaces in tool paths.** Flutter's native build step fails if the SDK lives under a path like
> `C:\Users\First Last\...`. Install tools under `C:\src\` as shown below.

---

## 1. Prerequisites

| Tool | Version | Needed for | Get it |
|---|---|---|---|
| Git | any | everything | https://git-scm.com/download/win |
| JDK | 21 | backend, Android builds | IntelliJ's bundled JDK, or https://adoptium.net |
| Maven | 3.9+ | backend | Bundled with IntelliJ, or https://maven.apache.org/download.cgi |
| Docker Desktop | latest | backend's PostgreSQL + Redis, integration tests | https://www.docker.com/products/docker-desktop |
| Flutter | stable | mobile app | step 3 (script installs it) |
| Android SDK + emulator | API 35/36 | Android testing | step 3 (script installs it) |
| Xcode | latest | iOS testing — **macOS only** | Mac App Store (step 5) |

Hardware for the Android emulator: CPU virtualisation enabled in BIOS (on by default on most laptops),
8 GB RAM minimum (16 GB recommended), ~15 GB free disk.

---

## 2. Backend (platform-infra)

```bash
cd platform-infra
docker compose up -d                                  # PostgreSQL :5432, Redis :6379
mvn clean verify                                      # build + tests (integration tests need Docker)
mvn spring-boot:run -Dspring-boot.run.profiles=dev    # API on http://localhost:8080
```

Check it: http://localhost:8080/actuator/health returns `{"status":"UP"}`, and Swagger is at
http://localhost:8080/swagger-ui.html.

The `dev` profile uses test secrets and **prints each OTP in this console**. There's no real SMS
until you configure MSG91 or Twilio (see the platform-infra README).

---

## 3. Flutter + Android emulator (Windows)

### Option A — script (recommended)

From the repo root, in PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\setup-windows.ps1
```

It installs Flutter into `C:\src\flutter` and the Android SDK into `C:\src\android-sdk`, then creates a
`Pixel_8_API_35` emulator and adds the tools to your user PATH. It verifies the download checksum and is
safe to re-run. It downloads about 4 GB and **accepts the
[Android SDK licence](https://developer.android.com/studio/terms) for you**, so read that first.

Open a **new** terminal afterwards so the PATH change applies.

### Option B — Android Studio

1. Install Flutter: `git clone -b stable https://github.com/flutter/flutter.git C:\src\flutter`, then add
   `C:\src\flutter\bin` to your user PATH.
2. Install [Android Studio](https://developer.android.com/studio) and accept the licence during setup.
3. In Android Studio, open **More Actions → Virtual Device Manager → Create device**, pick Pixel 8 and
   the API 35 image.
4. Run `flutter doctor --android-licenses`.

### Verify

```bash
flutter doctor          # Flutter and Android toolchain should be ✓. "Visual Studio not installed" only
                        # matters for Windows desktop apps; ignore it (and Xcode, which is Mac-only)
flutter emulators       # lists Pixel_8_API_35
```

If the emulator reports no hardware acceleration, enable **Windows Hypervisor Platform**: Start →
"Turn Windows features on or off" → tick *Windows Hypervisor Platform* → reboot. Also check that
virtualisation (AMD-V/SVM or Intel VT-x) is on in BIOS.

---

## 4. Run the app on the Android emulator

```bash
flutter emulators --launch Pixel_8_API_35   # first boot takes 1–2 minutes
cd mobile_app
flutter pub get
flutter run                                 # builds, installs and starts the app (first build ~5–8 min)
```

While `flutter run` is active: `r` hot-reloads, `R` restarts, `q` quits. The emulator uses your PC
keyboard for typing, so no on-screen keyboard appears.

**Demo mode (default, no backend needed):** enter any Indian mobile number, e.g. `9876543210`, and the
code **`123456`**. A red DEMO ribbon shows it's active.

**Real backend:** with platform-infra running (step 2), start the app with
`flutter run --dart-define=DEMO_MODE=false`. Then copy the OTP from the **backend console**
(`DEV ONLY: OTP for +919876543210 is ...`) into the app.

The emulator reaches your PC's `localhost` through `10.0.2.2`, which is the app's default in debug
builds. You don't need to configure anything.

---

## 5. iOS Simulator (requires a Mac)

Apple only ships the iOS Simulator with Xcode on macOS, so **it cannot run on Windows**. Your options:

| Option | Cost | Good for |
|---|---|---|
| Any Mac (a Mac mini is the cheapest) | one-off | Daily iOS development |
| Cloud Mac: MacinCloud, AWS EC2 Mac, Scaleway | hourly/monthly | Occasional iOS work without buying a Mac |
| CI with macOS runners: GitHub Actions, Codemagic | free tier | Automatic iOS builds and tests on every push |
| Real-device clouds: BrowserStack App Live, Firebase Test Lab | paid / free tier | Testing on many real devices |

On a Mac:

```bash
xcode-select --install                           # command-line tools
sudo xcodebuild -runFirstLaunch
brew install cocoapods                           # or: sudo gem install cocoapods
git clone -b stable https://github.com/flutter/flutter.git ~/development/flutter
export PATH="$HOME/development/flutter/bin:$PATH"   # add to ~/.zshrc
flutter doctor

open -a Simulator                                # boots an iPhone simulator
cd mobile_app && flutter run
```

The simulator shares the Mac's network, so the app's default `http://localhost:8080` works if the backend
runs on the same Mac. If the backend runs on your Windows PC instead, pass its LAN address:
`flutter run --dart-define=API_BASE_URL=http://<pc-ip>:8080`.

---

## 6. Physical devices

**Android phone:** Settings → About phone → tap *Build number* 7 times → Developer options → enable
*USB debugging*. Plug it in, accept the prompt, and check `flutter devices`. Then:

```bash
flutter run --dart-define=API_BASE_URL=http://<your-pc-lan-ip>:8080
```

Find the LAN IP with `ipconfig` (IPv4 address). The phone and PC must be on the same Wi-Fi, and Windows
Firewall must allow inbound port 8080 for Java.

**iPhone:** needs a Mac with Xcode and a free Apple ID (7-day signing) or a paid Apple Developer account
($99/yr, needed for TestFlight and the App Store).

---

## 7. Which device should I test on?

| Stage | Android | iOS |
|---|---|---|
| Everyday development | Emulator (Pixel, latest API) with hot reload | iOS Simulator on a Mac |
| Before a release | Also a small/old emulator (API 24, the minimum) and one real phone | One real iPhone (Face ID, keyboard, notch) |
| Wide coverage | Firebase Test Lab or BrowserStack | BrowserStack or TestFlight beta testers |
| Automated | `flutter test` on every push (fast, no device) | `flutter test` + a macOS CI runner for iOS builds |

Emulators cover layout, navigation, the sign-in flow and API errors well. Use real devices for SMS
autofill of the OTP, performance, camera, push notifications and battery behaviour.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| `'C:\Users\First' is not recognized` during `flutter test`/`run` | The Flutter SDK path contains a space. Move it to `C:\src\flutter`. |
| App shows "Could not reach the server" | The backend isn't running, or on a physical phone you didn't pass `API_BASE_URL` with the PC's LAN IP. |
| "Please wait before requesting another OTP" | 60 s resend cooldown. Wait, or restart Redis in dev: `docker compose restart redis`. |
| Backend fails with `Could not resolve placeholder` / `is not set` | You started it without `-Dspring-boot.run.profiles=dev`. |
| Emulator very slow or won't start | Enable Windows Hypervisor Platform (section 3); give the emulator more RAM in Device Manager. |
| `flutter doctor` says Android licences not accepted | `flutter doctor --android-licenses` |
| `mvn verify` shows 10 tests *skipped* | Docker isn't running; the Testcontainers integration tests need it. |
