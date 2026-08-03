# SPECS.md — httpd-next technical specification

Normative contract for `wsams/httpd-next`. If code and this document disagree, update one of them in the same change. Product intent and agent workflow live in [AGENTS.md](./AGENTS.md); user-facing usage lives in [README.md](./README.md).

## 1. Purpose

Provide opinionated Docker images that:

1. Terminate TLS and serve static files at an **Nginx** edge.
2. Reverse-proxy to **independent** language runtimes (never language modules inside the web server).
3. Ship as **flavor tags** (single-runtime) plus one **stack** (polyglot) tag.
4. Publish via **semantic-release** + Docker Hub, with **Renovate** keeping dependencies current.

Legacy Apache / `mod_php` / `mod_wsgi` / CGI workflows remain in [`wsams/httpd`](https://github.com/wsams/httpd) and are out of scope here.

## 2. Non-goals

- Reintroducing Apache, `mod_php`, `mod_wsgi`, or Go CGI.
- Making FrankenPHP / Caddy the default edge (optional future flavor only).
- Orchestrating multi-container apps (compose examples may mount code; the image itself is a single container with s6).
- Application frameworks as first-class image contents (examples are smoke-test fixtures, not product features).

## 3. Architecture

```
                          ┌──> PHP-FPM   unix:/run/php/php-fpm.sock
[ Client ] ──> [ Nginx ] ─┼──> Python    http://127.0.0.1:8000   (Uvicorn/ASGI)
                          └──> Go        http://127.0.0.1:8080   (net/http)
```

| Layer | Technology | Role |
| --- | --- | --- |
| Edge | Nginx | TLS, static files, `fastcgi_pass` / `proxy_pass`, security headers |
| Supervisor | s6-overlay v3 | Starts/reaps long-running services (`/init` entrypoint) |
| PHP | PHP-FPM (distro package, currently 8.5 on Ubuntu 26.04) | FastCGI over Unix socket |
| Python | Uvicorn | ASGI app process |
| Go | Prebuilt binary (+ optional toolchain in go/stack) | HTTP listener for `proxy_pass` |
| Base OS | Ubuntu 26.04 | Same family as `wsams/httpd` |

### 3.1 Process model

- Image `ENTRYPOINT` is `/init` (s6-overlay).
- Longruns live under `/etc/s6-overlay/s6-rc.d/<service>/{type,run}` with `type` = `longrun`.
- Services are enabled by empty files in `/etc/s6-overlay/user-bundles.d/user/contents.d/<service>` (not the deprecated `s6-rc.d/user/contents.d` path).
- Nginx `run` scripts render the active template with `envsubst` before `exec nginx`.

### 3.2 Routing contracts

| Flavor | Template | Behavior |
| --- | --- | --- |
| base | `docker/nginx/templates/base.conf.template` | Static only from `/var/www/html` |
| php | `php.conf.template` | Static + `*.php` → `unix:/run/php/php-fpm.sock` |
| python | `python.conf.template` | All locations → `http://127.0.0.1:8000` |
| go | `go.conf.template` | All locations → `http://127.0.0.1:8080` |
| stack | `stack.conf.template` | See table below |

**Stack routes (normative):**

| Path | Backend |
| --- | --- |
| `/api/py/` | Uvicorn (`proxy_pass` strips prefix to `/`) |
| `/api/go/` | Go app (`proxy_pass` strips prefix to `/`) |
| `*.php` and `/` fallback | PHP-FPM FastCGI |
| Dotfiles (`/\.`) | Denied |

HTTP (80) and HTTPS (443, HTTP/2) server blocks must stay behaviorally aligned within each template.

## 4. Image catalog

Published repository: **`wsams/httpd-next`** (Docker Hub).

| Versioned tag | Floating tag | Nightly | Contents |
| --- | --- | --- | --- |
| `x.y.z` | `latest` | `nightly` | Nginx edge |
| `php-x.y.z` | `php` | `php-nightly` | + PHP-FPM |
| `python-x.y.z` | `python` | `python-nightly` | + Uvicorn |
| `go-x.y.z` | `go` | `go-nightly` | + Go binary (+ toolchain) |
| `stack-x.y.z` | `stack` | `stack-nightly` | + PHP-FPM + Uvicorn + Go |

Nightly also publishes date stamps: `nightly-YYYYMMDD` (and flavor prefixes via the build script).

### 4.1 Dockerfile map

| File | Stage notes |
| --- | --- |
| `Dockerfile` | Base; installs Nginx + s6-overlay; self-signed cert |
| `Dockerfile.php` | `FROM` base; PHP-FPM + Composer + security.ini |
| `Dockerfile.python` | `FROM` base; pip-installs `examples/python/requirements.txt` |
| `Dockerfile.go` | Multi-stage: build `examples/go` → copy into base; also installs `golang-go` for in-container builds |
| `Dockerfile.stack` | Multi-stage Go build + PHP + Python on base |

`ARG BASE_IMAGE` and `ARG GO_BUILD_IMAGE` for multi-stage files **must** be declared before the first `FROM` so BuildKit resolves them.

## 5. Environment variables

| Variable | Default | Flavors | Meaning |
| --- | --- | --- | --- |
| `NGINX_SERVER_NAME` | `localhost` | all | `server_name` |
| `SSL_CERTIFICATE_FILE` | `/nginx-cert.pem` | all | TLS cert path |
| `SSL_CERTIFICATE_KEY_FILE` | `/nginx-key.pem` | all | TLS key path |
| `NGINX_TEMPLATE` | flavor-specific path under `/etc/nginx/templates/` | all | Template rendered to `/etc/nginx/conf.d/default.conf` |
| `PYTHON_APP_MODULE` | `app:app` | python, stack | Uvicorn import path |
| `PYTHON_APP_DIR` | `/var/www/python` | python, stack | Working directory for the app |
| `PYTHON_HOST` | `127.0.0.1` | python, stack | Uvicorn bind host |
| `PYTHON_PORT` | `8000` | python, stack | Uvicorn bind port |
| `GO_APP_BIN` | `/usr/local/bin/goapp` | go, stack | Binary executed by s6 |
| `GO_APP_ADDR` | `127.0.0.1:8080` | go, stack | Listen address (read by the example Go app) |
| `S6_KEEP_ENV` | `1` | all | Preserve env into s6 services |
| `S6_BEHAVIOUR_IF_STAGE2_FAILS` | `2` | all | Fail container if stage-2 setup fails |

Internal marker file: `/etc/httpd-next-php-version` contains the distro PHP `X.Y` string used by the php-fpm s6 run script.

## 6. Filesystem layout (repository)

```
.
├── AGENTS.md                 # Intent, constraints, agent workflow
├── SPECS.md                  # This file (normative contracts)
├── README.md                 # User-facing usage
├── Dockerfile*               # Image definitions
├── docker/
│   ├── install-s6.sh         # s6-overlay installer
│   ├── nginx/                # nginx.conf + templates
│   ├── php/                  # FPM pool + security.ini
│   └── s6/<flavor>/<svc>/    # type + run scripts
├── examples/                 # Smoke-test / demo apps
├── scripts/
│   ├── build-images.sh       # Build (+ optional push) all flavors
│   └── test-images.sh        # HTTP/HTTPS smoke tests
├── Makefile
├── sample.docker-compose.yml
├── package.json              # semantic-release deps only
├── release.config.cjs
├── renovate.json
└── .github/workflows/        # ci, semantic-release, renovate, nightly, republish
```

### 6.1 Example app contracts (smoke tests)

| Path | Must respond with substring |
| --- | --- |
| base `/` | `Nginx is working` |
| php `/` | `PHP-FPM is working` |
| python `/` | `Python (Uvicorn/ASGI) is working` |
| go `/` | `Go is working` |
| stack `/` | `PHP-FPM is working` |
| stack `/api/py/` | `Python (Uvicorn/ASGI) is working` |
| stack `/api/go/` | `Go is working` |

Examples must remain small and framework-light so CI stays fast.

## 7. Security defaults

Required for all HTTPS server blocks:

- `server_tokens off` (global nginx.conf)
- No directory autoindex
- `Strict-Transport-Security` with long max-age
- `X-Frame-Options DENY`
- `X-Content-Type-Options nosniff`
- `Referrer-Policy strict-origin-when-cross-origin`
- Restrictive `Content-Security-Policy` default (`default-src 'self'; frame-ancestors 'none'; base-uri 'self'`)
- PHP: `expose_php = Off`, hide `X-Powered-By` via FastCGI, `cgi.fix_pathinfo = 0`, dangerous URL wrappers off (see `docker/php/security.ini`)
- Deny access to `/\.` paths in PHP/stack templates
- Self-signed cert shipped for local/dev only; production must mount real certs via the SSL env vars

## 8. Build, test, and release

### 8.1 Local

```bash
make test                    # build + smoke-test VERSION=local
IMAGE_NAME=wsams/httpd-next ./scripts/build-images.sh <version>
IMAGE_NAME=wsams/httpd-next ./scripts/test-images.sh <version>
```

`scripts/build-images.sh` builds base → php → python → go → stack. Optional env:

- `PUSH=true` — push versioned tags
- `FLOAT_BASE` / `FLOAT_PHP` / `FLOAT_PYTHON` / `FLOAT_GO` / `FLOAT_STACK` — comma-separated floating tags to retag (and push if `PUSH=true`)
- `PLATFORM` — passed to `docker build --platform` when set

### 8.2 CI

- Workflow: `.github/workflows/ci.yml`
- Triggers: PRs and pushes to `main`
- Builds tag `ci` and runs `scripts/test-images.sh ci`

### 8.3 semantic-release

- Workflow: `.github/workflows/semantic-release.yml` on push to `main`
- Runs **`npx semantic-release` directly** (no third-party release action wrapper such as codfish)
- Branch: `main` (`release.config.cjs`)
- On publish: `@semantic-release/exec` runs `build-images.sh` with `PUSH=true` and floating tags `latest`, `php`, `python`, `go`, `stack`
- Conventional commits drive version bumps (`feat:` → minor, `fix:` → patch, `BREAKING CHANGE` → major)

### 8.4 Renovate

- Workflow: `.github/workflows/renovate.yml` on **nightly** cron `0 6 * * *` (+ `workflow_dispatch`)
- Config: `renovate.json` + `.github/renovate-config.json` (`repositories: ["wsams/httpd-next"]`)
- Token secret: `RENOVATE_TOKEN`
- Automerge: enabled for all update types (patch/minor/major/digest); requires repo **Allow auto-merge**
- Commit style: `fix(deps):` so merges can trigger semantic-release

### 8.5 Nightly / republish images

- Nightly: `.github/workflows/docker-nightly.yml` (`0 3 * * *`)
- Manual republish: `.github/workflows/docker-publish.yml` (`workflow_dispatch` with version)
- Docker Hub secrets: `DOCKER_USERNAME`, `DOCKER_PASSWORD`

## 9. Compatibility and upgrade notes

- Base OS tracks Ubuntu LTS/interim used by `wsams/httpd` (currently **26.04**). Distro PHP minor (e.g. 8.5) may change with Ubuntu; do not hardcode `php8.5-*` package names unless necessary — prefer `php-*` metapackages and detect `PHP_VER` at build time.
- OpCache may ship inside `php-common` rather than a separate `php-opcache` package; do not assume the latter exists.
- Go example uses Go 1.22+ routing (`GET /{$}`). Build image default: `golang:1.24-bookworm`.
- Python example targets ASGI callable `app` in module `app`; keep `uvicorn[standard]` pinned in `examples/python/requirements.txt`.

## 10. Change checklist

When changing behavior, update in the same PR:

1. Relevant `Dockerfile*` / `docker/**` / `examples/**` / `scripts/**`
2. This `SPECS.md` if contracts, tags, env vars, routes, or automation change
3. `AGENTS.md` if constraints or agent workflow change
4. `README.md` if user-facing usage changes
5. Smoke expectations in `scripts/test-images.sh` if response text or routes change
