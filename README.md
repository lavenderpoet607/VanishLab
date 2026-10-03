# VanishLab

<div align="center">

![VanishLab Banner](https://img.shields.io/badge/VanishLab-AI%20Watermark%20Remover-FF6B35?style=for-the-badge&logo=flutter&logoColor=white)

**High-Performance AI Watermark Remover & Clean Media Downloader**

[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?style=flat-square&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Celery](https://img.shields.io/badge/Celery-Distributed%20Tasks-37814A?style=flat-square&logo=celery&logoColor=white)](https://docs.celeryq.dev)
[![PyTorch / ONNX](https://img.shields.io/badge/LaMa-ONNX%20Inpainting-EE4C2C?style=flat-square&logo=pytorch&logoColor=white)](https://onnxruntime.ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

</div>

---

## 🌟 Overview

**VanishLab** is a production-ready, full-stack platform engineered to remove watermarks from photos and videos using deep learning, as well as download clean, watermark-free media from social platforms including TikTok, Instagram Reels, YouTube Shorts, and X/Twitter.

Built on a distributed asynchronous microservice architecture, VanishLab handles compute-heavy video processing without blocking the API gateway. The platform features an interactive client interface with dynamic 3D animations, an onboarding flow, and background daemon execution.

---

## ✨ Key Features

### 1. 🖼️ AI Image Watermark Remover
- **Multi-Tool Precision Canvas**: Support for Brush, Drag-Box, and Lasso Polygon selection to target text, logos, or unwanted objects.
- **Deep Learning Inpainting (LaMa ONNX)**: Employs the Large Mask Inpainting model for high-resolution background synthesis with smooth textures and zero blur distortion.
- **Interactive Before/After Slider**: Real-time side-by-side comparison between original and processed images.

### 2. 🎬 AI Video Watermark Remover
- **Live Frame Preview Extraction**: Fast frame extraction (`POST /api/v1/inpaint/video/preview`) preserving aspect ratios (16:9 widescreen, 9:16 vertical Reels/TikTok, 1:1 square).
- **Visual Inpainting Overlays**:
  - **Corner Presets**: One-click selection for corner watermarks (Bottom-Right, Top-Left, etc.).
  - **Bouncing Watermark Preset (`tiktok_both`)**: Simultaneous removal of alternating top-left and bottom-right corner watermarks.
  - **Custom Draggable Box**: Percentage-based interactive bounding box editor.
  - **Direct Brush on Video Frame**: Freehand mask painting directly over the extracted video frame.
- **Pristine Quality Preservation**: Retains native resolution, original 60 FPS frame rates, and lossless audio streams without destructive re-encoding.

### 3. ⚡ Clean Media Downloader
- **Universal URL Hub**: Direct watermark-free extraction from TikTok, Instagram, YouTube, and X/Twitter powered by `yt-dlp` and FFmpeg.
- **Video (MP4) & Audio (MP3)**: Options for high-definition video download or conversion to 320 kbps audio.
- **Auto-Crop Watermark Bars**: Automated detection and cropping of letterbox borders and edge watermark strips.

### 4. 🚀 3D Splash Screen & Onboarding
- **3D Animated Splash Screen**: Perspective 3D logo rotation with spring bounce dynamics, ambient radial glow, gradient typography, and a calibrated 3.6-second progress indicator.
- **Interactive Onboarding Experience**: Three-step carousel presentation with 3D illustration cards, feature capability chips (Brush & Custom Box, Generative Fill, 60 FPS Lossless), and local persistence via `SharedPreferences`.
- **Standardized 3D App Logo**: Centralized `AppLogo3D` widget with three size presets:
  - `small` (32x32 px) on the Top Utility Bar
  - `standard` (72x72 px) across dialogs and cards
  - `large` (112x112 px) on Splash and Onboarding screens
- **Modern Adaptive Launcher Icons**: 3D icons across all Android mipmap densities with adaptive icon support (`mipmap-anydpi-v26`).

### 5. 🔌 Auto-Run Background API Engine
- **Silent Background Daemon**: `start_daemon.py` and `run_silent.vbs` execute Uvicorn silently in the background without terminal windows (`CREATE_NO_WINDOW`).
- **Windows Startup Integration**: Optional registration (`install_autostart.bat`) to launch the API automatically on system boot.
- **Flutter Native Auto-Spawner**: On desktop platforms, the Flutter app checks backend availability and launches the daemon automatically if needed.
- **One-Click Launcher**: `start_app_with_backend.bat` script to boot both API and Flutter simultaneously.

### 6. 📊 Real-Time Task Tracker & Quota System
- **Asynchronous Task Polling**: Progress tracking (0–100%) through discrete state transitions (`queued` → `processing` → `completed` / `failed`).
- **Presigned Download URLs**: Secure, time-limited direct download links generated from object storage.
- **User Quota**: Default 50 free daily requests per user/IP enforced via atomic Redis rate limiting.

---

## 🏗️ System Architecture

```mermaid
flowchart TD
    Client([Flutter App: Android / iOS / Desktop / Web])

    subgraph API_Gateway [FastAPI Gateway :8000]
        Router[API v1 Endpoints]
        Auth[JWT & Quota Manager]
        StorageMgr[MinIO / S3 Storage Engine]
    end

    subgraph Data_Stores [State & Broker Layer]
        PG[(PostgreSQL 16 DB)]
        Redis[(Redis 7 Broker & Cache)]
        S3[(MinIO Object Storage)]
    end

    subgraph Workers [Distributed Celery Cluster]
        Worker1[Worker: yt-dlp & FFmpeg Downloader]
        Worker2[Worker: LaMa ONNX & Video Inpainter]
        Beat[Celery Beat: 24h Media Purge Cron]
    end

    Client -->|1. Submit Job / Video Preview| Router
    Router --> Auth
    Auth -->|Atomic Quota INCR| Redis
    Router -->|Stage Input File| S3
    Router -->|2. Record Task State| PG
    Router -->|3. Dispatch Task| Redis
    Router -->|4. Return 202 Accepted + Task ID| Client

    Redis -->|Consume Job| Worker1
    Redis -->|Consume Job| Worker2
    Worker1 -->|Update Progress 0-100%| PG
    Worker2 -->|Update Progress 0-100%| PG
    Worker1 -->|Save Clean Media| S3
    Worker2 -->|Save Clean Media| S3

    Client -->|5. Poll GET /api/v1/tasks/:id| Router
    Router -->|Read State| PG
    Router -->|Generate Presigned URL| S3

    Beat -->|Hourly Cleanup Task| S3
    Beat -->|Delete Expired Records > 24h| PG
```

---

## 📁 Repository Structure

```text
VanishLab/
├── backend/                        # FastAPI, Celery, AI Inpainting & Downloader Service
│   ├── app/
│   │   ├── api/v1/                 # Endpoints (auth, inpaint, downloader, tasks)
│   │   ├── core/                   # Config, Database, Redis, S3 Storage, Security
│   │   ├── models/                 # SQLAlchemy ORM Models (User, Task, MediaFile)
│   │   ├── schemas/                # Pydantic v2 Request/Response Schemas
│   │   ├── services/               # Inpainting, Video Inpainting, Extractor, Quota, Retention
│   │   └── workers/                # Celery App, Background Worker Tasks, Beat Schedules
│   ├── models_weights/             # AI Model Weights (big-lama.onnx)
│   ├── scripts/                    # Model downloader and background daemon scripts
│   ├── run_silent.vbs              # Windowless background launcher
│   ├── docker-compose.yml          # Production Docker orchestration
│   ├── Dockerfile                  # Container definition (FFmpeg, OpenCV, Python 3.11)
│   └── requirements.txt            # Python dependencies
├── frontend/                       # Flutter Client Application (BLoC Pattern)
│   ├── assets/                     # 3D graphic assets (logo_3d, onboarding illustrations)
│   ├── lib/
│   │   ├── core/                   # Dark mode theme, API config, networking, launcher service
│   │   ├── data/                   # Models and repository implementations
│   │   └── presentation/           # BLoC, pages (Inpaint, Downloader, Splash, Onboarding)
│   ├── test/                       # Unit and widget test suites
│   └── pubspec.yaml                # Flutter dependencies and assets
├── postman/                        # Postman collection and environment definitions
├── start_app_with_backend.bat      # One-click dual launcher (API + Flutter)
├── CHANGELOG.md                    # Release history and version notes
├── CONTRIBUTING.md                 # Contribution guidelines and coding standards
├── LICENSE                         # MIT Open Source License
├── README.md                       # Main documentation
└── SECURITY.md                     # Security policy and data retention rules
```

---

## 🚀 Quick Start Guide

### Option A: Run Full Stack with Docker Compose (Recommended)

Ensure Docker and Docker Compose are installed on your system:

```bash
cd backend
cp .env.example .env
docker compose up --build -d
```

Active services:
- **FastAPI Backend**: `http://localhost:8000` (Swagger docs: `http://localhost:8000/docs`)
- **MinIO S3 Console**: `http://localhost:9001` (User: `minioadmin` / Pass: `minioadmin`)
- **PostgreSQL**: `localhost:5432`
- **Redis**: `localhost:6379`
- **Celery Worker & Beat**: Task queues and automated periodic cleanup.

---

### Option B: Local Development

#### 1. Running the Backend:
To start the server silently without terminal windows:
```bash
wscript.exe backend/run_silent.vbs
```

To run manually with live logs in your terminal:
```bash
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env
python scripts/download_model.py
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

To configure the backend to start automatically on Windows boot:
```bash
backend\scripts\install_autostart.bat
```

#### 2. Running the Flutter Frontend:
```bash
cd frontend
flutter pub get
flutter run -d emulator-5554
```

For Windows Desktop or Web:
```bash
flutter run -d windows
flutter run -d chrome
```

---

## 📡 Key API Endpoints

| Method | Endpoint | Description | Authentication |
| :--- | :--- | :--- | :---: |
| `POST` | `/api/v1/auth/register` | User account registration | Public |
| `POST` | `/api/v1/auth/login` | Login and obtain JWT Bearer Token | Public |
| `GET` | `/api/v1/auth/quota` | Check remaining daily quota and reset timer | Token / IP |
| `POST` | `/api/v1/downloader/process` | Submit clean media download task | Token / IP |
| `POST` | `/api/v1/inpaint/image` | Submit image inpainting with mask | Token / IP |
| `POST` | `/api/v1/inpaint/video/preview` | Fast frame and metadata extraction | Public |
| `POST` | `/api/v1/inpaint/video` | Submit full video inpainting task | **Required** |
| `GET` | `/api/v1/tasks/{task_id}` | Poll progress and retrieve presigned S3 URL | Public |

---

## 🛡️ Security & Privacy Policy

- **24-Hour Ephemeral Storage**: All uploaded and generated media files are automatically removed after 24 hours by a scheduled Celery Beat worker.
- **Presigned S3 Access**: Media files are not publicly accessible and can only be downloaded through short-lived presigned URLs.
- **SSRF Protection & Media Validation**: Downloader URLs are checked against private and loopback IP ranges, and MIME types are strictly verified before processing.
- For complete details, refer to [SECURITY.md](SECURITY.md).

---

## 🤝 Contributing

Contributions are welcome! Please read the complete guidelines in [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a pull request.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
