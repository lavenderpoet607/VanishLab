# Contributing to VanishLab

Thank you for your interest in contributing to **VanishLab**! We welcome bug reports, feature suggestions, architectural improvements, and code contributions.

---

## 🧭 Code of Conduct

- Be respectful and considerate in communications and reviews.
- Focus on constructive feedback and maintain high engineering standards.
- Keep the codebase clean, readable, and free of unnecessary noise.

---

## 🛠️ Development Setup

### 1. Prerequisites
- **Git**
- **Docker & Docker Compose** (for full stack or backend dependencies)
- **Python 3.11+** with virtual environment support
- **Flutter SDK 3.19+** (Dart 3.3+)
- **FFmpeg 5.0+** installed on PATH

### 2. Backend Setup

Clone repository and enter backend directory:
```bash
git clone https://github.com/your-org/vanishlab.git
cd vanishlab/backend
```

Create and activate virtual environment:
```bash
python -m venv .venv
.venv\Scripts\Activate.ps1
```

Install dependencies:
```bash
pip install -r requirements.txt
```

Configure environment variables:
```bash
cp .env.example .env
```

Optional download of AI inpainting model weights:
```bash
python scripts/download_model.py
```

Launch background dependencies (Postgres, Redis, MinIO):
```bash
docker compose up -d postgres redis minio
```

Run FastAPI development server:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Run Celery worker in a separate terminal:
```bash
celery -A app.workers.celery_app worker --loglevel=info --concurrency=4
```

Or run the silent background daemon:
```bash
wscript.exe run_silent.vbs
```

### 3. Frontend Setup

Enter frontend directory and fetch dependencies:
```bash
cd ../frontend
flutter pub get
```

Run on connected Android device or emulator:
```bash
flutter run -d emulator-5554
```

Or run on desktop / web:
```bash
flutter run -d windows
flutter run -d chrome
```

---

## 🧼 Code Style & Hygiene Standards

We adhere to strict code quality and hygiene standards:

1. **Self-Documenting Code**: Code must be clear, concise, and expressive through meaningful naming conventions. Avoid decorative separators, obvious line restatements, or dead boilerplate comments.
2. **Type Safety**:
   - Python code must utilize Pydantic schemas, type hints (`typing.Optional`, `typing.List`, etc.), and pass linting.
   - Dart code must enforce strict typing with zero compiler warnings (`dart analyze`).
3. **Responsive UI**: All Flutter pages must handle various viewport sizes (mobile portrait, landscape, tablets, desktop) without RenderFlex overflow exceptions. Use layout wrappers like `LayoutBuilder`, `SingleChildScrollView`, and responsive flex columns.
4. **Asynchronous Architecture**: Long-running media operations (AI inpainting, video encoding, video downloading) must always run asynchronously through Celery worker tasks rather than blocking the FastAPI HTTP event loop.

---

## 🧪 Testing

Always verify test suites before submitting a Pull Request:

### Backend Checks
```bash
cd backend
python -m compileall app
pytest
```

### Frontend Checks
```bash
cd frontend
flutter analyze
flutter test
```

---

## 📦 Pull Request Process

1. Fork the repository and create your feature branch:
   ```bash
   git checkout -b feat/your-feature-name
   ```
2. Commit your changes with descriptive messages:
   - `feat: add dual-corner bouncing watermark preset`
   - `fix: correct video preview aspect ratio calculation`
   - `docs: update deployment architecture`
3. Push to your branch and open a Pull Request against `main`.
4. Provide a summary of changes, reproduction steps, and screenshots for UI modifications.
