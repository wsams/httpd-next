# httpd-next

Modern successor to [`wsams/httpd`](https://github.com/wsams/httpd). The legacy Apache + `mod_php` / `mod_wsgi` images remain supported in that repository; this project is the Nginx reverse-proxy stack with independent app runtimes.

```
                          ┌──> PHP-FPM  unix:/run/php/php-fpm.sock
[ Client ] ──> [ Nginx ] ─┼──> Python   http://127.0.0.1:8000  (Uvicorn/ASGI)
                          └──> Go       http://127.0.0.1:8080  (net/http)
```

Project docs:

* [SPECS.md](./SPECS.md) — normative technical contracts (tags, routes, env vars, security, release)
* [AGENTS.md](./AGENTS.md) — intent, hard constraints, and how to maintain this repo

## Image tags

Published as `wsams/httpd-next` on Docker Hub:

| Tag | Contents |
| --- | --- |
| `x.y.z` / `latest` | Nginx edge (static + TLS + security defaults) |
| `php-x.y.z` / `php` | Nginx + PHP-FPM (s6-overlay) |
| `python-x.y.z` / `python` | Nginx + Uvicorn ASGI (s6-overlay) |
| `go-x.y.z` / `go` | Nginx + Go HTTP binary (s6-overlay) |
| `stack-x.y.z` / `stack` | Polyglot: PHP-FPM + Uvicorn + Go behind one Nginx |

Nightly tags: `nightly`, `php-nightly`, `python-nightly`, `go-nightly`, `stack-nightly`.

### Stack routes

| Path | Backend |
| --- | --- |
| `/` and `*.php` | PHP-FPM |
| `/api/py/` | Uvicorn |
| `/api/go/` | Go binary |

## Environment variables

| Variable | Default | Used by |
| --- | --- | --- |
| `NGINX_SERVER_NAME` | `localhost` | all |
| `SSL_CERTIFICATE_FILE` | `/nginx-cert.pem` | all |
| `SSL_CERTIFICATE_KEY_FILE` | `/nginx-key.pem` | all |
| `NGINX_TEMPLATE` | flavor-specific | all |
| `PYTHON_APP_MODULE` | `app:app` | python, stack |
| `PYTHON_APP_DIR` | `/var/www/python` | python, stack |
| `PYTHON_HOST` / `PYTHON_PORT` | `127.0.0.1` / `8000` | python, stack |
| `GO_APP_BIN` | `/usr/local/bin/goapp` | go, stack |
| `GO_APP_ADDR` | `127.0.0.1:8080` | go, stack |

## Build and test locally

```bash
make test                 # build + smoke-test all flavors as :local
make build VERSION=ci     # build only
./scripts/test-images.sh local
```

Or individually:

```bash
docker build -t wsams/httpd-next:local --rm --pull .
docker build -t wsams/httpd-next:php-local -f Dockerfile.php --build-arg BASE_IMAGE=wsams/httpd-next:local .
docker build -t wsams/httpd-next:python-local -f Dockerfile.python --build-arg BASE_IMAGE=wsams/httpd-next:local .
docker build -t wsams/httpd-next:go-local -f Dockerfile.go --build-arg BASE_IMAGE=wsams/httpd-next:local .
docker build -t wsams/httpd-next:stack-local -f Dockerfile.stack --build-arg BASE_IMAGE=wsams/httpd-next:local .
```

Example compose file: `sample.docker-compose.yml`. After `make up` (or `docker compose -f sample.docker-compose.yml up -d`), open `https://localhost` (self-signed cert).

Example apps live under `examples/` (`php/`, `python/`, `go/`, `static/`).

## Releases and automation

* **CI** builds every flavor and runs `scripts/test-images.sh` on pushes/PRs to `main`.
* **semantic-release** runs directly on pushes to `main` (`npx semantic-release` — not a third-party action wrapper). It creates the GitHub release/tag, then builds and pushes Docker Hub flavors for that version plus floating tags (`latest`, `php`, `python`, `go`, `stack`).
* **Nightly Docker images** rebuild and push the nightly tags.
* **Renovate** runs from a nightly GitHub Actions workflow, opens dependency PRs with `fix(deps):` commits, and automerges (enable **Allow auto-merge** in repo settings). Merges to `main` can produce a new semantic-release and image publish.
* **Republish Docker images** manually rebuilds/pushes a given version if needed.

### Secrets

| Secret | Purpose |
| --- | --- |
| `RENOVATE_TOKEN` | Classic PAT (or GitHub App token) with `repo` + `workflow` for the Renovate workflow |
| `REGISTERY_USERNAME` | Docker Hub username (spelling matches the parent `httpd` repo) |
| `REGISTRY_PASSWORD` | Docker Hub password/token |

## What changed vs `wsams/httpd`

| Legacy (`httpd`) | Next (`httpd-next`) |
| --- | --- |
| Apache + `mod_php` | Nginx + PHP-FPM |
| Apache + `mod_wsgi` | Nginx + Uvicorn (ASGI) |
| Apache CGI for Go | Compiled Go binary + `proxy_pass` |
| Single-process foreground scripts | s6-overlay multi-process supervision |
| Optional nginx sibling flavor | Nginx is the only edge |
