# syntax=docker/dockerfile:1

# ── Build stage ──────────────────────────────────────────────────────
FROM dart:stable AS build

WORKDIR /app

# Copy backend dependencies
COPY backend_dart/pubspec.* ./
RUN dart pub get

# Copy backend source
COPY backend_dart/ .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# ── Runtime stage ────────────────────────────────────────────────────
FROM debian:bookworm-slim

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled binary
COPY --from=build /app/bin/server /app/bin/server

# Create data directories
RUN mkdir -p /app/data/uploads

EXPOSE 8000

ENV PORT=8000

CMD ["/app/bin/server"]
