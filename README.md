# [nostr-rs-relay](https://git.sr.ht/~gheartsfield/nostr-rs-relay)

This is a [nostr](https://github.com/nostr-protocol/nostr) relay,
written in Rust.  It currently supports the entire relay protocol, and
persists data with SQLite.  There is experimental support for
Postgresql.

The project master repository is available on
[sourcehut](https://sr.ht/~gheartsfield/nostr-rs-relay/), and is
mirrored on [GitHub](https://github.com/scsibug/nostr-rs-relay).

[![builds.sr.ht status](https://builds.sr.ht/~gheartsfield/nostr-rs-relay/commits/master.svg)](https://builds.sr.ht/~gheartsfield/nostr-rs-relay/commits/master?)

![Github CI](https://github.com/scsibug/nostr-rs-relay/actions/workflows/ci.yml/badge.svg)


## Features

[NIPs](https://github.com/nostr-protocol/nips) with a relay-specific implementation are listed here.

- [x] NIP-01: [Basic protocol flow description](https://github.com/nostr-protocol/nips/blob/master/01.md)
  * Core event model
  * Hide old metadata events
  * Id/Author prefix search
- [x] NIP-02: [Contact List and Petnames](https://github.com/nostr-protocol/nips/blob/master/02.md)
- [ ] NIP-03: [OpenTimestamps Attestations for Events](https://github.com/nostr-protocol/nips/blob/master/03.md)
- [x] NIP-05: [Mapping Nostr keys to DNS-based internet identifiers](https://github.com/nostr-protocol/nips/blob/master/05.md)
- [x] NIP-09: [Event Deletion](https://github.com/nostr-protocol/nips/blob/master/09.md)
- [x] NIP-11: [Relay Information Document](https://github.com/nostr-protocol/nips/blob/master/11.md)
- [x] NIP-12: [Generic Tag Queries](https://github.com/nostr-protocol/nips/blob/master/12.md)
- [x] NIP-15: [End of Stored Events Notice](https://github.com/nostr-protocol/nips/blob/master/15.md)
- [x] NIP-16: [Event Treatment](https://github.com/nostr-protocol/nips/blob/master/16.md)
- [x] NIP-20: [Command Results](https://github.com/nostr-protocol/nips/blob/master/20.md)
- [x] NIP-22: [Event `created_at` limits](https://github.com/nostr-protocol/nips/blob/master/22.md) (_future-dated events only_)
- [ ] NIP-26: [Event Delegation](https://github.com/nostr-protocol/nips/blob/master/26.md) (_implemented, but currently disabled_)
- [x] NIP-28: [Public Chat](https://github.com/nostr-protocol/nips/blob/master/28.md)
- [x] NIP-33: [Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md)
- [x] NIP-40: [Expiration Timestamp](https://github.com/nostr-protocol/nips/blob/master/40.md)
- [x] NIP-42: [Authentication of clients to relays](https://github.com/nostr-protocol/nips/blob/master/42.md)
- [x] NIP-70: [Protected Tags](https://github.com/nostr-protocol/nips/blob/master/70.md)

## Deployment Options

### 1. Docker Compose with Caddy (Recommended for Production)

The easiest way to deploy nostr-rs-relay in production is using Docker Compose with Caddy as a reverse proxy. This setup:

- Automatically handles SSL certificates with Let's Encrypt
- Configures proper WebSocket proxying
- Ensures the application restarts automatically
- Provides a secure configuration out of the box

For detailed instructions, see [DOCKER_COMPOSE.md](DOCKER_COMPOSE.md) or use the automated deployment script:

```bash
sudo ./deploy.sh
```

### 2. Docker/Podman (Quick Start)

The provided `Dockerfile` will compile and build the server
application. Use a bind mount to store the SQLite database outside of
the container image, and map the container's 8080 port to a host port
(7000 in the example below).

The examples below start a rootless podman container, mapping a local
data directory and config file.

```console
$ podman build --pull -t nostr-rs-relay .

$ mkdir data

$ podman unshare chown 100:100 data

$ podman run -it --rm -p 7000:8080 \
  --user=100:100 \
  -v $(pwd)/data:/usr/src/app/db:Z \
  -v $(pwd)/config.toml:/usr/src/app/config.toml:ro,Z \
  --name nostr-relay nostr-rs-relay:latest

Nov 19 15:31:15.013  INFO nostr_rs_relay: Starting up from main
Nov 19 15:31:15.017  INFO nostr_rs_relay::server: listening on: 0.0.0.0:8080
Nov 19 15:31:15.019  INFO nostr_rs_relay::server: db writer created
Nov 19 15:31:15.019  INFO nostr_rs_relay::server: control message listener started
Nov 19 15:31:15.019  INFO nostr_rs_relay::db: Built a connection pool "event writer" (min=1, max=4)
Nov 19 15:31:15.019  INFO nostr_rs_relay::db: opened database "/usr/src/app/db/nostr.db" for writing
Nov 19 15:31:15.019  INFO nostr_rs_relay::schema: DB version = 0
Nov 19 15:31:15.054  INFO nostr_rs_relay::schema: database pragma/schema initialized to v7, and ready
Nov 19 15:31:15.054  INFO nostr_rs_relay::schema: All migration scripts completed successfully.  Welcome to v7.
Nov 19 15:31:15.521  INFO nostr_rs_relay::db: Built a connection pool "client query" (min=4, max=128)
```

Use a `nostr` client such as
[`noscl`](https://github.com/fiatjaf/noscl) to publish and query
events.

```console
$ noscl publish "hello world"
Sent to 'ws://localhost:8090'.
Seen it on 'ws://localhost:8090'.
$ noscl home
Text Note [81cf...2652] from 296a...9b92 5 seconds ago
  hello world
```

A pre-built container is also available on DockerHub:
https://hub.docker.com/r/scsibug/nostr-rs-relay

### 3. Build and Run (without Docker)

Building `nostr-rs-relay` requires an installation of Cargo & Rust: https://www.rust-lang.org/tools/install

The following OS packages will be helpful; on Debian/Ubuntu:
```console
$ sudo apt-get install build-essential cmake protobuf-compiler pkg-config libssl-dev
```

On OpenBSD:
```console
$ doas pkg_add rust protobuf
```

Clone this repository, and then build a release version of the relay:

```console
$ git clone -q https://git.sr.ht/\~gheartsfield/nostr-rs-relay
$ cd nostr-rs-relay
$ cargo build -q -r
```

The relay executable is now located in
`target/release/nostr-rs-relay`.  In order to run it with logging
enabled, execute it with the `RUST_LOG` variable set:

```console
$ RUST_LOG=warn,nostr_rs_relay=info ./target/release/nostr-rs-relay
Dec 26 10:31:56.455  INFO nostr_rs_relay: Starting up from main
Dec 26 10:31:56.464  INFO nostr_rs_relay::server: listening on: 0.0.0.0:8080
Dec 26 10:31:56.466  INFO nostr_rs_relay::server: db writer created
Dec 26 10:31:56.466  INFO nostr_rs_relay::db: Built a connection pool "event writer" (min=1, max=2)
Dec 26 10:31:56.466  INFO nostr_rs_relay::db: opened database "./nostr.db" for writing
Dec 26 10:31:56.466  INFO nostr_rs_relay::schema: DB version = 11
Dec 26 10:31:56.467  INFO nostr_rs_relay::db: Built a connection pool "maintenance writer" (min=1, max=2)
Dec 26 10:31:56.467  INFO nostr_rs_relay::server: control message listener started
Dec 26 10:31:56.468  INFO nostr_rs_relay::db: Built a connection pool "client query" (min=4, max=8)
```

You now have a running relay, on port `8080`.  Use a `nostr` client or
`websocat` to connect and send/query for events.

## Configuration

The sample [`config.toml`](config.toml) file demonstrates the
configuration available to the relay.  This file is optional, but may
be mounted into a docker container like so:

```console
$ docker run -it -p 7000:8080 \
  --mount src=$(pwd)/config.toml,target=/usr/src/app/config.toml,type=bind \
  --mount src=$(pwd)/data,target=/usr/src/app/db,type=bind \
  --mount src=$(pwd)/index.html,target=/usr/src/app/index.html,type=bind \
  nostr-rs-relay
```

Options include rate-limiting, event size limits, and network address
settings.

## Reverse Proxy Configuration

For examples of putting the relay behind a reverse proxy (for TLS
termination, load balancing, and other features), see:

- [Reverse Proxy Examples](docs/reverse-proxy.md) (HAProxy, Nginx, Traefik)
- [Caddy Configuration](Caddyfile.example) (Recommended)

## Dev Channel

For development discussions, please feel free to use the [sourcehut
mailing list](https://lists.sr.ht/~gheartsfield/nostr-rs-relay-devel).

License
---
This project is MIT licensed.

External Documentation and Links
---

* [BlockChainCaffe's Nostr Relay Setup Guide](https://github.com/BlockChainCaffe/Nostr-Relay-Setup-Guide)