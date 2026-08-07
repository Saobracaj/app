# syntax=docker/dockerfile:1
#
# The web version of Saobraćaj: the Rust static server (web_server/) with the
# Flutter web bundle baked in.
#
# The bundle is NOT built here — Flutter in Docker would add ~2 GB and a very
# slow layer to every deploy. CI runs `flutter build web --wasm` first and this
# image copies the result, so the build context must contain `build/web`:
#
#   flutter build web --wasm --release --target lib/main_prod.dart
#   docker build -t saobracaj_web .
#
# See .github/workflows/build-and-deploy.yml (jobs build-web / deploy-web) and
# web_server/README.md for how the server behaves.

FROM rust:1-bookworm AS builder

WORKDIR /src
# Dependencies first, so editing the server's source does not refetch the world.
COPY web_server/Cargo.toml web_server/Cargo.lock ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs && cargo build --release --locked && rm -rf src

COPY web_server/src ./src
COPY web_server/well_known ./well_known
# The stub above leaves a binary cargo would happily reuse; touch the real entry
# point so the actual sources are compiled.
RUN touch src/main.rs && cargo build --release --locked

# ---- Runtime image -------------------------------------------------------
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/target/release/saobracaj_web /usr/local/bin/saobracaj_web
COPY build/web /srv/web

ENV WEB_ROOT=/srv/web \
    HOST=0.0.0.0 \
    PORT=8080 \
    PUBLIC_ORIGIN=https://saobracaj.gleb.at

EXPOSE 8080
CMD ["saobracaj_web"]
