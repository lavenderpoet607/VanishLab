import os
import re
import shutil
import subprocess
import tempfile
import logging
from typing import Callable, Optional, Dict, Any, Tuple, List, cast
import ffmpeg
import yt_dlp
from yt_dlp.utils import DownloadError, ExtractorError

from app.core.config import settings
from app.core.exceptions import ExtractionFailedException
from app.services.browser_cookies import auto_extract_browser_cookies

logger = logging.getLogger(__name__)

def _instagram_id_to_shortcode(media_id: int) -> str:
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    shortcode = ""
    while media_id > 0:
        media_id, rem = divmod(media_id, 64)
        shortcode = alphabet[rem] + shortcode
    return shortcode

def _resolve_alternate_urls(url: str) -> List[str]:
    alts = []
    match = re.search(r"instagram\.com/stories/[^/]+/(\d+)", url)
    if match:
        try:
            media_id = int(match.group(1))
            code = _instagram_id_to_shortcode(media_id)
            if code:
                alts.append(f"https://www.instagram.com/p/{code}/")
                alts.append(f"https://www.instagram.com/reel/{code}/")
        except Exception:
            pass
    return alts

def _resolve_cookies_file() -> Optional[str]:
    candidates = [
        settings.COOKIES_FILE_PATH,
        os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "cookies.txt")),
        os.path.abspath(os.path.join(os.getcwd(), "cookies.txt")),
        os.path.abspath(os.path.join(os.getcwd(), "data", "cookies.txt")),
        os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "cookies.txt")),
    ]
    for p in candidates:
        if p and os.path.exists(p) and os.path.getsize(p) > 0:
            return p

    try:
        if auto_extract_browser_cookies():
            for p in candidates:
                if p and os.path.exists(p) and os.path.getsize(p) > 0:
                    return p
    except Exception as e:
        logger.debug("Automatic browser cookie extraction encountered: %s", e)

    return None

def _ensure_ffmpeg_available() -> Optional[str]:
    ffmpeg_path = shutil.which("ffmpeg")
    if ffmpeg_path:
        bin_dir = os.path.dirname(os.path.abspath(ffmpeg_path))
        return bin_dir

    try:
        import imageio_ffmpeg
        exe = imageio_ffmpeg.get_ffmpeg_exe()
        if exe and os.path.exists(exe):
            bin_dir = os.path.dirname(os.path.abspath(exe))
            target_name = "ffmpeg.exe" if os.name == "nt" else "ffmpeg"
            target_exe = os.path.join(bin_dir, target_name)
            if not os.path.exists(target_exe):
                try:
                    shutil.copy2(exe, target_exe)
                except Exception as copy_err:
                    logger.warning("Could not copy ffmpeg executable to %s: %s", target_name, copy_err)

            cur_path = os.environ.get("PATH", "")
            if bin_dir not in cur_path:
                os.environ["PATH"] = bin_dir + os.pathsep + cur_path
            return bin_dir
    except Exception as e:
        logger.warning("Failed to auto-configure ffmpeg from imageio_ffmpeg: %s", e)

    return None

_FFMPEG_DIR = _ensure_ffmpeg_available()

