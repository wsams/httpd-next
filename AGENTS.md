# AGENTS.md

Guidance for humans and AI agents working in `wsams/httpd-next`.

| Doc | Role |
| --- | --- |
| [SPECS.md](./SPECS.md) | **Normative** contracts: architecture, tags, env vars, routes, security, release |
| [README.md](./README.md) | User-facing quick start and usage |
| This file | Intent, hard constraints, how to change the repo safely |

If SPECS and code disagree, fix them together in one change.

---

## Mission

Modern successor to [`wsams/httpd`](https://github.com/wsams/httpd). The legacy repo stays valid for Apache + `mod_php` / `mod_wsgi` / CGI.

**httpd-next** is a polyglot **edge proxy + app runtime** container:

* Nginx terminates TLS and reverse-proxies
* PHP via **PHP-FPM** (Unix socket)
* Python via **Uvicorn** (ASGI)
* Go via a compiled **HTTP binary** (`proxy_pass`)
* **s6-overlay** supervises processes inside one container

## Hard constraints (do not violate)

1. **No language modules in the web server.** Never add `mod_php`, `mod_wsgi`, Apache, or Go CGI to this repo.
2. **Nginx stays a reverse proxy / static server.** Runtimes are separate processes.
3. **Keep flavor tags + `stack`.** Do not collapse to a single opaque image without an explicit decision and SPECS update.
4. **Security defaults stay on** (`server_tokens off`, HSTS + headers, PHP hardenings). See SPECS §7.
5. **semantic-release runs directly** (`npx semantic-release`). Do not reintroduce wrappers like codfish.
6. **Renovate is the nightly workflow** using `RENOVATE_TOKEN`; keep automerge-oriented config unless the maintainer asks otherwise.
7. **Examples exist for smoke tests**, not as product frameworks. Keep them tiny and string-stable (SPECS §6.1).

## Design decisions (summary)

| Topic | Choice | Why |
| --- | --- | --- |
| Edge | Nginx only | Clear proxy role; Caddy/FrankenPHP are optional future flavors |
| PHP | PHP-FPM / Unix socket | Current production pattern; not `mod_php` |
| Python | Uvicorn ASGI | Prefer async ASGI over WSGI-in-Apache |
| Go | Standalone binary | CGI is a poor fit for Go |
| Supervisor | s6-overlay v3 | Container-native multi-process |
| Base OS | Ubuntu (same family as `httpd`) | Familiar packages/ops |
| Layout | Flavors + `stack` | Same tagging habit as parent, modern internals |

Full routing, env, and tag tables: [SPECS.md](./SPECS.md).

## Repository map (where to edit)

| Change | Primary paths |
| --- | --- |
| Nginx config / routes | `docker/nginx/` |
| s6 service scripts | `docker/s6/**/run` (+ enable under `user-bundles.d` in Dockerfiles) |
| PHP pool / hardenings | `docker/php/` |
| Image contents | `Dockerfile`, `Dockerfile.php`, `Dockerfile.python`, `Dockerfile.go`, `Dockerfile.stack` |
| Demo / CI fixtures | `examples/` |
| Build / smoke tests | `scripts/build-images.sh`, `scripts/test-images.sh` |
| Release | `release.config.cjs`, `.github/workflows/semantic-release.yml` |
| Renovate | `renovate.json`, `.github/workflows/renovate.yml`, `.github/renovate-config.json` |

### s6 gotchas

* Enable services with empty files in `/etc/s6-overlay/user-bundles.d/user/contents.d/<name>` (not deprecated `s6-rc.d/user/contents.d`).
* Multi-stage Dockerfiles must declare `ARG BASE_IMAGE` (and `GO_BUILD_IMAGE`) **before the first `FROM`**.
* Prefer distro `php-*` metapackages; detect `PHP_VER` at build time. Do not assume `php-opcache` exists as its own package.

## How to work in this repo

### Before coding

1. Read SPECS for the contract you are changing.
2. Prefer small, focused diffs that keep flavors consistent (if you change stack routes, update the matching single-flavor templates when behavior should align).

### Local verification (required for image/runtime changes)

```bash
make test
# or
./scripts/build-images.sh local && ./scripts/test-images.sh local
```

All five flavors (base, php, python, go, stack) must pass smoke tests before merge.

### Commit style

Use [Conventional Commits](https://www.conventionalcommits.org/):

* `feat:` — new user-visible capability (may bump minor)
* `fix:` — bugfix (patch); Renovate uses `fix(deps):`
* `docs:` / `chore:` — non-release or tooling as appropriate
* Breaking changes: footer `BREAKING CHANGE:` (major)

`main` is the release branch. Merges that warrant a release are cut by semantic-release, which also publishes Docker tags.

### Docs sync checklist

Same PR should update, when relevant:

1. Code / Docker / scripts / examples
2. `SPECS.md` (contracts)
3. This file (constraints / workflow)
4. `README.md` (user-facing)
5. Smoke-test assertions if response text or routes change

## Code style expectations

* **PHP:** 8.x, `declare(strict_types=1);`, typed APIs where practical
* **Python:** 3.11+ style type hints, ASGI callables (not WSGI `application` for new examples)
* **Go:** 1.22+ stdlib routing (`ServeMux` method patterns), multi-stage builds, trimmed binaries
* **Shell:** `set -euo pipefail` in scripts; keep `build-images.sh` / `test-images.sh` the single entrypoints for CI
* **Containers:** lean layers; no secrets in images; certs mounted or generated for local only

## Out of scope / escalate to humans

* Rotating or creating `RENOVATE_TOKEN`, `DOCKER_USERNAME` / `DOCKER_PASSWORD`, or GitHub auto-merge settings
* Changing the published image name away from `wsams/httpd-next` without an explicit request
* Adding a second edge server (Caddy/FrankenPHP) without updating SPECS and agreeing on tag layout
* Anything that would break compatibility with the parent `wsams/httpd` project’s role (this repo complements it; it does not replace the need for that repo’s Apache images)
