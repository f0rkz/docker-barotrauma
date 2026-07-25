# Docker Barotrauma

A non-root Barotrauma dedicated server image built on
[`ghcr.io/f0rkz/docker-steamcmd:2`](https://github.com/f0rkz/docker-steamcmd).
It installs or updates the server at startup and persists the game, configuration,
saves, logs, Steam Workshop library, and local application state under `/data`.

## Quick start

```bash
cp .env.example .env
mkdir -p config
cp clientpermissions.xml.example config/clientpermissions.xml
docker compose up -d
docker compose logs -f barotrauma
```

Review `.env` before exposing the server. Compose publishes UDP ports `27015`
and `27016` and stores state in the `barotrauma-data` named volume.

## Runtime contract

| Setting | Value |
| --- | --- |
| User | `steam` (`1000:1000`) |
| Dedicated server | `/data/barotrauma` |
| Local application state | `/data/state` |
| Read-only operator configuration | `/config/barotrauma` |
| Default command | `./DedicatedServer` |

For a bind mount, make the host directory writable by UID/GID 1000.

## Server configuration

`MANAGE_SERVER_SETTINGS=true` updates only the XML attributes whose environment
variables are present. The variables are listed in [.env.example](.env.example),
and their canonical XML attributes are defined in
[serversettings.envmap](serversettings.envmap). Unmapped attributes and child
elements remain untouched.

On a new volume, the image creates a minimal `<serversettings/>` document.
Barotrauma loads those managed values and writes its complete current settings
schema during startup. On later starts, the image merges environment values into
that persisted document instead of replacing it. This allows new upstream
settings and in-game changes to survive image updates.

Set `MANAGE_SERVER_SETTINGS=false` to let Barotrauma manage the persisted file
without environment overrides. When
`/config/barotrauma/serversettings.xml` is mounted, it is copied verbatim before
startup in this mode. The old `SETTINGS_TEMPLATE` and `SETTINGS_ENVTPL` variables
remain accepted as migration aliases.

See [docs/SERVER_SETTINGS.md](docs/SERVER_SETTINGS.md) for precedence, migration,
testing, and instructions for adding future settings.

Optional read-only files:

- `/config/barotrauma/clientpermissions.xml` is installed into the server `Data`
  directory.
- `/config/barotrauma/config_player.xml` supplies an operator-managed content
  package load order and takes precedence over automatic Workshop enablement.

## SteamCMD updates

| Variable | Default | Purpose |
| --- | --- | --- |
| `UPDATE_ON_START` | `true` | Install or update App 1026340 at startup. |
| `STEAMCMD_VALIDATE` | `false` | Validate every server or Workshop file. |
| `STEAMCMD_RETRIES` | `3` | Metadata-refresh and update attempts. |

Validation is useful for repairs but makes routine starts slower.

## Workshop mods

The upstream dedicated server does not download Workshop updates itself. Set
`WORKSHOP_ITEMS` to numeric Barotrauma Workshop IDs and this image will download
them through SteamCMD, install them into Barotrauma's Workshop directory, and
enable them in the same order:

```dotenv
WORKSHOP_ITEMS=2701251094,2532991202
```

Comma- and space-separated IDs are accepted. The persistent paths are:

- Steam library: `/data/barotrauma/steamapps/workshop/content/602960`
- Installed packages: `/data/state/Daedalic Entertainment GmbH/Barotrauma/WorkshopMods/Installed`
- Enabled load order: `/data/barotrauma/config_player.xml`

When `WORKSHOP_ITEMS` is present, only the `contentpackages` section of the
persisted `config_player.xml` is replaced; unrelated settings are preserved.
When `/config/barotrauma/config_player.xml` is mounted, it is copied verbatim and
must list the desired package paths itself.

Workshop dependencies are not inferred. List required items before the mods that
depend on them, verify that each mod supports the current server version, and
back up campaigns before changing a load order. Local mods can still be placed in
`/data/barotrauma/LocalMods` and enabled through an operator-managed
`config_player.xml`.

## Graceful shutdown

Barotrauma ignores redirected console input, so simple signal forwarding cannot
run its normal server shutdown path. The image supplies a small terminal
supervisor that answers the server's console cursor requests and sends the
official `quit` command when Docker delivers SIGTERM. Compose allows 60 seconds
for ban lists, settings, logs, networking, and active game state to close.

Use `docker compose stop barotrauma` for routine shutdowns; avoid `docker kill`.

## Operations

```bash
docker compose logs -f barotrauma
docker compose stop barotrauma
docker compose start barotrauma
docker compose down
```

## Migrating from version 0

Version 1 is intentionally breaking:

- The process now runs as UID/GID 1000 instead of root.
- The SteamCMD v2 image replaces the old floating base.
- Persistent local application state is redirected to `/data/state`.
- Configuration mounts use `/config/barotrauma`.
- Environment-managed settings use a persisted XML merge instead of `envtmpl`.

Existing bind mounts may need ownership changes. Preserve the old `/data`
contents, mount them at `/data`, and take a backup before the first version 1
start.

## Local development

```bash
make test
make build
make integration
```

The integration test downloads the current dedicated server and a small Workshop
fixture, starts the server, and verifies its persisted shutdown log and exit code.
It runs manually and on the scheduled CI job rather than on every pull request.

## Security and license

See [SECURITY.md](SECURITY.md) for private vulnerability reporting. This project
is distributed under the [MIT license](LICENSE).