class MediaExtractorService:

    @staticmethod
    def extract_and_clean_video(
        url: str,
        output_dir: str,
        task_id: str,
        extract_audio_only: bool = False,
        crop_watermark_bars: bool = False,
        progress_callback: Optional[Callable[[int, str], None]] = None,
    ) -> Tuple[str, Dict[str, Any]]:
        ffmpeg_bin = _ensure_ffmpeg_available() or _FFMPEG_DIR

        if progress_callback:
            progress_callback(10, "Extracting media metadata...")

        raw_download_template = os.path.join(output_dir, f"raw_{task_id}.%(ext)s")

        def ytdl_progress_hook(d):
            if d.get("status") == "downloading" and progress_callback:
                total_bytes = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
                downloaded = d.get("downloaded_bytes", 0)
                if total_bytes > 0:
                    percent = int((downloaded / total_bytes) * 35) + 15
                    progress_callback(percent, f"Downloading clean stream: {d.get('_percent_str', '')}")

        ydl_opts: Dict[str, Any] = {
            "outtmpl": raw_download_template,
            "quiet": True,
            "no_warnings": True,
            "progress_hooks": [ytdl_progress_hook],
            "nocheckcertificate": True,
            "ignoreerrors": False,
            "socket_timeout": 30,
            "http_headers": {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.9",
                "Sec-Fetch-Mode": "navigate",
            },
        }

        if ffmpeg_bin:
            ydl_opts["ffmpeg_location"] = ffmpeg_bin

        cookie_file = _resolve_cookies_file()
        if cookie_file:
            ydl_opts["cookiefile"] = cookie_file
        elif settings.COOKIES_FROM_BROWSER:
            ydl_opts["cookiesfrombrowser"] = (settings.COOKIES_FROM_BROWSER,)

        if extract_audio_only:
            ydl_opts["format"] = "bestaudio/best"
        else:
            ydl_opts["format"] = "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
            ydl_opts["merge_output_format"] = "mp4"

        urls_to_try = [url] + _resolve_alternate_urls(url)
        last_exception = None
        extracted_info = None

        for attempt_idx, target_url in enumerate(urls_to_try):
            try:
                current_opts = dict(ydl_opts)
                if attempt_idx > 0 and "cookiesfrombrowser" not in current_opts and not current_opts.get("cookiefile"):
                    current_opts["cookiesfrombrowser"] = ("edge",)

                with yt_dlp.YoutubeDL(cast(Any, current_opts)) as ydl:
                    info_dict = ydl.extract_info(target_url, download=False)
                    if not info_dict:
                        continue

                    title = info_dict.get("title", "clean_media")
                    duration = info_dict.get("duration", 0)
                    extractor_key = info_dict.get("extractor_key", "Generic")
                    width = info_dict.get("width")
                    height = info_dict.get("height")

                    if progress_callback:
                        stream_type = "audio" if extract_audio_only else "video"
                        progress_callback(20, f"Detected {stream_type} stream: {extractor_key}. Initiating download...")

                    ydl.download([target_url])
                    extracted_info = {
                        "title": title,
                        "duration": duration,
                        "extractor_key": extractor_key,
                        "width": width,
                        "height": height,
                    }
                    break
            except (DownloadError, ExtractorError) as e:
                last_exception = e
                err_str = str(e)
                logger.warning("yt-dlp extraction failed for %s: %s", target_url, err_str)
                lower_err = err_str.lower()
                if "log in" in lower_err or "login" in lower_err or "cookies" in lower_err or "authenticated" in lower_err:
                    auto_extract_browser_cookies()
                    new_cookie = _resolve_cookies_file()
                    if new_cookie:
                        ydl_opts["cookiefile"] = new_cookie
                continue
            except Exception as e:
                last_exception = e
                logger.warning("Unexpected extraction error for %s: %s", target_url, e)
                continue

        if not extracted_info:
            if last_exception:
                err_str = str(last_exception)
                lower_err = err_str.lower()
                if "log in" in lower_err or "login" in lower_err or "cookies" in lower_err or "authenticated" in lower_err:
                    msg = (
                        "Konten ini memerlukan autentikasi login (seperti Instagram Story atau konten privat). "
                        "Sistem telah mencoba sinkronisasi otomatis cookies browser. "
                        "Pastikan akun Anda aktif di browser atau pasang file cookies.txt."
                    )
                    raise ExtractionFailedException(
                        msg,
                        details={"url": url, "error": err_str, "requires_cookies": True},
                    )
                raise ExtractionFailedException(
                    f"Failed to extract media: {err_str}",
                    details={"url": url, "error": err_str},
                )
            raise ExtractionFailedException("Could not retrieve media info for the specified URL.")

        title = extracted_info["title"]
        duration = extracted_info["duration"]
        extractor_key = extracted_info["extractor_key"]
        width = extracted_info["width"]
        height = extracted_info["height"]

        downloaded_files = [
            os.path.join(output_dir, f)
            for f in os.listdir(output_dir)
            if f.startswith(f"raw_{task_id}")
        ]
        if not downloaded_files:
            raise ExtractionFailedException("Downloaded file not found on disk.")

        raw_filepath = downloaded_files[0]

        if progress_callback:
            progress_callback(55, "Post-processing stream with FFmpeg...")

        if extract_audio_only:
            clean_filename = f"clean_{task_id}.mp3"
            clean_filepath = os.path.join(output_dir, clean_filename)
            encoded_successfully = False

            try:
                (
                    ffmpeg.input(raw_filepath)
                    .output(
                        clean_filepath,
                        acodec="libmp3lame",
                        audio_bitrate="192k",
                        map_metadata=-1,
                    )
                    .overwrite_output()
                    .run(quiet=True, capture_stdout=True, capture_stderr=True)
                )
                if os.path.exists(clean_filepath) and os.path.getsize(clean_filepath) > 0:
                    encoded_successfully = True
            except ffmpeg.Error as ffe:
                logger.warning("ffmpeg-python audio encoding error: %s. Attempting fallback CLI.", ffe.stderr.decode(errors="ignore") if ffe.stderr else ffe)
            except Exception as ffe:
                logger.warning("FFmpeg audio encoding error: %s", ffe)

            if not encoded_successfully:
                ffmpeg_cmd = "ffmpeg.exe" if os.name == "nt" else "ffmpeg"
                ffmpeg_target = os.path.join(ffmpeg_bin or "", ffmpeg_cmd) if ffmpeg_bin else shutil.which("ffmpeg") or "ffmpeg"
                try:
                    res = subprocess.run(
                        [ffmpeg_target, "-y", "-i", raw_filepath, "-vn", "-c:a", "libmp3lame", "-b:a", "192k", clean_filepath],
                        capture_output=True,
                        text=True,
                    )
                    if res.returncode == 0 and os.path.exists(clean_filepath) and os.path.getsize(clean_filepath) > 0:
                        encoded_successfully = True
                    else:
                        logger.error("Fallback ffmpeg CLI failed: %s", res.stderr)
                except Exception as sub_err:
                    logger.error("Direct fallback subprocess error: %s", sub_err)

            if not encoded_successfully:
                if raw_filepath.lower().endswith(".mp3"):
                    shutil.copy2(raw_filepath, clean_filepath)
                    encoded_successfully = True
                else:
                    raise ExtractionFailedException("Failed to convert audio stream to standard MP3 format.")

        else:
            clean_filename = f"clean_{task_id}.mp4"
            clean_filepath = os.path.join(output_dir, clean_filename)
            try:
                stream = ffmpeg.input(raw_filepath)
                video_stream = stream.video
                if crop_watermark_bars:
                    video_stream = video_stream.filter("crop", "in_w", "in_h-80", "0", "40")

                audio_stream = stream.audio

                (
                    ffmpeg.output(
                        video_stream,
                        audio_stream,
                        clean_filepath,
                        vcodec="libx264",
                        pix_fmt="yuv420p",
                        acodec="aac",
                        audio_bitrate="192k",
                        movflags="+faststart",
                        map_metadata=-1,
                    )
                    .overwrite_output()
                    .run(quiet=True, capture_stdout=True, capture_stderr=True)
                )
            except (ffmpeg.Error, FileNotFoundError, Exception) as ffe:
                logger.warning("FFmpeg video filtering error: %s, falling back to direct copy or raw file.", ffe)
                try:
                    (
                        ffmpeg.input(raw_filepath)
                        .output(clean_filepath, c="copy", movflags="+faststart")
                        .overwrite_output()
                        .run(quiet=True)
                    )
                except Exception:
                    clean_filepath = raw_filepath

        if progress_callback:
            progress_callback(80, "Media cleaned and standardized successfully.")

        if os.path.exists(raw_filepath) and raw_filepath != clean_filepath:
            try:
                os.remove(raw_filepath)
            except Exception:
                pass

        file_size = os.path.getsize(clean_filepath)
        metadata = {
            "title": title,
            "duration": duration,
            "extractor": extractor_key,
            "width": None if extract_audio_only else width,
            "height": None if extract_audio_only else height,
            "file_size": file_size,
            "content_type": "audio/mpeg" if extract_audio_only else "video/mp4",
        }

        return clean_filepath, metadata

extractor_service = MediaExtractorService()
