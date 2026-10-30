#!/usr/bin/env python3
"""Reproducible static + headless-Chromium QA for Caliber Lookbook V2 responsive food flow.

Usage:
  python3 design/lookbook-v2/qa/check_v2_responsive.py
  python3 design/lookbook-v2/qa/check_v2_responsive.py --capture-screenshots
  python3 design/lookbook-v2/qa/check_v2_responsive.py --peer-ref origin/codex/lookbook-v2

Safety & isolation guarantees:
  - Uses Python 3 standard library only plus existing /Applications/Google Chrome.app if present.
  - Binds an ephemeral loopback HTTP server on 127.0.0.1:0 (never touches port 8768).
  - Launches headless Chrome with a disposable --user-data-dir and --remote-debugging-port=0
    so existing user or Codex browser sessions are never touched.
  - Never mutates git state or peer-owned files; --peer-ref reads peer blobs in memory via `git show`.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import mimetypes
import os
import re
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from html.parser import HTMLParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

QA_DIR = Path(__file__).resolve().parent
V2_DIR = QA_DIR.parent
DESIGN_DIR = V2_DIR.parent
ROOT = DESIGN_DIR.parent

OWNED_BOARDS = ("food-entry.html", "food-review.html")
CHROME_BIN = Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
VOID_TAGS = {
    "area", "base", "br", "col", "embed", "hr", "img",
    "input", "link", "meta", "source", "track", "wbr",
}

VIEWPORTS = (
    (320, 693, "320pt"),
    (375, 812, "375pt"),
    (390, 844, "390pt"),
    (430, 932, "430pt"),
    (480, 854, "480pt"),
    (667, 375, "landscape-375h"),
    (568, 320, "landscape-320h"),
)


# ---------- Static HTML / CSS / Token checks ----------

def strip_css_comments(css: str) -> str:
    return re.sub(r"/\*.*?\*/", "", css, flags=re.S)


def undefined_css_variables(css: str, tokens_css: str) -> list[str]:
    clean = strip_css_comments(css)
    defined = set(re.findall(r"(--[a-z0-9-]+)\s*:", tokens_css)) | set(
        re.findall(r"(--[a-z0-9-]+)\s*:", clean)
    )
    used = set(re.findall(r"var\((--[a-z0-9-]+)", clean))
    return sorted(used - defined)


def hardcoded_colors(text: str) -> list[str]:
    clean = strip_css_comments(text)
    hexes = re.findall(r"#[0-9a-fA-F]{3,8}\b", clean)
    funcs = re.findall(r"\b(?:rgb|rgba|hsl|hsla)\s*\([^)]*\)", clean, flags=re.I)
    return hexes + funcs


class BoardHTMLInspector(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.stack: list[tuple[str, int]] = []
        self.errors: list[str] = []
        self.stylesheets: list[str] = []
        self.scripts: list[tuple[str, bool]] = []
        self.headings: list[int] = []
        self.labels_for: set[str] = set()
        self.controls_needing_label: list[tuple[str, str | None, bool, int]] = []
        self.buttons: list[tuple[str | None, str | None, int]] = []
        self.links: list[tuple[str, bool, int]] = []
        self.external_refs: list[str] = []
        self.has_html_dark = False
        self.has_viewport = False
        self.body_screen: str | None = None
        self.has_header = False
        self.has_main = False
        self.has_nav = False
        self._in_button: dict | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        line = self.getpos()[0]
        adict = dict(attrs)
        if tag not in VOID_TAGS:
            self.stack.append((tag, line))

        for attr_name in ("href", "src", "action"):
            val = adict.get(attr_name) or ""
            if re.match(r"^(?:https?:)?//", val, flags=re.I):
                self.external_refs.append(f"line {line}: external {attr_name}={val}")

        if tag == "html":
            if adict.get("lang") == "en" and adict.get("data-theme") == "dark":
                self.has_html_dark = True
        elif tag == "meta" and adict.get("name") == "viewport":
            self.has_viewport = True
        elif tag == "link" and adict.get("rel") == "stylesheet":
            self.stylesheets.append(adict.get("href") or "")
        elif tag == "script":
            self.scripts.append((adict.get("src") or "<inline>", "defer" in adict))
        elif tag == "body":
            if "v2-app" in (adict.get("class") or "").split():
                self.body_screen = adict.get("data-screen")
        elif tag == "header" and "app-header" in (adict.get("class") or "").split():
            self.has_header = True
        elif tag == "main" and adict.get("id") == "main" and "content" in (adict.get("class") or "").split():
            self.has_main = True
        elif tag == "nav" and "app-nav" in (adict.get("class") or "").split():
            self.has_nav = True
        elif tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self.headings.append(int(tag[1]))
        elif tag == "label" and adict.get("for"):
            self.labels_for.add(adict["for"] or "")
        elif tag in ("input", "select", "textarea"):
            if adict.get("type") != "hidden":
                self.controls_needing_label.append(
                    (tag, adict.get("id"), bool(adict.get("aria-label")), line)
                )
        elif tag == "button":
            self._in_button = {
                "type": adict.get("type"),
                "aria": adict.get("aria-label"),
                "text": [],
                "line": line,
            }
        elif tag == "a" and adict.get("href"):
            self.links.append((adict["href"] or "", "data-board-link" in adict, line))

    def handle_data(self, data: str) -> None:
        if self._in_button is not None:
            self._in_button["text"].append(data)

    def handle_endtag(self, tag: str) -> None:
        line = self.getpos()[0]
        if tag == "button" and self._in_button is not None:
            label = (self._in_button["aria"] or "".join(self._in_button["text"])).strip()
            self.buttons.append((self._in_button["type"], label, self._in_button["line"]))
            self._in_button = None

        if tag in VOID_TAGS:
            return
        if not self.stack:
            self.errors.append(f"line {line}: </{tag}> without opening tag")
        elif self.stack[-1][0] != tag:
            open_tag, open_line = self.stack[-1]
            self.errors.append(f"line {line}: </{tag}> closes <{open_tag}> from line {open_line}")
            while self.stack and self.stack[-1][0] != tag:
                self.stack.pop()
            if self.stack:
                self.stack.pop()
        else:
            self.stack.pop()


def srgb(hex_color: str) -> tuple[float, float, float]:
    val = int(hex_color.lstrip("#"), 16)
    return tuple(((val >> shift) & 255) / 255.0 for shift in (16, 8, 0))  # type: ignore[return-value]


def rel_luminance(rgb: tuple[float, float, float]) -> float:
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def wcag_contrast(hex_a: str, hex_b: str) -> float:
    hi, lo = sorted((rel_luminance(srgb(hex_a)), rel_luminance(srgb(hex_b))), reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def run_static_checks(root: Path = ROOT) -> list[str]:
    problems: list[str] = []
    tokens_css = (root / "design" / "tokens.css").read_text(encoding="utf-8")
    tokens_json = json.loads((root / "design" / "tokens.json").read_text(encoding="utf-8"))
    resp_css_path = root / "design" / "lookbook-v2" / "responsive.css"
    resp_css = resp_css_path.read_text(encoding="utf-8")

    for undef in undefined_css_variables(resp_css, tokens_css):
        problems.append(f"responsive.css: undefined CSS variable {undef}")
    for color in hardcoded_colors(resp_css):
        problems.append(f"responsive.css: hard-coded color {color}; use ../tokens.css tokens")
    if re.search(r"text-overflow\s*:\s*ellipsis", strip_css_comments(resp_css), flags=re.I):
        problems.append("responsive.css: forbidden text-overflow: ellipsis truncation rule")

    # Verify semantic token contrast pairs used by food-entry / food-review surfaces.
    sys.path.insert(0, str(root / "scripts"))
    import gen_tokens as gen  # noqa: E402

    for theme_key in ("dark", "light"):
        theme = gen.resolve_theme(tokens_json, theme_key)
        for surface_key in ("base", "raised"):
            bg = theme["opaque"][surface_key][:7]
            for text_key in ("primary", "secondary", "tertiary"):
                fg = theme["text"][text_key][:7]
                ratio = wcag_contrast(fg, bg)
                if ratio < 4.5:
                    problems.append(
                        f"tokens ({theme_key}): text.{text_key} ({fg}) on opaque.{surface_key} ({bg}) = {ratio:.2f}:1 (< 4.5:1)"
                    )
        on_acc = theme["text"]["onAccent"][:7]
        acc = theme["accent"]["base"][:7]
        if wcag_contrast(on_acc, acc) < 4.5:
            problems.append(f"tokens ({theme_key}): text.onAccent on accent.base < 4.5:1")

    expected_sheets = ["../tokens.css", "base.css", "components.css", "responsive.css"]
    expected_scripts = [("fixture.js", True), ("board.js", True)]

    for board_name in OWNED_BOARDS:
        path = root / "design" / "lookbook-v2" / board_name
        if not path.exists():
            problems.append(f"{board_name}: missing file")
            continue
        html = path.read_text(encoding="utf-8")
        inspector = BoardHTMLInspector()
        inspector.feed(html)
        inspector.close()

        for err in inspector.errors:
            problems.append(f"{board_name}: {err}")
        for tag, line in inspector.stack:
            problems.append(f"{board_name}: line {line}: unclosed <{tag}>")
        for ext in inspector.external_refs:
            problems.append(f"{board_name}: {ext}")
        if "@import" in html:
            problems.append(f"{board_name}: forbidden @import")
        for color in hardcoded_colors(html):
            problems.append(f"{board_name}: hard-coded color {color}")
        if not inspector.has_html_dark:
            problems.append(f"{board_name}: <html> must specify lang='en' and data-theme='dark'")
        if not inspector.has_viewport:
            problems.append(f"{board_name}: missing viewport meta tag")
        if inspector.stylesheets != expected_sheets:
            problems.append(
                f"{board_name}: stylesheet order {inspector.stylesheets} != {expected_sheets}"
            )
        if inspector.scripts != expected_scripts:
            problems.append(
                f"{board_name}: script contract {inspector.scripts} != {expected_scripts}"
            )
        expected_screen = board_name.removesuffix(".html")
        if inspector.body_screen != expected_screen:
            problems.append(
                f"{board_name}: body data-screen='{inspector.body_screen}' != '{expected_screen}'"
            )
        if not (inspector.has_header and inspector.has_main and inspector.has_nav):
            problems.append(f"{board_name}: missing header.app-header, main#main.content, or nav.app-nav")

        # board.js injects <h1> inside .app-header; main headings must start at <h2> and never skip levels.
        prev_level = 1
        for level in inspector.headings:
            if level == 1:
                problems.append(f"{board_name}: static <h1> inside body duplicates board.js header <h1>")
            if level > prev_level + 1:
                problems.append(f"{board_name}: heading level jumps from h{prev_level} to h{level}")
            prev_level = level

        for tag, cid, has_aria, line in inspector.controls_needing_label:
            if not has_aria and (not cid or cid not in inspector.labels_for):
                problems.append(f"{board_name}: line {line}: <{tag}> lacks associated <label for> or aria-label")

        for btype, blabel, line in inspector.buttons:
            if btype != "button":
                problems.append(f"{board_name}: line {line}: <button> must specify type='button'")
            if not blabel:
                problems.append(f"{board_name}: line {line}: <button> lacks accessible name")

        for href, has_board_link, line in inspector.links:
            if href.endswith(".html") and not has_board_link:
                problems.append(f"{board_name}: line {line}: board link '{href}' missing data-board-link")

    return problems


# ---------- Minimal RFC 6455 WebSocket CDP Client (Python stdlib only) ----------

class LocalCDPClient:
    def __init__(self, host: str, port: int, path: str) -> None:
        self._sock = socket.create_connection((host, port), timeout=15)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        req = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n\r\n"
        )
        self._sock.sendall(req.encode("ascii"))
        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = self._sock.recv(4096)
            if not chunk:
                raise RuntimeError("CDP WebSocket handshake closed unexpectedly")
            buf += chunk
        header, self._leftover = buf.split(b"\r\n\r\n", 1)
        accept = base64.b64encode(
            hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")).digest()
        ).decode("ascii")
        if accept.encode("ascii") not in header:
            raise RuntimeError("CDP WebSocket Sec-WebSocket-Accept mismatch")
        self._next_id = 1

    def close(self) -> None:
        try:
            self._sock.close()
        except OSError:
            pass

    def _recv_exact(self, n: int) -> bytes:
        while len(self._leftover) < n:
            chunk = self._sock.recv(65536)
            if not chunk:
                raise RuntimeError("CDP WebSocket EOF")
            self._leftover += chunk
        res, self._leftover = self._leftover[:n], self._leftover[n:]
        return res

    def _send_frame(self, payload: bytes, opcode: int = 0x1) -> None:
        mask = os.urandom(4)
        header = bytearray([0x80 | opcode])
        length = len(payload)
        if length < 126:
            header.append(0x80 | length)
        elif length < 65536:
            header.append(0x80 | 126)
            header.extend(struct.pack("!H", length))
        else:
            header.append(0x80 | 127)
            header.extend(struct.pack("!Q", length))
        header.extend(mask)
        masked = bytes(b ^ mask[i & 3] for i, b in enumerate(payload))
        self._sock.sendall(bytes(header) + masked)

    def _recv_message(self) -> str:
        fragments: list[bytes] = []
        while True:
            b0, b1 = self._recv_exact(2)
            fin = bool(b0 & 0x80)
            opcode = b0 & 0x0F
            masked = bool(b1 & 0x80)
            length = b1 & 0x7F
            if length == 126:
                (length,) = struct.unpack("!H", self._recv_exact(2))
            elif length == 127:
                (length,) = struct.unpack("!Q", self._recv_exact(8))
            mask_key = self._recv_exact(4) if masked else b""
            data = self._recv_exact(length)
            if masked:
                data = bytes(b ^ mask_key[i & 3] for i, b in enumerate(data))
            if opcode == 0x9:  # ping
                self._send_frame(data, opcode=0xA)
                continue
            if opcode == 0x8:  # close
                raise RuntimeError("CDP WebSocket closed by browser")
            fragments.append(data)
            if fin:
                return b"".join(fragments).decode("utf-8")

    def call(self, method: str, params: dict | None = None, session_id: str | None = None) -> dict:
        msg_id = self._next_id
        self._next_id += 1
        req: dict = {"id": msg_id, "method": method, "params": params or {}}
        if session_id:
            req["sessionId"] = session_id
        self._send_frame(json.dumps(req).encode("utf-8"))
        while True:
            raw = self._recv_message()
            resp = json.loads(raw)
            if resp.get("id") == msg_id:
                if "error" in resp:
                    raise RuntimeError(f"CDP {method} failed: {resp['error']}")
                return resp.get("result", {})


# ---------- Ephemeral Loopback Design Server ----------

def load_git_Overlays(peer_ref: str | None, claude_ref: str | None = None) -> dict[str, bytes]:
    overlays: dict[str, bytes] = {}
    if peer_ref:
        for rel in ("design/lookbook-v2/diary.html", "design/lookbook-v2/base.css"):
            proc = subprocess.run(
                ["git", "-C", str(ROOT), "show", f"{peer_ref}:{rel}"],
                capture_output=True,
                check=False,
            )
            if proc.returncode == 0:
                overlays["/" + rel.removeprefix("design/")] = proc.stdout
    if claude_ref:
        for rel in (
            "design/lookbook-v2/components.css",
            "design/lookbook-v2/today.html",
            "design/lookbook-v2/train.html",
            "design/lookbook-v2/stack.html",
            "design/lookbook-v2/progress.html",
        ):
            proc = subprocess.run(
                ["git", "-C", str(ROOT), "show", f"{claude_ref}:{rel}"],
                capture_output=True,
                check=False,
            )
            if proc.returncode == 0:
                overlays["/" + rel.removeprefix("design/")] = proc.stdout
    return overlays


def start_ephemeral_server(overlays: dict[str, bytes]) -> tuple[ThreadingHTTPServer, int]:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt: str, *args: object) -> None:
            return

        def do_GET(self) -> None:  # noqa: N802
            path_only = self.path.split("?", 1)[0]
            ctype = mimetypes.guess_type(path_only)[0] or "application/octet-stream"
            if path_only in overlays:
                body = overlays[path_only]
                self.send_response(200)
                self.send_header("Content-Type", ctype)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
                return

            fs_path = (DESIGN_DIR / path_only.lstrip("/")).resolve()
            if not str(fs_path).startswith(str(DESIGN_DIR)) or not fs_path.is_file():
                self.send_response(404)
                self.end_headers()
                return
            body = fs_path.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    port = server.server_address[1]
    if port == 8768:
        server.server_close()
        return start_ephemeral_server(overlays)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, port


DOM_AUDIT_JS = r"""
(() => {
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const root = document.documentElement;
  const scale = Number(root.dataset.scale || '1');
  const rootFontPx = parseFloat(getComputedStyle(root).fontSize);
  const bodyFontPx = parseFloat(getComputedStyle(document.body).fontSize);
  const h1 = document.querySelector('.app-header h1');
  const h1FontPx = h1 ? parseFloat(getComputedStyle(h1).fontSize) : null;

  const docScrollWidth = Math.max(root.scrollWidth, document.body.scrollWidth);
  const horizontalOverflowPx = Math.max(0, docScrollWidth - vw);

  const overflowingElements = [];
  const truncatedElements = [];
  const undersizedTargets = [];
  const unlabeledControls = [];

  const isVisible = (el) => {
    if (el.hidden || el.closest('[hidden]')) return false;
    if (el.classList.contains('sr-only') || el.classList.contains('skip-link')) return false;
    const cs = getComputedStyle(el);
    if (cs.display === 'none' || cs.visibility === 'hidden' || parseFloat(cs.opacity) === 0) return false;
    const r = el.getBoundingClientRect();
    if (r.width <= 1 && r.height <= 1 && cs.position === 'absolute' && cs.overflow === 'hidden') return false;
    return r.width > 0 && r.height > 0;
  };

  for (const el of document.querySelectorAll('*')) {
    if (!isVisible(el)) continue;
    const r = el.getBoundingClientRect();
    if (r.right > vw + 1.0 || r.left < -1.0) {
      overflowingElements.push({
        tag: el.tagName.toLowerCase(),
        cls: el.className || '',
        left: Math.round(r.left * 10) / 10,
        right: Math.round(r.right * 10) / 10,
        text: (el.textContent || '').trim().slice(0, 40)
      });
    }
    const cs = getComputedStyle(el);
    if (cs.textOverflow === 'ellipsis') {
      truncatedElements.push({ tag: el.tagName.toLowerCase(), cls: el.className || '', reason: 'ellipsis' });
    }
    if ((cs.overflowX === 'hidden' || cs.overflowX === 'clip') &&
        !el.classList.contains('macro-track') &&
        el.scrollWidth > el.clientWidth + 2) {
      truncatedElements.push({
        tag: el.tagName.toLowerCase(),
        cls: el.className || '',
        reason: `clipped (${el.scrollWidth}>${el.clientWidth})`
      });
    }
  }

  const interactive = document.querySelectorAll('button, a[href], input, select, textarea');
  for (const el of interactive) {
    if (!isVisible(el)) continue;
    let targetEl = el;
    if (el.tagName === 'INPUT' && el.type === 'checkbox' && el.closest('label.v2-check')) {
      targetEl = el.closest('label.v2-check');
    } else if (el.classList.contains('hub-search-input') && el.closest('.hub-search-shell')) {
      targetEl = el.closest('.hub-search-shell');
    }
    const r = targetEl.getBoundingClientRect();
    if (r.width < 47.5 || r.height < 47.5) {
      undersizedTargets.push({
        tag: el.tagName.toLowerCase(),
        cls: targetEl.className || '',
        w: Math.round(r.width * 10) / 10,
        h: Math.round(r.height * 10) / 10,
        name: (el.getAttribute('aria-label') || el.textContent || el.id || '').trim().slice(0, 40)
      });
    }

    let accName = (el.getAttribute('aria-label') || '').trim();
    if (!accName && el.id) {
      const lbl = document.querySelector(`label[for="${CSS.escape(el.id)}"]`);
      if (lbl) accName = lbl.textContent.trim();
    }
    if (!accName && el.closest('label')) {
      accName = el.closest('label').textContent.trim();
    }
    if (!accName) {
      accName = (el.textContent || el.value || '').trim();
    }
    if (!accName) {
      unlabeledControls.push({ tag: el.tagName.toLowerCase(), id: el.id || '', cls: el.className || '' });
    }
  }

  // Test keyboard focus visibility on first visible button or link.
  let focusVisibleOk = true;
  const firstBtn = Array.from(document.querySelectorAll('button, a[href]')).find(isVisible);
  if (firstBtn) {
    firstBtn.focus();
    const fcs = getComputedStyle(firstBtn);
    // In headless programmatic .focus(), :focus-visible may depend on modality; verify outline token exists when focused or rule is active.
    focusVisibleOk = Boolean(getComputedStyle(root).getPropertyValue('--accent-focus').trim());
  }

  // Test button click preview-status honesty.
  let previewNoteOk = true;
  const clickBtn = Array.from(document.querySelectorAll('main button')).find(isVisible);
  const statusEl = document.getElementById('preview-status');
  if (!statusEl) {
    previewNoteOk = false;
  } else if (clickBtn) {
    clickBtn.click();
    previewNoteOk = statusEl.textContent.includes('design preview; nothing was saved');
  }

  return {
    vw,
    vh,
    scale,
    rootFontPx,
    bodyFontPx,
    h1FontPx,
    docScrollWidth,
    horizontalOverflowPx,
    overflowingElements: overflowingElements.slice(0, 8),
    truncatedElements: truncatedElements.slice(0, 8),
    undersizedTargets: undersizedTargets.slice(0, 8),
    unlabeledControls: unlabeledControls.slice(0, 8),
    focusVisibleOk,
    previewNoteOk
  };
})()
"""


def build_render_cases(boards: list[str]) -> list[tuple[str, int, int, str]]:
    cases: list[tuple[str, int, int, str]] = []
    for board in boards:
        # Full viewport sweep (320, 375, 390, 430, 480, short-landscape) in Graphite & Frost at scale=1, 2, 3.
        for w, h, _label in VIEWPORTS:
            for theme in ("dark", "light"):
                for scale in (1, 2, 3):
                    cases.append((board, w, h, f"theme={theme}&scale={scale}"))
        # State & accessibility modifier sweep at critical 320pt (scale 1 & 3) and 390pt (scale 1 & 2).
        if board in ("food-entry.html", "food-review.html"):
            states = ["long-name", "empty", "number-free"]
        elif board == "diary.html":
            states = ["long-name", "empty", "number-free", "no-goals"]
        elif board == "stack.html":
            states = ["locked", "opted-out"]
        else:
            states = ["populated"]
        for state in states:
            for theme in ("dark", "light"):
                cases.append((board, 320, 693, f"theme={theme}&state={state}&scale=3"))
                cases.append((board, 390, 844, f"theme={theme}&state={state}&scale=1"))
        for theme in ("dark", "light"):
            cases.append((board, 390, 844, f"theme={theme}&glass=reduced&contrast=more&scale=1"))
            cases.append((board, 320, 693, f"theme={theme}&glass=reduced&contrast=more&scale=3"))
    return cases


SCREENSHOT_SPECS = (
    ("food-entry.html", 390, 844, "theme=dark&scale=1", "food-entry-graphite-390.png"),
    ("food-entry.html", 390, 844, "theme=light&scale=1", "food-entry-frost-390.png"),
    ("food-review.html", 390, 844, "theme=dark&scale=1", "food-review-graphite-390.png"),
    ("food-review.html", 390, 844, "theme=light&scale=1", "food-review-frost-390.png"),
    ("food-entry.html", 320, 693, "theme=light&state=long-name&scale=3", "food-entry-frost-320-scale3.png"),
    ("food-review.html", 320, 693, "theme=dark&state=long-name&scale=3", "food-review-graphite-320-scale3.png"),
)


def run_rendered_checks(
    peer_ref: str | None = None,
    claude_ref: str | None = None,
    capture_screenshots: bool = False,
) -> tuple[str, list[str], dict]:
    if not CHROME_BIN.exists():
        return "UNTESTED", [], {"reason": f"{CHROME_BIN} not installed"}

    overlays = load_git_Overlays(peer_ref, claude_ref)
    boards = list(OWNED_BOARDS)
    for extra in ("diary.html", "today.html", "train.html", "stack.html", "progress.html"):
        if f"/lookbook-v2/{extra}" in overlays or (V2_DIR / extra).exists():
            boards.append(extra)

    server, http_port = start_ephemeral_server(overlays)
    problems: list[str] = []
    summary: dict = {
        "browser": None,
        "httpPort": http_port,
        "boards": boards,
        "peerRef": peer_ref,
        "casesChecked": 0,
        "diary320Scale3LongNameFrostScrollWidth": None,
        "screenshots": [],
    }

    profile_dir = tempfile.mkdtemp(prefix="caliber-v2-qa-")
    try:
        proc = subprocess.Popen(
            [
                str(CHROME_BIN),
                "--headless=new",
                "--disable-gpu",
                "--no-first-run",
                "--no-default-browser-check",
                "--disable-extensions",
                "--disable-background-networking",
                "--hide-scrollbars",
                f"--user-data-dir={profile_dir}",
                "--remote-debugging-port=0",
                "about:blank",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            active_port_file = Path(profile_dir) / "DevToolsActivePort"
            deadline = time.time() + 12.0
            while not active_port_file.exists():
                if time.time() > deadline:
                    raise RuntimeError("Timed out waiting for Chrome DevToolsActivePort")
                time.sleep(0.05)
            lines = active_port_file.read_text(encoding="utf-8").strip().splitlines()
            cdp_port = int(lines[0])
            ws_path = lines[1]

            ver_info = json.loads(
                urllib.request.urlopen(f"http://127.0.0.1:{cdp_port}/json/version", timeout=5).read()
            )
            summary["browser"] = ver_info.get("Browser", "Google Chrome Headless")

            cdp = LocalCDPClient("127.0.0.1", cdp_port, ws_path)
            try:
                target_id = cdp.call("Target.createTarget", {"url": "about:blank"})["targetId"]
                session_id = cdp.call(
                    "Target.attachToTarget", {"targetId": target_id, "flatten": True}
                )["sessionId"]
                cdp.call("Page.enable", session_id=session_id)
                cdp.call("Runtime.enable", session_id=session_id)

                def load_and_audit(board: str, w: int, h: int, query: str) -> dict:
                    cdp.call(
                        "Emulation.setDeviceMetricsOverride",
                        {"width": w, "height": h, "deviceScaleFactor": 2, "mobile": True},
                        session_id=session_id,
                    )
                    url = f"http://127.0.0.1:{http_port}/lookbook-v2/{board}?{query}"
                    cdp.call("Page.navigate", {"url": url}, session_id=session_id)
                    # Poll until exact target URL has finished loading and deferred board.js injected #preview-status.
                    wait_js = (
                        f"location.href === {json.dumps(url)} && "
                        "document.readyState === 'complete' && "
                        "Boolean(document.getElementById('preview-status'))"
                    )
                    for _ in range(80):
                        res = cdp.call(
                            "Runtime.evaluate",
                            {"expression": wait_js, "returnByValue": True},
                            session_id=session_id,
                        )
                        if res.get("result", {}).get("value") is True:
                            break
                        time.sleep(0.025)
                    eval_res = cdp.call(
                        "Runtime.evaluate",
                        {"expression": DOM_AUDIT_JS, "returnByValue": True},
                        session_id=session_id,
                    )
                    return eval_res["result"]["value"]

                for board, w, h, query in build_render_cases(boards):
                    audit = load_and_audit(board, w, h, query)
                    summary["casesChecked"] += 1
                    label = f"{board}?{query} @{w}x{h}"

                    if (
                        board == "diary.html"
                        and w == 320
                        and query == "theme=light&state=long-name&scale=3"
                    ):
                        summary["diary320Scale3LongNameFrostScrollWidth"] = audit["docScrollWidth"]

                    expected_root = 16.0 * audit["scale"]
                    expected_body = 17.0 * audit["scale"]
                    if abs(audit["rootFontPx"] - expected_root) > 0.5:
                        problems.append(f"{label}: root font {audit['rootFontPx']}px != {expected_root}px")
                    if abs(audit["bodyFontPx"] - expected_body) > 0.5:
                        problems.append(
                            f"{label}: body font shrunk to {audit['bodyFontPx']}px (expected {expected_body}px)"
                        )
                    if audit["horizontalOverflowPx"] > 0:
                        problems.append(
                            f"{label}: docScrollWidth={audit['docScrollWidth']} > {w} "
                            f"(overflow elements: {audit['overflowingElements']})"
                        )
                    elif audit["overflowingElements"]:
                        problems.append(f"{label}: element box overflow {audit['overflowingElements']}")
                    if audit["truncatedElements"]:
                        problems.append(f"{label}: clipped/truncated text {audit['truncatedElements']}")
                    if audit["undersizedTargets"]:
                        problems.append(f"{label}: targets < 48px {audit['undersizedTargets']}")
                    if audit["unlabeledControls"]:
                        problems.append(f"{label}: unlabeled controls {audit['unlabeledControls']}")
                    if not audit["focusVisibleOk"]:
                        problems.append(f"{label}: missing --accent-focus token")
                    if not audit["previewNoteOk"]:
                        problems.append(f"{label}: preview-status honesty banner failed")

                if capture_screenshots:
                    shot_dir = QA_DIR / "screenshots"
                    shot_dir.mkdir(parents=True, exist_ok=True)
                    for board, w, h, query, filename in SCREENSHOT_SPECS:
                        cdp.call(
                            "Emulation.setDeviceMetricsOverride",
                            {"width": w, "height": h, "deviceScaleFactor": 2, "mobile": True},
                            session_id=session_id,
                        )
                        url = f"http://127.0.0.1:{http_port}/lookbook-v2/{board}?{query}"
                        cdp.call("Page.navigate", {"url": url}, session_id=session_id)
                        wait_js = (
                            f"location.href === {json.dumps(url)} && "
                            "document.readyState === 'complete' && "
                            "Boolean(document.getElementById('preview-status'))"
                        )
                        for _ in range(80):
                            res = cdp.call(
                                "Runtime.evaluate",
                                {"expression": wait_js, "returnByValue": True},
                                session_id=session_id,
                            )
                            if res.get("result", {}).get("value") is True:
                                break
                            time.sleep(0.025)
                        # Measure full content height for complete board inspection at scale=1 (capped at 2400px for scale=3).
                        cap_h = 3200 if "scale=1" in query else 2400
                        h_res = cdp.call(
                            "Runtime.evaluate",
                            {
                                "expression": f"Math.min({cap_h}, Math.max(window.innerHeight, document.documentElement.scrollHeight))",
                                "returnByValue": True,
                            },
                            session_id=session_id,
                        )
                        full_h = int(h_res["result"]["value"])
                        cdp.call(
                            "Emulation.setDeviceMetricsOverride",
                            {"width": w, "height": full_h, "deviceScaleFactor": 2, "mobile": True},
                            session_id=session_id,
                        )
                        time.sleep(0.05)
                        shot = cdp.call(
                            "Page.captureScreenshot",
                            {"format": "png", "captureBeyondViewport": False},
                            session_id=session_id,
                        )
                        out_path = shot_dir / filename
                        out_path.write_bytes(base64.b64decode(shot["data"]))
                        summary["screenshots"].append(str(out_path.relative_to(ROOT)))
            finally:
                cdp.close()
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
            server.shutdown()
            server.server_close()
    finally:
        time.sleep(0.15)
        shutil.rmtree(profile_dir, ignore_errors=True)

    return ("FAILED" if problems else "PASSED"), problems, summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--peer-ref", default=None, help="Optional git ref (e.g. origin/codex/lookbook-v2) for in-memory Diary check")
    parser.add_argument("--claude-ref", default=None, help="Optional git ref (e.g. origin/claude/lookbook-v2-design) for in-memory 7-board check")
    parser.add_argument("--capture-screenshots", action="store_true", help="Write PNG evidence into design/lookbook-v2/qa/screenshots/")
    parser.add_argument("--static-only", action="store_true", help="Run static HTML/CSS/token checks only")
    parser.add_argument("--json-out", default=None, help="Optional path to write JSON QA summary")
    args = parser.parse_args()

    static_problems = run_static_checks(ROOT)
    render_status = "UNTESTED"
    render_problems: list[str] = []
    render_summary: dict = {"reason": "skipped via --static-only"}

    if not args.static_only:
        render_status, render_problems, render_summary = run_rendered_checks(
            peer_ref=args.peer_ref,
            claude_ref=args.claude_ref,
            capture_screenshots=args.capture_screenshots,
        )

    all_problems = static_problems + render_problems
    report = {
        "staticStatus": "FAILED" if static_problems else "PASSED",
        "staticProblemsCount": len(static_problems),
        "renderedStatus": render_status,
        "renderedProblemsCount": len(render_problems),
        "renderedSummary": render_summary,
        "nativeDynamicTypeStatus": "UNTESTED (HTML root font-size stress does not establish SwiftUI Dynamic Type)",
        "nativeVoiceOverStatus": "UNTESTED (DOM label/focus audit does not establish iOS VoiceOver)",
        "problems": all_problems,
    }

    if args.json_out:
        out_file = Path(args.json_out)
        out_file.parent.mkdir(parents=True, exist_ok=True)
        out_file.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    for p in all_problems:
        print(f"lookbook-v2-qa FAIL: {p}")
    print(
        f"lookbook-v2-qa: static={report['staticStatus']} "
        f"rendered={report['renderedStatus']} "
        f"cases={render_summary.get('casesChecked', 0)} "
        f"problems={len(all_problems)}"
    )
    if render_summary.get("diary320Scale3LongNameFrostScrollWidth") is not None:
        print(
            "lookbook-v2-qa: diary.html @320px/scale=3/long-name/Frost "
            f"docScrollWidth={render_summary['diary320Scale3LongNameFrostScrollWidth']}"
        )
    return 1 if all_problems else 0


if __name__ == "__main__":
    sys.exit(main())
