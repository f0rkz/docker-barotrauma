# Server settings management

Barotrauma is the schema authority for `/data/barotrauma/serversettings.xml`.
The container does not maintain a complete copy of that schema. It owns only the
environment-to-attribute mapping in `serversettings.envmap`.

## Startup lifecycle

With `MANAGE_SERVER_SETTINGS=true`, the entrypoint:

1. Uses the persisted `serversettings.xml`, or creates a minimal
   `<serversettings/>` document on a new volume.
2. Reads `serversettings.envmap` and considers only environment variables that
   are actually present, including variables explicitly set to an empty value.
3. Removes the canonical attribute and listed legacy aliases for each managed
   variable, then writes the canonical attribute atomically with `xmlstarlet`.
4. Preserves every unmapped attribute and child element.
5. Starts Barotrauma, which loads the managed values and saves the complete
   schema supported by the installed server version.

This order means a SteamCMD update can introduce settings without waiting for an
image change. Barotrauma supplies their defaults and persists them; the image
continues to manage only attributes listed in the mapping.

## Deployment configuration runbook

An agent configuring a deployment should follow these steps:

1. Decide whether environment variables or an operator XML file owns settings.
   Do not configure both mechanisms.
2. For environment ownership, set `MANAGE_SERVER_SETTINGS=true` and include only
   the mapped `BAROTRAUMA_*` variables that the deployment should enforce.
   Copying all of `.env.example` intentionally manages every listed attribute.
3. For an operator XML file, set `MANAGE_SERVER_SETTINGS=false` and mount the
   file read-only at `/config/barotrauma/serversettings.xml`.
4. Recreate the container after changing environment values. A Compose restart
   does not reload `env_file` contents.
5. Inspect the persisted XML and container logs after startup.

For a campaign server managed through `.env`, the minimum mode configuration is:

```dotenv
MANAGE_SERVER_SETTINGS=true
BAROTRAUMA_GAME_MODE_IDENTIFIER=campaign
BAROTRAUMA_MODE_SELECTION_MODE=Manual
```

Apply and verify it with the supplied Compose service:

```bash
docker compose up -d --force-recreate barotrauma
docker compose exec barotrauma xmlstarlet select --text --template \
  --value-of /serversettings/@GameModeIdentifier \
  /data/barotrauma/serversettings.xml
docker compose logs --tail 100 barotrauma
```

The XML query must print `campaign`. Campaign creation, save selection, and the
`CampaignSettings` child element remain owned by Barotrauma; do not add that
child element to `serversettings.envmap`.

For Compose deployments whose service is not named `barotrauma`, substitute the
actual key under `services:`. For another orchestrator, use the same environment
variables and persistent paths, and trigger a rollout that replaces the running
container rather than merely restarting its process.

## Precedence

| Mode | Persisted file | Operator file | Environment variables |
| --- | --- | --- | --- |
| `MANAGE_SERVER_SETTINGS=true` | Used as the merge base | Ignored | Present mapped variables override attributes |
| `MANAGE_SERVER_SETTINGS=false` with operator file | Replaced at startup | Copied verbatim | Ignored |
| `MANAGE_SERVER_SETTINGS=false` without operator file | Used as-is; Barotrauma creates it if absent | Not present | Ignored |

The compatibility variables `SETTINGS_TEMPLATE` and `SETTINGS_ENVTPL` are used
only when `MANAGE_SERVER_SETTINGS` is unset. They now select managed merge mode;
they no longer select whole-file rendering.

## Adding a setting

Add one whitespace-delimited row to `serversettings.envmap`:

```text
BAROTRAUMA_EXAMPLE_SETTING ExampleSetting OldExampleName,OlderExampleName
```

Use `-` when there are no legacy aliases. Attribute matching and alias removal
are case-insensitive. Use the canonical name written by the current Barotrauma
server source, not a historical lowercase template name.

Then add a documented default to `.env.example`. A variable absent from the
container environment is deliberately unmanaged; an explicitly empty variable
is managed and written as an empty XML attribute.

Run:

```bash
make test
make build
IMAGE_NAME=docker-barotrauma:latest bash tests/settings.sh
```

The fast settings test verifies first-run bootstrapping, canonical alias
replacement, empty-safe XML editing, and preservation of unknown upstream data.
The real integration test additionally starts the current dedicated server and
checks that every canonical mapped attribute survives Barotrauma's native save.
This scheduled check detects mappings that become obsolete after a game update.

## Migration from template rendering

Existing persisted files remain valid. On the first start with managed merge
mode, mapped legacy attributes are replaced with canonical names. Unmapped data
is retained, and Barotrauma rewrites the document using its current schema.

The version 1 template exposed several attributes removed by newer Barotrauma
servers. `BAROTRAUMA_RESPAWN_MODE` replaces `BAROTRAUMA_ALLOW_RESPAWN`, while
`BAROTRAUMA_TRAITOR_PROBABILITY` and `BAROTRAUMA_TRAITOR_DANGER_LEVEL` replace
the old traitor toggle and delay attributes. Removed attributes without a
current upstream equivalent are left unmanaged and are discarded when
Barotrauma normalizes the document.

Back up `/data/barotrauma/serversettings.xml` before changing management modes.
If an operator-managed file should be authoritative, set
`MANAGE_SERVER_SETTINGS=false` and mount it read-only at
`/config/barotrauma/serversettings.xml`.
