# VanishLab Backend Engine
> **High-Concurrency AI Watermark Remover & Clean Media Downloader**

VanishLab is a production-grade backend engineered for asynchronous, non-blocking media processing. It powers watermark-free video downloads and deep-learning image and video inpainting (LaMa ONNX & Video Inpainting) over a distributed task queue.

---

## 🏗️ 1. System Architecture

```mermaid
flowchart TD
    Client([Client / Frontend])
    
    subgraph FastAPI_Application [FastAPI Gateway / Async API]
        Router[API v1 Routers]
        Auth[JWT & Quota Validator]
        S3Upload[S3 Staging Manager]
    end

    subgraph Data_Stores [State & Message Brokers]
        PG[(PostgreSQL 16\nSQLAlchemy Async)]
        Redis[(Redis 7\nBroker + Cache + Quota)]
        MinIO[(MinIO / S3\nObject Storage)]
    end

    subgraph Worker_Tier [Distributed Celery Workers]
        Worker1[Celery Worker:\nyt-dlp + FFmpeg Clean Engine]
        Worker2[Celery Worker:\nLaMa ONNX & Video Inpainting Engine]
        Beat[Celery Beat:\n24h Media Retention Cron]
    end

    Client -->|1. Submit Download / Inpaint Job| Router
    Router --> Auth
    Auth -->|Atomic INCR Check| Redis
    Router -->|Stage Original Files| MinIO
    Router -->|2. Create Task status=queued| PG
    Router -->|3. Dispatch Job Non-blocking| Redis
    Router -->|4. Return 202 Accepted + task_id| Client

    Redis -->|Consume Task| Worker1
    Redis -->|Consume Task| Worker2
    Worker1 -->|Update Progress 0-100%| PG
    Worker2 -->|Update Progress 0-100%| PG
    Worker1 -->|Save Clean MP4| MinIO
    Worker2 -->|Save Clean PNG/MP4| MinIO
    
    Client -->|5. Poll GET /api/v1/tasks/:id| Router
    Router -->|Read Task & Output Media| PG
    Router -->|Generate Presigned Download URL| MinIO
    Router -->|Return Status & Presigned URL| Client

    Beat -->|Periodic 1h Check| Worker1
    Worker1 -->|Delete Media > 24h| MinIO
    Worker1 -->|Delete Expired Records| PG
```

---

## 📁 2. Directory Structure

```text
backend/
├── app/
│   ├── api/
│   │   ├── deps.py                 # Dependency Injection (Auth, DB, Client IP)
│   │   └── v1/
│   │       ├── auth.py             # User Register, Login, Me, Quota Status, Quota Reset
│   │       ├── downloader.py       # POST /api/v1/downloader/process
│   │       ├── inpaint.py          # POST /api/v1/inpaint/image, /inpaint/video/preview, /inpaint/video
│   │       ├── tasks.py            # GET /api/v1/tasks/{task_id} (Polling & Presigned URLs)
│   │       └── router.py           # V1 Router Aggregator
│   ├── core/
│   │   ├── config.py               # Pydantic Settings & Environment Variables
│   │   ├── database.py             # Async & Sync SQLAlchemy Session Management
│   │   ├── exceptions.py           # Standardized Domain Exceptions & Handlers
│   │   ├── redis_client.py         # Async/Sync Redis Connections
│   │   ├── security.py             # Password Hashing (bcrypt) & JWT Auth
│   │   └── storage.py              # MinIO/S3 Client & Presigned URLs
│   ├── models/
│   │   ├── base.py                 # TimeStampedModel Base
│   │   ├── user.py                 # User Model (Daily Quota Tracking)
│   │   ├── task.py                 # Task Model (Status, Progress, Metadata)
│   │   └── media.py                # MediaFile Model (Retention & S3 Keys)
│   ├── schemas/
│   │   ├── auth.py                 # Pydantic v2 Auth Schemas
│   │   ├── common.py               # Standard Response & Error Formats
│   │   ├── downloader.py           # Downloader Request & Task Schemas
│   │   ├── inpaint.py              # Inpainting Request & Task Schemas
│   │   └── task.py                 # Task Progress & Output Schemas
│   ├── services/
│   │   ├── extractor.py            # yt-dlp Clean Extraction & FFmpeg Stream Pipeline
│   │   ├── inpainting.py           # LaMa ONNX Watermark Removal Inference Engine
│   │   ├── video_inpainting.py     # Video Inpainting Engine (Corner Presets, Custom Box, Mask)
│   │   ├── quota.py                # Atomic Quota Rate Limiter (Redis + DB)
│   │   └── retention.py            # S3 & DB 24h Auto-Cleanup Logic
│   ├── workers/
│   │   ├── celery_app.py           # Celery Configuration & Beat Schedule
│   │   └── tasks.py                # Background Tasks Definitions
│   └── main.py                     # FastAPI Application Entrypoint & Healthcheck
├── models_weights/                 # Directory for ONNX Model Weights (e.g. big-lama.onnx)
├── scripts/
│   ├── download_model.py           # Automated model weight downloader for LaMa
│   ├── start_daemon.py             # Silent background daemon runner
│   ├── stop_daemon.py              # Background daemon terminator
│   ├── install_autostart.bat       # Windows Startup registry installer
│   └── uninstall_autostart.bat     # Windows Startup uninstaller
├── run_silent.vbs                  # Windowless VBScript launcher
├── docker-compose.yml              # Complete Production Stack Orchestration
├── Dockerfile                      # Production Docker Image (FFmpeg + OpenCV + Py3.11)
├── requirements.txt                # Pinned Modern Dependencies
└── .env.example                    # Environment Variables Documentation
```

