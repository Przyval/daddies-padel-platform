"""Server-side HTML → PNG renderer.

Uses Playwright (preferred) or html2image (fallback).
PNGs are cached by content hash — same data = same image, no re-render.
"""
import hashlib
import os
from pathlib import Path

SHARE_DIR = Path(__file__).parent.parent / "static" / "shares"
SHARE_DIR.mkdir(parents=True, exist_ok=True)


def render_card(card_type: str, html_content: str) -> str:
    """Render HTML to PNG. Returns path relative to static/ (e.g., 'shares/streak_a1b2.png')."""
    content_hash = hashlib.md5(html_content.encode()).hexdigest()[:12]
    filename = f"{card_type}_{content_hash}.png"
    filepath = SHARE_DIR / filename

    # Return cached
    if filepath.exists():
        return f"shares/{filename}"

    # Try Playwright first (best quality)
    try:
        return _render_playwright(html_content, filepath, filename, card_type)
    except Exception:
        pass

    # Fallback: html2image
    try:
        return _render_html2image(html_content, filepath, filename)
    except Exception:
        pass

    # Last resort: return empty (caller handles)
    return ""


def _render_playwright(html_content, filepath, filename, card_type):
    from playwright.sync_api import sync_playwright
    with sync_playwright() as pw:
        browser = pw.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1080, "height": 1080})
        page.set_content(html_content, wait_until="networkidle")
        card = page.query_selector(".card")
        if card:
            card.screenshot(path=str(filepath), type="png")
        else:
            page.screenshot(path=str(filepath), type="png")
        browser.close()
    return f"shares/{filename}"


def _render_html2image(html_content, filepath, filename):
    import tempfile
    from html2image import Html2Image
    tmpdir = tempfile.mkdtemp()
    hti = Html2Image(output_path=tmpdir, size=(1080, 1080))
    paths = hti.screenshot(html_str=html_content, save_as=filename)
    # Move to share dir
    import shutil
    shutil.move(paths[0], str(filepath))
    return f"shares/{filename}"


def cleanup_old(max_age_hours=24):
    """Delete PNGs older than max_age_hours."""
    import time
    now = time.time()
    for f in SHARE_DIR.glob("*.png"):
        if now - f.stat().st_mtime > max_age_hours * 3600:
            f.unlink()
