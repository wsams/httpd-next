"""Minimal ASGI app for the httpd-next python flavor."""

from __future__ import annotations

async def app(scope: dict, receive, send) -> None:
    if scope["type"] != "http":
        return

    path = scope.get("path", "/")
    body = (
        "<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'>"
        "<title>httpd-next python</title></head><body>"
        "<h1>Python (Uvicorn/ASGI) is working</h1>"
        f"<p>Path: {path}</p>"
        "</body></html>"
    ).encode("utf-8")

    await send(
        {
            "type": "http.response.start",
            "status": 200,
            "headers": [
                (b"content-type", b"text/html; charset=utf-8"),
                (b"content-length", str(len(body)).encode("ascii")),
            ],
        }
    )
    await send({"type": "http.response.body", "body": body})