---

## 🚀 3. How to Run

### Option A: Silent Background Mode (Automatic & Terminal-Free)

To run the API silently in the background without command prompt windows:

```bash
wscript.exe backend/run_silent.vbs
```

To register the API to boot automatically with Windows:
Run `backend/scripts/install_autostart.bat`.

To stop the background daemon when needed:
```bash
python backend/scripts/stop_daemon.py
```

---

### Option B: Docker Compose (Recommended for Production)

```bash
cd backend
cp .env.example .env
docker compose up --build -d
```

Running services:
- **FastAPI Backend**: `http://localhost:8000` (Swagger UI: `http://localhost:8000/docs`)
- **MinIO S3 Console**: `http://localhost:9001` (User: `minioadmin` / Pass: `minioadmin`)
- **PostgreSQL**: `localhost:5432`
- **Redis**: `localhost:6379`
- **Celery Worker**: 4 concurrent worker processes for video/AI processing
- **Celery Beat**: Periodic cleanup scheduler for files older than 24 hours

---

### Option C: Manual Terminal Execution

```bash
cd backend
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env
python scripts/download_model.py
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

---

## 📡 4. Key Endpoints Documentation

### 1. Submit Clean Media Downloader Job
- **URL**: `POST /api/v1/downloader/process`
- **Status Code**: `202 Accepted`
- **Request Body**:
```json
{
  "url": "https://www.tiktok.com/@username/video/1234567890",
  "extract_audio_only": false,
  "crop_watermark_bars": false,
  "max_resolution": "1080p"
}
```
- **Response**:
```json
{
  "task_id": "a92e622b-23eb-46c5-a6e4-e3f7c10b784a",
  "status": "queued",
  "message": "Media extraction job accepted and queued for worker processing.",
  "estimated_time_sec": 15
}
```

---

### 2. Submit AI Image Watermark Inpainting Job
- **URL**: `POST /api/v1/inpaint/image`
- **Content-Type**: `multipart/form-data`
- **Status Code**: `202 Accepted`
- **Form Data**:
  - `image`: Original image file (PNG/JPG/WebP)
  - `mask`: Binary mask file (White = Watermark to remove, Black = Retained image area)
- **Response**:
```json
{
  "task_id": "8c5eb3c0-6d45-4fd2-8a9d-19069d27f8a7",
  "status": "queued",
  "message": "Inpainting task accepted and queued for worker processing.",
  "estimated_time_sec": 5
}
```

---

### 3. Video Live Frame Extraction
- **URL**: `POST /api/v1/inpaint/video/preview`
- **Content-Type**: `multipart/form-data`
- **Form Data**:
  - `video`: Video file (MP4/MOV/WebM)
- **Response**:
```json
{
  "width": 1080,
  "height": 1920,
  "fps": 30.0,
  "duration_sec": 15.2,
  "aspect_ratio": 0.5625,
  "preview_frame_base64": "data:image/jpeg;base64,..."
}
```

---

### 4. Submit AI Video Inpainting Job
- **URL**: `POST /api/v1/inpaint/video`
- **Authentication**: JWT Bearer Token required
- **Form Data**:
  - `video`: Source video file
  - `corner_preset`: `bottom_right`, `bottom_left`, `top_right`, `top_left`, or `tiktok_both`
  - `box_x`, `box_y`, `box_w`, `box_h`: Custom bounding box coordinates (optional)
  - `mask`: Custom binary mask file (optional)

---

### 5. Task Status Polling & Presigned Download URL
- **URL**: `GET /api/v1/tasks/{task_id}`
- **Response while processing (`processing`)**:
```json
{
  "task_id": "a92e622b-23eb-46c5-a6e4-e3f7c10b784a",
  "task_type": "download_media",
  "status": "processing",
  "progress": 55,
  "error_message": null,
  "output_files": [],
  "created_at": "2026-10-03T04:30:00Z",
  "updated_at": "2026-10-03T04:30:10Z"
}
```
- **Response when completed (`completed`)**:
```json
{
  "task_id": "a92e622b-23eb-46c5-a6e4-e3f7c10b784a",
  "task_type": "download_media",
  "status": "completed",
  "progress": 100,
  "error_message": null,
  "result_metadata": {
    "title": "Clean Video Sample",
    "duration": 45,
    "extractor": "TikTok",
    "file_size": 14205810,
    "content_type": "video/mp4"
  },
  "output_files": [
    {
      "id": "e44186fd-f952-4752-95eb-522199b4ff44",
      "file_name": "clean_a92e622b-23eb-46c5-a6e4-e3f7c10b784a.mp4",
      "file_size_bytes": 14205810,
      "content_type": "video/mp4",
      "is_output": true,
      "download_url": "http://localhost:8000/media/outputs/clean_sample.mp4",
      "expires_at": "2026-10-04T04:30:00Z",
      "created_at": "2026-10-03T04:30:15Z"
    }
  ],
  "created_at": "2026-10-03T04:30:00Z",
  "updated_at": "2026-10-03T04:30:15Z"
}
```

---

## 🛡️ 5. Standardized Error Handling

All system exceptions return a standard JSON structure:
```json
{
  "status": "error",
  "error_code": "QUOTA_EXCEEDED",
  "message": "Daily limit reached (50 requests/day). Please upgrade or try again tomorrow.",
  "details": {
    "limit": 50,
    "used": 50,
    "remaining": 0
  }
}
```

Standard Error Codes:
- `QUOTA_EXCEEDED` (HTTP 429): Daily limit reached for registered user or guest IP.
- `EXTRACTION_FAILED` (HTTP 422): Video URL could not be extracted (private or platform blocked).
- `INVALID_FILE` (HTTP 400): File type or dimensions unsupported or corrupted.
- `TASK_NOT_FOUND` (HTTP 404): Task ID does not exist.
- `INPAINTING_FAILED` (HTTP 500): AI model inference error.
- `STORAGE_ERROR` (HTTP 502): Storage connection disruption.

---

## 🧹 6. Auto-Cleanup & Media Retention

Ephemeral media cleanup runs across two layers:
1. **Celery Beat Cron**: Executes hourly at `crontab(minute=0)`. Queries `media_files` where `expires_at <= NOW()` and purges storage objects as well as database rows.
2. **Storage Orphan Scavenger**: Cleans local and S3 files older than 24 hours even if missing from database records.

---

## 📬 7. Postman Collection & Environment

Ready-to-use Postman files are located in the `postman/` directory:
- **Collection**: `postman/VanishLab.postman_collection.json`
- **Environment**: `postman/VanishLab.postman_environment.json`

Automated Postman Features:
1. Running **Login User** automatically persists the JWT token into `{{access_token}}`.
2. Subsequent requests (Quota, Downloader, Inpaint, Task) automatically authenticate via `Bearer {{access_token}}`.
3. Submitting jobs (Downloader / Inpaint) saves `task_id` into `{{task_id}}` for immediate polling in **Get Task Status**.
4. Includes **Reset Quota** (`POST /api/v1/auth/quota/reset`) to reset test quotas on demand.
