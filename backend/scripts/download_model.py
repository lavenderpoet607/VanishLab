import os
import sys
import urllib.request

LAMA_ONNX_URL = "https://huggingface.co/anyisalin/big-lama-onnx/resolve/main/onnx/model.onnx"
FALLBACK_URL = "https://huggingface.co/Carve/LaMa-ONNX/resolve/main/lama_fp32.onnx"

TARGET_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "models_weights")
TARGET_FILE = os.path.join(TARGET_DIR, "big-lama.onnx")

def download_file(url: str, dest_path: str):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
    with urllib.request.urlopen(req, timeout=30) as response:
        total_size = int(response.headers.get("Content-Length", 0))
        block_size = 1024 * 1024
        downloaded = 0
        part_file = dest_path + ".part"

        with open(part_file, "wb") as f:
            while True:
                chunk = response.read(block_size)
                if not chunk:
                    break
                f.write(chunk)
                downloaded += len(chunk)
                if total_size > 0:
                    percent = int(downloaded * 100 / total_size)
                    sys.stdout.write(f"\rDownloading LaMa ONNX Model: {percent}% [{downloaded / (1024*1024):.1f}MB / {total_size / (1024*1024):.1f}MB]")
                else:
                    sys.stdout.write(f"\rDownloading LaMa ONNX Model: [{downloaded / (1024*1024):.1f}MB]")
                sys.stdout.flush()

        if os.path.exists(dest_path):
            os.remove(dest_path)
        os.rename(part_file, dest_path)
        print("\nDownload finished successfully!")

def main():
    os.makedirs(TARGET_DIR, exist_ok=True)
    if os.path.exists(TARGET_FILE) and os.path.getsize(TARGET_FILE) > 100 * 1024 * 1024:
        print(f"Model already present at: {TARGET_FILE} ({os.path.getsize(TARGET_FILE) / (1024*1024):.1f} MB)")
        return

    print(f"Downloading LaMa ONNX model to: {TARGET_FILE}...")
    try:
        download_file(LAMA_ONNX_URL, TARGET_FILE)
    except Exception as e:
        print(f"\nPrimary source failed ({e}), attempting fallback mirror...")
        try:
            download_file(FALLBACK_URL, TARGET_FILE)
        except Exception as e2:
            print(f"\nFailed to download model: {e2}")
            sys.exit(1)

if __name__ == "__main__":
    main()
