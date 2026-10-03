# Security Policy

VanishLab prioritizes the security, confidentiality, and integrity of user media and services. This document outlines our security measures, data retention practices, and vulnerability disclosure protocol.

---

## 🛡️ Supported Versions

Only active release branches receive proactive security patches:

| Version | Supported          | Security Status |
| ------- | ------------------ | --------------- |
| 1.3.x   | :white_check_mark: | Active Support  |
| 1.2.x   | :white_check_mark: | Active Support  |
| 1.1.x   | :white_check_mark: | Critical Only   |
| < 1.1   | :x:                | End of Life     |

---

## 🔒 Security Architecture & Measures

### 1. Ephemeral Media Storage & 24-Hour Auto-Purge
- **Zero Permanent Retention**: Uploaded user media (images, videos, masks) and processed outputs are stored temporarily for a maximum of 24 hours.
- **Automated Lifecycle Enforcement**: Celery Beat scheduled tasks execute hourly cleanup cycles (`backend/app/services/retention.py`), removing expired objects from MinIO/S3 and deleting their database metadata.
- **S3 Orphan Garbage Collection**: Independent sweepers prune unreferenced objects older than 24 hours to prevent orphaned data accumulation.

### 2. Presigned URL Access Control
- Object storage buckets (`vanishlab-media`) remain strictly private with public access disabled.
- Media download links are served exclusively via presigned S3 URLs with short expiration windows (typically 1–2 hours), preventing link sharing or indefinite public exposure.

### 3. Authentication & Credential Protection
- **Password Security**: Passwords are never stored in plaintext. They are salted and hashed using `bcrypt` with appropriate cost factors.
- **Stateless Tokens**: User sessions use JWT (JSON Web Tokens) encoded with HMAC-SHA256 (`HS256`) or asymmetric keys, enforcing configurable token lifespans (`ACCESS_TOKEN_EXPIRE_MINUTES`).
- **Endpoint Protection**: Protected operations (video inpainting, elevated downloader quotas) enforce authorization dependencies (`get_current_user` in `backend/app/api/deps.py`).

### 4. Atomic Rate Limiting & DoS Mitigation
- Quotas are tracked atomically via Redis transactions and counters to prevent race conditions and concurrent quota exhaustion.
- Unauthenticated guest access is rate-limited per client IP address.
- File upload payloads enforce strict size limits (`MAX_UPLOAD_SIZE_MB`) at the web gateway layer (FastAPI & Nginx/Reverse Proxy).

### 5. Media Validation & Anti-Traversal
- **File Type & MIME Validation**: Uploaded files undergo MIME type verification and magic bytes header checking before processing.
- **Path Traversal Defenses**: Filenames are sanitized using UUID v4 namespaces (`inputs/{task_id}/source.{ext}`). Direct user-supplied paths are never passed directly to disk operations.
- **Sandboxed Processing**: Deep learning models (ONNX Runtime, OpenCV) and multimedia tools (FFmpeg) run with isolated subprocess permissions and bounded timeout handlers.

### 6. SSRF Protection (Downloader Engine)
- The media downloader validates target URLs against supported public domain schemes (HTTPS/HTTP).
- Internal loopback addresses (`127.0.0.1`, `localhost`), link-local/cloud metadata endpoints (`169.254.169.254`), and private subnets (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) are blocked to prevent Server-Side Request Forgery.
- User-uploaded browser cookies are stored encrypted or securely isolated per user account.

---

## 📢 Reporting a Vulnerability

If you discover a potential security vulnerability within VanishLab, please adhere to responsible and coordinated disclosure:

1. Do NOT open a public GitHub issue or discuss vulnerabilities in public forums.
2. Send a detailed report via email to **security@vanishlab.local** (or project maintainers).
3. Include the following details to facilitate investigation:
   - Detailed description of the vulnerability and attack vector.
   - Step-by-step reproduction steps or proof-of-concept (PoC) code.
   - Affected components (backend API, worker, frontend, or infrastructure).
   - Potential impact assessment.

### Response SLA
- **Initial Acknowledgment**: Within 24–48 hours.
- **Status & Triaging Update**: Within 3–5 business days.
- **Remediation & Patch**: Target resolution within 14 business days, accompanied by a published advisory.
