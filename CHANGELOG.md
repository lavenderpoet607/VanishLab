# Changelog

All notable changes to **VanishLab** are documented in this file following the [Keep a Changelog](https://keepachangelog.com/) standard and [Semantic Versioning](https://semver.org/).

---

## [1.3.0] - 2026-10-03

### Added
- **3D Animated Splash Screen**: Implemented calibrated 3.6-second entrance screen featuring perspective 3D rotation, spring-scale bouncy entrance, ambient neon radial glow, and dynamic staged loading indicator (`Memuat modul AI deep learning...` to `Siap digunakan!`).
- **Interactive Onboarding Experience**: Created 3-step carousel presentation with rich 3D illustration cards, feature chips (*Brush & Custom Box*, *Generative Fill*, *60 FPS Lossless*), smooth pill indicators, Skip navigation, and local completion persistence via `SharedPreferences`.
- **Standardized 3D Logo Component**: Built `AppLogo3D` widget providing three standard size presets (`small: 32px`, `standard: 72px`, `large: 112px`) with subtle ambient neon glows and squircle clipping.
- **Android 3D Launcher Icons & Adaptive Icons**: Rendered and deployed 3D launcher icons across all mipmap densities (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`) including circular icons and API 26+ adaptive icon definitions (`res/mipmap-anydpi-v26/`).
- **Silent Background API Daemon**: Created windowless background runner (`start_daemon.py` and `run_silent.vbs`) using `pythonw.exe` and `CREATE_NO_WINDOW` to run the Uvicorn server automatically without terminal windows.
- **Windows Startup Auto-Run Integration**: Added `install_autostart.bat` and `uninstall_autostart.bat` to automatically register the backend into Windows Startup, ensuring the API is always online.
- **Flutter Backend Launcher Service**: Added `BackendLauncherService` in Flutter to probe backend health during splash and automatically spawn the background process when running on Desktop.
- **Unified Root Launcher**: Added `start_app_with_backend.bat` for one-click launching of both backend and frontend.

### Fixed
- **Matrix4 Deprecation Warnings**: Replaced deprecated `Matrix4.scale` and `Matrix4.translate` with native Flutter widgets `Transform.scale` and `Transform.translate`.
- **Dart Wildcard Conventions**: Migrated multiple underscores (`__`, `___`) to standard single underscore (`_`) in route builders and error handlers.
- **Unused Import Directives**: Removed unreferenced imports across main entrypoints.
- **Clean Code Hygiene**: Verified zero comments (`//`, `/* ... */`, `#`) across all newly introduced and modified project code files.

---

## [1.2.0] - 2026-10-03

### Added
- **Dynamic Video Preview Extraction**: New backend endpoint `POST /api/v1/inpaint/video/preview` extracts resolution, aspect ratio, frame rate, duration, and JPEG preview frame without requiring full job submission.
- **Visual Video Inpainting Canvas**: Integrated live video frame preview directly beneath interactive selection tools:
  - Preset Corner buttons overlaying visual target boxes.
  - Interactive Draggable Custom Box Editor with percentage sliders.
  - Interactive Multi-tool Brush/Box/Lasso canvas over the exact video aspect ratio (16:9, 9:16 vertical Reels/TikTok, 1:1 square).
- **Dual-Corner Watermark Preset**: Added `tiktok_both` (`Kedua Sudut`) preset to simultaneously remove watermarks alternating between Top-Left and Bottom-Right corners.
- **Lossless Audio & FPS Preservation**: Maintained original audio stream and frame rate during video reconstruction.

### Fixed
- **Watermark Inpainting Coordinate Clamping Bug**: Fixed dimension check in `VideoInpaintingService.get_watermark_box` where videos under 1000px width/height incorrectly clamped normalized coordinates into 1px slivers.
- **Custom Brush Mask Aspect Ratio Distortion**: Replaced hardcoded 1280x720 canvas dimensions with actual video resolution and dynamic viewport size scaling.
- **RenderFlex Layout Overflows**: Resolved vertical viewport overflows on small Android mobile viewports within the Inpaint and Downloader screens.
- **Authentication Enforcement**: Fixed mandatory authentication dialog when attempting video watermark processing.

### Security
- Verified short-lived presigned download URLs for output media.
- Maintained automatic 24-hour media purge via Celery Beat cron tasks.
- Cleaned codebase comment hygiene across all Python and Dart project source files.

---

## [1.1.0] - 2026-10-03

### Added
- **Multi-Platform Clean Media Downloader**: Full support for TikTok, Instagram Reels, YouTube Shorts, and X/Twitter video extraction via `yt-dlp` and FFmpeg.
- **Audio-Only Extraction**: Added option to extract pristine 320kbps MP3 audio from any supported media link.
- **Black Bar & Watermark Strip Cropping**: Automated edge margin detection and cropping filter for persistent letterbox watermarks.
- **Realtime Task Tracking**: Asynchronous polling engine with live progress bars, state transitions, and direct file download actions.
- **User Quota Tracking**: Added 50 free daily requests with atomic Redis rate limiter and status indicator in top navigation bar.

---

## [1.0.0] - 2026-10-02

### Added
- **Initial Architecture**:
  - FastAPI asynchronous gateway with SQLAlchemy Async ORM.
  - Distributed Celery workers with Redis broker.
  - MinIO S3-compatible object storage staging.
  - PostgreSQL 16 database for state management.
  - Flutter multi-platform client with BLoC pattern.
- **LaMa ONNX Inpainting Engine**: Deep learning watermark removal for images with OpenCV Telea/Navier-Stokes fallback.
- **Docker Compose Production Stack**: Complete multi-container orchestration.
