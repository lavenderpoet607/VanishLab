# VanishLab Frontend Client

Modern, responsive cross-platform Flutter application for **VanishLab** — AI Watermark Remover & Clean Media Downloader.

---

## 📱 Features

- **3D Animated Splash Screen**:
  - Rotating 3D logo perspective animation with smooth easing (`Curves.easeOutCubic`).
  - Spring-scale entrance with vibrant neon radial glow.
  - Linear loading progress indicator with multi-stage status messages and a calibrated 3.6-second duration.
  - Automatic intelligent routing to Onboarding on first launch or Main Navigation on returning sessions.
- **Interactive Onboarding Experience**:
  - 3-step carousel presentation with rich 3D illustration cards.
  - Feature capability chips (*Brush & Custom Box*, *Generative Fill*, *60 FPS Lossless*).
  - Smooth animated pill page indicators and full-width call-to-action button.
  - Top utility bar with instant Skip action and local session persistence via `SharedPreferences`.
- **Standardized 3D Logo Component**:
  - `AppLogo3D` widget providing three standard sizing presets:
    - `small` (32x32 px) for the Top Navigation Bar.
    - `standard` (72x72 px) for modal dialogs and card containers.
    - `large` (112x112 px) for Splash and Onboarding screens.
  - Adaptive rounded squircle clipping, ambient neon shadows, and optional 3D floating animation.
- **AI Image Watermark Remover**:
  - Interactive multi-tool drawing canvas (Brush, Drag-Box, Lasso polygon, Eraser).
  - High-precision binary mask generation mapped to original image coordinates.
  - Interactive Before/After split comparison slider.
- **AI Video Watermark Remover**:
  - Instant server-side video preview frame extraction.
  - Dynamic aspect ratio rendering (16:9 widescreen, 9:16 vertical Reels/TikTok, 1:1 square).
  - Three distinct selection modes:
    - **Corner Presets**: Single or dual corner presets (`tiktok_both`) for bouncing watermarks.
    - **Custom Box**: Draggable and resizable bounding box with fine-tuning sliders.
    - **Brush/Mask**: Freehand drawing directly on video frame with stroke-to-mask translation.
- **Clean Media Downloader**:
  - URL extraction hub for TikTok, Instagram Reels, YouTube Shorts, X/Twitter, etc.
  - Video (MP4) and Audio-only (MP3) extraction toggles.
  - Optional margin and letterbox watermark cropping switch.
- **Real-Time Task Tracker**:
  - Asynchronous progress polling with live percentage updates.
  - Direct file download buttons and system clipboard integration.
- **User Authentication & Quotas**:
  - Email/Password JWT authentication.
  - Live daily quota tracker (50 requests/day default) with countdown reset timer.
  - Configurable API endpoint switcher for local, emulator, or production environments.
- **Automatic Backend Launcher Integration**:
  - Built-in `BackendLauncherService` that verifies backend API availability on startup and automatically spawns the background daemon on Desktop targets.

---

## 🏗️ Architecture & State Management

The Flutter app follows clean architecture principles utilizing `flutter_bloc`:

```text
frontend/
├── assets/
│   ├── icons/              # App launcher icon and brand badges
│   └── images/             # 3D assets (logo_3d, onboarding_inpaint, onboarding_download)
├── lib/
│   ├── core/
│   │   ├── config/         # API configuration and environment endpoints
│   │   ├── di/             # Dependency injection service locator (get_it)
│   │   ├── network/        # Dio HTTP client, auth interceptor, exception mapping
│   │   ├── services/       # Backend launcher and auto-spawner service
│   │   ├── storage/        # SharedPreferences token and session persistence
│   │   └── theme/          # Dark mode design system (HSL tailored palettes)
│   ├── data/
│   │   ├── models/         # Immutable data models with JSON serialization
│   │   └── repositories/   # Abstract repositories and network implementations
│   └── presentation/
│       ├── blocs/          # Business Logic Components (Auth, Downloader, Inpaint, TaskTracker)
│       ├── pages/          # Screens (Splash, Onboarding, MainNavigation, Inpaint, Downloader)
│       └── widgets/        # Reusable UI widgets, AppLogo3D, Drawing Canvas, Slider
└── pubspec.yaml            # Registered assets and Flutter dependencies
```

---

## 🚀 Running the App

### Prerequisites
- Flutter SDK 3.19+ (Dart 3.3+)
- Android Studio / Android SDK (for Android emulator or physical device)
- Chrome / Edge (for Web development)
- Visual Studio / C++ workload (for Windows Desktop)

### Commands

Fetch dependencies:
```bash
flutter pub get
```

Check connected devices:
```bash
flutter devices
```

Run on Android Emulator:
```bash
flutter run -d emulator-5554
```

Run on Windows Desktop:
```bash
flutter run -d windows
```

Run in Web mode:
```bash
flutter run -d chrome
```

---

## 🌐 Network Configuration

By default, the app automatically selects the appropriate API host:
- **Android Emulator**: `http://10.0.2.2:8000/api/v1`
- **Windows / Desktop / iOS Simulator**: `http://127.0.0.1:8000/api/v1`
- **Web**: `http://localhost:8000/api/v1`

You can customize the API URL directly inside the app by tapping the top-left status indicator (`VanishLab •`).
