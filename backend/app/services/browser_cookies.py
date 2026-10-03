import os
import sys
import logging
import http.cookiejar
from typing import Optional

logger = logging.getLogger(__name__)

def auto_extract_browser_cookies(target_path: Optional[str] = None) -> bool:
    try:
        import yt_dlp.cookies
    except ImportError:
        return False

    if target_path is None:
        target_path = os.path.abspath(
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "cookies.txt")
        )

    orig_dpapi = getattr(yt_dlp.cookies, "_decrypt_windows_dpapi", None)
    if orig_dpapi:
        def safe_dpapi(ciphertext, logger_arg):
            try:
                return orig_dpapi(ciphertext, logger_arg)
            except Exception:
                return b""
        setattr(yt_dlp.cookies, "_decrypt_windows_dpapi", safe_dpapi)

    combined_jar = http.cookiejar.MozillaCookieJar(target_path)
    if os.path.exists(target_path) and os.path.getsize(target_path) > 0:
        try:
            combined_jar.load(ignore_discard=True, ignore_expires=True)
        except Exception:
            pass

    found_any = False
    browsers = ["edge", "chrome", "firefox", "brave", "opera", "vivaldi"]
    for browser in browsers:
        try:
            jar = yt_dlp.cookies.extract_cookies_from_browser(browser)
            if jar and len(jar) > 0:
                for c in jar:
                    combined_jar.set_cookie(c)
                found_any = True
                logger.info("Auto-extracted cookies from browser %s", browser)
        except Exception as e:
            logger.debug("Browser %s extraction skipped: %s", browser, e)

    if found_any or len(combined_jar) > 0:
        try:
            os.makedirs(os.path.dirname(target_path), exist_ok=True)
            combined_jar.save(ignore_discard=True, ignore_expires=True)
            logger.info("Saved %d total cookies to %s", len(combined_jar), target_path)
            return True
        except Exception as e:
            logger.error("Failed to save combined cookies: %s", e)

    return False
