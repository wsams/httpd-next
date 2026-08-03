# AGENTS.md

## Overview & Vision

This repository (`wsams/httpd-next`) is the modern successor to [`wsams/httpd`](https://github.com/wsams/httpd). The legacy project remains valid for Ubuntu + Apache + `mod_php` / `mod_wsgi` / CGI workflows.

**httpd-next** is a polyglot edge-proxy container stack:

* **Nginx** terminates TLS and reverse-proxies to independent app runtimes
* **PHP 8.x** via **PHP-FPM** (Unix socket FastCGI — not `mod_php`)
* **Python 3** via **Uvicorn** (ASGI — not `mod_wsgi`)
* **Go** as a compiled `net/http` binary behind `proxy_pass` (not CGI)

## Design decisions (refined from the initial summary)

| Topic | Choice | Why |
| --- | --- | --- |
| Edge server | Nginx only | Proven reverse-proxy defaults; Caddy/FrankenPHP left as optional future flavors |
| PHP | PHP-FPM over a Unix socket | Keeps the web server as a proxy; matches current production practice |
| Python | Uvicorn (ASGI) | Prefer async ASGI over legacy WSGI-in-Apache |
| Go | Standalone HTTP binary | CGI is a poor fit for Go; compile once, `proxy_pass` forever |
| Process supervisor | s6-overlay | Lightweight, container-native multi-process supervision |
| Base OS | Ubuntu (same family as `wsams/httpd`) | Familiar ops surface; easy PHP/Python packages |
| Image layout | Flavor tags + optional `stack` | Same tagging habit as the parent repo, modern internals |

Do **not** reintroduce `mod_php`, `mod_wsgi`, or Go CGI in this repository.

## Architecture

```
                          ┌──> PHP-FPM  unix:/run/php/php-fpm.sock
[ Client ] ──> [ Nginx ] ─┼──> Python   http://127.0.0.1:8000
                          └──> Go       http://127.0.0.1:8080
```

### Default route map (`stack` flavor)

| Path | Backend |
| --- | --- |
| `/` static assets | Nginx `root /var/www/html` |
| `*.php` | PHP-FPM FastCGI |
| `/api/py/` | Uvicorn |
| `/api/go/` | Go binary |

Flavor-specific images expose only the backends they ship.

## Image tags

Published as `wsams/httpd-next` on Docker Hub:

| Tag | Contents |
| --- | --- |
| `x.y.z` / `latest` | Nginx edge (static + TLS + proxy-ready) |
| `php-x.y.z` / `php` | Nginx + PHP-FPM (s6) |
| `python-x.y.z` / `python` | Nginx + Uvicorn (s6) |
| `go-x.y.z` / `go` | Nginx + Go app runner (s6) |
| `stack-x.y.z` / `stack` | Nginx + PHP-FPM + Uvicorn + Go (polyglot) |

Nightly tags: `nightly`, `php-nightly`, `python-nightly`, `go-nightly`, `stack-nightly`.

## Instructions for AI / Cursor agents

1. **Separation of concerns:** Nginx is only a reverse proxy / static server. Never embed language runtimes via Apache/Nginx modules.
2. **Security defaults:** `server_tokens off`, no directory listing, HSTS + standard security headers, hide PHP/`X-Powered-By` where applicable.
3. **Modern idioms:** PHP 8 typed code, Python 3.11+ type hints / ASGI, Go 1.22+ `ServeMux` routing.
4. **Containers:** Prefer multi-stage builds for Go binaries; keep runtime images lean; use s6 service scripts under `docker/s6/`.
5. **Automation:** semantic-release runs directly (`npx semantic-release`). Renovate runs from the nightly GitHub Actions workflow and automerges PRs.
