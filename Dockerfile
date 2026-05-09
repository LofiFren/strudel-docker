# syntax=docker/dockerfile:1.7
#
# Self-hosted Strudel REPL.
#
# Builds the upstream Strudel website at https://codeberg.org/uzu/strudel
# in production mode, then serves it with `astro preview` on port 4321.
# Production mode is required so the vite-pwa service worker is active
# and Strudel works offline once the page has been visited.

FROM node:22-alpine

ENV PNPM_HOME=/pnpm \
    PATH=/pnpm:$PATH \
    ASTRO_TELEMETRY_DISABLED=1

# git: needed to clone the repo
# wget: used by the HEALTHCHECK
# pnpm 9 is pinned deliberately. pnpm 10+ refuses to run postinstall
# scripts for "unapproved" dependencies (esbuild, sharp, etc.) and
# pnpm 11 makes that a hard error (ERR_PNPM_IGNORED_BUILDS) by
# defaulting strictDepBuilds=true. There's no non-interactive
# "approve everything" flag yet (pnpm/pnpm#9102), and the upstream
# Strudel repo doesn't ship an allowBuilds list. pnpm 9 just runs
# them, which is what we want for a fresh clean build. We skip
# corepack so the pinned global pnpm wins regardless of any
# `packageManager` field in the cloned repo.
# python3/make/g++ are needed by node-gyp for native deps that ship in
# devDependencies (tree-sitter-haskell, @serialport/bindings-cpp, etc.).
RUN apk add --no-cache git wget python3 make g++ \
    && npm install -g pnpm@9

WORKDIR /app

# Pin to a tag, branch, or commit at build time:
#   docker build --build-arg STRUDEL_REF=@strudel/core@1.2.4 .
ARG STRUDEL_REF=main
RUN git clone --depth 1 --branch "${STRUDEL_REF}" \
        https://codeberg.org/uzu/strudel.git . \
    && rm -rf .git

# pnpm store is mounted as a BuildKit cache so repeated builds are fast.
# devDependencies (jsdoc, astro, vite) are needed for the build itself,
# so NODE_ENV=production is set only afterwards for the runtime stage.
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile \
    && pnpm build

ENV NODE_ENV=production

# Drop privileges. Alpine's adduser doesn't take long flags everywhere,
# so we use the short forms.
RUN addgroup -S strudel \
    && adduser -S -G strudel strudel \
    && chown -R strudel:strudel /app
USER strudel

WORKDIR /app/website
EXPOSE 4321

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD wget -qO- http://127.0.0.1:4321/ >/dev/null 2>&1 || exit 1

# Invoke astro directly. Going through the website's `preview` npm script
# results in `astro preview --host 0.0.0.0 --host 0.0.0.0 --port 4321`,
# which Astro 5's CLI parses such that the server still binds to ::1
# (the "use --host to expose" warning fires). Calling astro once with a
# single `--host 0.0.0.0` makes it listen on all interfaces.
CMD ["pnpm", "exec", "astro", "preview", "--host", "0.0.0.0", "--port", "4321"]
