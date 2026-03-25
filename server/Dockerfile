# syntax=docker/dockerfile:1

FROM rust:1.91 as builder
WORKDIR /app

COPY Cargo.toml Cargo.lock ./
COPY src ./src
RUN cargo build --release

FROM debian:bookworm-slim
WORKDIR /app
COPY --from=builder /app/target/release/server /usr/local/bin/server

EXPOSE 3000
CMD ["server"]