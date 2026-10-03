import subprocess
import sys

def stop_backend():
    cmd = [
        "powershell",
        "-NoProfile",
        "-Command",
        "Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }",
    ]
    subprocess.run(cmd, creationflags=0x08000000)

if __name__ == "__main__":
    stop_backend()
