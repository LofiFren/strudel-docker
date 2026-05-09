# strudel-docker

Self-hosted [Strudel](https://strudel.cc) REPL in a single small container.
Builds the upstream Codeberg repo, serves the production bundle, and lets
the PWA service worker register so Strudel works offline once you've visited
the page.

## Quick start

```sh
docker compose up -d
# then open http://localhost:4321
```

That's it. Stop it with `docker compose down`. The first run takes a few
minutes to build (clones Strudel, runs `pnpm install`, runs `pnpm build`);
subsequent runs are instant. Re-pull upstream Strudel with
`docker compose up -d --build`.

**Requirements:** Docker Desktop 4.x+ (Mac/Windows) or Docker Engine 23+
(Linux). Both ship Compose v2 and BuildKit by default; the Dockerfile
uses BuildKit's cache mounts so older Docker versions (pre-2023) won't
build.

## Plain `docker` (no compose)

```sh
docker build -t strudel:local .
docker run -d --name strudel -p 127.0.0.1:4321:4321 strudel:local
```

## Pinning a Strudel version

The build clones from Codeberg at image-build time. Pin a tag, branch, or
commit with the `STRUDEL_REF` build arg:

```sh
# A specific release tag
docker compose build --build-arg STRUDEL_REF=@strudel/core@1.2.4

# Or via .env
echo "STRUDEL_REF=@strudel/core@1.2.4" > .env
docker compose up -d --build
```

Tags live at <https://codeberg.org/uzu/strudel/tags>.

## Going offline

Once the container is running and you've loaded the page in a browser,
the PWA service worker caches the app. After that:

- **Install as an app** (recommended): in Chrome/Edge/Brave, click the
  install icon in the address bar. Strudel becomes a standalone window
  that works without the container running, as long as your browser keeps
  the cache.
- **Pre-cache samples**: samples are only cached after they're played.
  Trigger any sound packs / synths you want available offline before
  disconnecting. Verify in DevTools → Application → Cache Storage.
- **Bring your own samples**: use Strudel's *Sounds → import sounds*
  (folder import) for samples that aren't dependent on any CDN.

## Exposing on the LAN

By default the port is bound to `127.0.0.1` only. To share with other
devices on your network:

```sh
BIND_ADDR=0.0.0.0 docker compose up -d
```

Or set it in `.env`. Be aware: anyone on your network can then load and
control your Strudel instance.

## Windows

Works as-is with **Docker Desktop for Windows** (WSL2 backend
recommended). The container is Linux regardless of host OS, so the image
is identical to what runs on macOS/Linux. The compose file uses no bind
mounts or host paths, so there are no path-translation gotchas.

The only difference is shell syntax for one-shot env vars. The bash form
in this README (`BIND_ADDR=0.0.0.0 docker compose up -d`) doesn't work
in PowerShell or cmd. Equivalents:

```powershell
# PowerShell
$env:BIND_ADDR="0.0.0.0"; docker compose up -d
$env:STRUDEL_REF="@strudel/core@1.2.4"; docker compose up -d --build
```

```bat
:: cmd.exe
set BIND_ADDR=0.0.0.0 && docker compose up -d
set STRUDEL_REF=@strudel/core@1.2.4 && docker compose up -d --build
```

Or simplest and identical on every OS: put the values in a `.env` file
next to `docker-compose.yml`.

```
STRUDEL_REF=@strudel/core@1.2.4
BIND_ADDR=0.0.0.0
```

## How this differs from `nouai/strudel-docker-container`

This project is a clean reimplementation. The differences:

| | nouai | this |
|---|---|---|
| Number of files | 1 script that writes 6 files into `$HOME` | 4 files, all in the project dir |
| Strudel mode | `pnpm dev` | `pnpm build` + `pnpm preview` |
| **PWA / offline support** | **broken** (service worker disabled in dev mode, see Strudel PR #421) | **works** |
| Firewall changes | runs `sudo iptables` against the host | none — Docker handles ports |
| Container user | root | non-root (`strudel`) |
| Filesystem | writable | read-only + tmpfs |
| Clone URL | typo (`codeberg.ocpmorg`) — broken on fresh install | correct |
| Container/image name | `sturdel` (typo) | `strudel` |
| Update workflow | `git pull` in a host directory | rebuild image with `STRUDEL_REF` |

## Image size

Around 3 GB. It's a Node-based runtime because Astro's `preview` server
is the simplest way to get the static build's correct headers and
service-worker scope. The bulk is the full `node_modules` tree plus the
build toolchain (python3/make/g++) needed by native devDependencies like
`tree-sitter-haskell`. If you'd rather have a ~50 MB image, swap the
runtime for `nginx:alpine` and copy `/app/website/dist` into
`/usr/share/nginx/html` — paths inside Strudel's build are root-relative
so default nginx config works. A multi-stage Dockerfile that builds in
this image and copies `dist/` into `nginx:alpine` is the most common
small-image variant.

## Credits

This project is a Docker wrapper around two upstream projects it bundles
or descends from:

- **[Strudel](https://strudel.cc)** — the live-coding music environment
  this image actually runs. Created by [Felix Roos](https://github.com/felixroos)
  and the Strudel contributors. Source:
  <https://codeberg.org/uzu/strudel>. Licensed AGPL-3.0.
- **[Tidal Cycles](https://tidalcycles.org)** — the pattern language
  Strudel ports from Haskell to JavaScript. Originally created by
  [Alex McLean](https://github.com/yaxu) and the Tidal contributors.
  Source: <https://github.com/tidalcycles/Tidal>. Licensed GPL-3.0.

This Docker wrapper is independent and is not affiliated with or
endorsed by the Strudel or Tidal Cycles projects. All the credit for the
software you'll actually be using belongs to those upstream authors.

If you make music with this, donate to / support those projects, not me.

## License

The wrapper itself (`Dockerfile`, `docker-compose.yml`, `.dockerignore`,
`README.md`) is released under **AGPL-3.0** — see [`LICENSE`](LICENSE) —
to match the Strudel build it produces. AGPL-3.0 also flows through
because Strudel is bundled into the resulting image.

Strudel's own license: <https://codeberg.org/uzu/strudel/src/branch/main/LICENSE>.
Tidal Cycles' license (referenced for credit, not bundled):
<https://github.com/tidalcycles/Tidal/blob/main/LICENSE>.
