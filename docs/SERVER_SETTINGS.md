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
