import os
import socket
import subprocess
import sys

def is_port_listening(host: str, port: int) -> bool:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(0.5)
            return s.connect_ex((host, port)) == 0
    except Exception:
        return False

def start_backend():
    if is_port_listening("127.0.0.1", 8000):
        return

    script_dir = os.path.dirname(os.path.abspath(__file__))
    backend_dir = os.path.dirname(script_dir)
    project_root = os.path.dirname(backend_dir)
    pythonw_path = os.path.join(project_root, ".venv", "Scripts", "pythonw.exe")

    if not os.path.isfile(pythonw_path):
        pythonw_path = os.path.join(project_root, ".venv", "Scripts", "python.exe")

    if not os.path.isfile(pythonw_path):
        pythonw_path = sys.executable

    creation_flags = 0x08000000 | 0x00000200

    cmd = [
        pythonw_path,
        "-m",
        "uvicorn",
        "app.main:app",
        "--host",
        "0.0.0.0",
        "--port",
        "8000",
    ]

    subprocess.Popen(
        cmd,
        cwd=backend_dir,
        creationflags=creation_flags,
        close_fds=True,
    )

if __name__ == "__main__":
    start_backend()
