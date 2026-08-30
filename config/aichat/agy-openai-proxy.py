#!/usr/bin/env python3
"""OpenAI-compatible shim so AIChat can use a logged-in `agy` CLI."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

HOST: str = "127.0.0.1"
PORT: int = 18741
AGY_TIMEOUT_SECONDS: int = 55
AGY_PRINT_TIMEOUT: str = "45s"
AGY_MODEL: str = "gemini-3.7-flash-low"


def resolve_agy() -> str:
    extra_paths: list[str] = [
        str(Path.home() / ".local" / "bin"),
        str(Path.home() / ".antigravity" / "antigravity" / "bin"),
    ]
    search_path: str = os.pathsep.join(extra_paths + [os.environ.get("PATH", "")])
    agy_path: str | None = shutil.which("agy", path=search_path)
    if agy_path is None:
        raise FileNotFoundError("agy not found; install Antigravity CLI and sign in")
    return agy_path


def strip_code_fences(text: str) -> str:
    stripped: str = text.strip()
    if not stripped.startswith("```"):
        return stripped
    lines: list[str] = stripped.splitlines()
    if lines and lines[0].startswith("```"):
        lines = lines[1:]
    if lines and lines[-1].strip() == "```":
        lines = lines[:-1]
    return "\n".join(lines).strip()


def messages_to_prompt(messages: list[dict[str, Any]]) -> str:
    parts: list[str] = []
    for message in messages:
        role: str = str(message.get("role", "user"))
        content: Any = message.get("content", "")
        if isinstance(content, list):
            texts: list[str] = []
            for item in content:
                if isinstance(item, dict) and item.get("type") == "text":
                    texts.append(str(item.get("text", "")))
                elif isinstance(item, str):
                    texts.append(item)
            content = "\n".join(texts)
        parts.append(f"{role}: {content}")
    return "\n\n".join(parts)


def complete_with_agy(prompt: str) -> str:
    agy_path: str = resolve_agy()
    completed: subprocess.CompletedProcess[str] = subprocess.run(
        [
            agy_path,
            "--model",
            AGY_MODEL,
            "--effort",
            "low",
            "--output-format",
            "text",
            "--print-timeout",
            AGY_PRINT_TIMEOUT,
            "--dangerously-skip-permissions",
            "-p",
            prompt,
        ],
        capture_output=True,
        text=True,
        timeout=AGY_TIMEOUT_SECONDS,
        env=os.environ.copy(),
    )
    if completed.returncode != 0:
        detail: str = (completed.stderr or completed.stdout or "agy failed").strip()
        if "timeout waiting for response" in detail:
            raise RuntimeError(
                "agy is logged in, but print mode never returned text "
                "(agy -p timed out). Interactive `agy` may still work."
            )
        raise RuntimeError(detail)
    if not (completed.stdout or "").strip():
        raise RuntimeError("agy -p returned empty output")
    return strip_code_fences(completed.stdout or "")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args: Any) -> None:
        return

    def _send_json(self, status: int, payload: dict[str, Any]) -> None:
        body: bytes = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path in ("/health", "/v1/health"):
            self._send_json(200, {"ok": True})
            return
        if self.path.startswith("/v1/models"):
            self._send_json(
                200,
                {
                    "object": "list",
                    "data": [{"id": "default", "object": "model", "owned_by": "agy"}],
                },
            )
            return
        self._send_json(404, {"error": {"message": "not found"}})

    def do_POST(self) -> None:
        if not self.path.startswith("/v1/chat/completions"):
            self._send_json(404, {"error": {"message": "not found"}})
            return
        length: int = int(self.headers.get("Content-Length", "0"))
        raw: bytes = self.rfile.read(length) if length > 0 else b"{}"
        try:
            request: dict[str, Any] = json.loads(raw.decode("utf-8"))
            prompt: str = messages_to_prompt(request.get("messages") or [])
            content: str = complete_with_agy(prompt)
        except Exception as err:
            self._send_json(502, {"error": {"message": str(err)}})
            return
        self._send_json(
            200,
            {
                "id": "chatcmpl-agy",
                "object": "chat.completion",
                "model": request.get("model", "default") if isinstance(request, dict) else "default",
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": content},
                        "finish_reason": "stop",
                    }
                ],
            },
        )


def main() -> None:
    server: ThreadingHTTPServer = ThreadingHTTPServer((HOST, PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    try:
        main()
    except OSError as err:
        sys.stderr.write(f"agy-openai-proxy failed to bind {HOST}:{PORT}: {err}\n")
        sys.exit(1)
