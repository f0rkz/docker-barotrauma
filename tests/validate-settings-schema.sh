#!/usr/bin/env bash

set -Eeuo pipefail

readonly SETTINGS_FILE="${1:?Usage: validate-settings-schema.sh SETTINGS_FILE MAP_FILE}"
readonly MAP_FILE="${2:?Usage: validate-settings-schema.sh SETTINGS_FILE MAP_FILE}"
readonly UPPERCASE="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
readonly LOWERCASE="abcdefghijklmnopqrstuvwxyz"

while read -r variable attribute _; do
    if [[ -z "${variable}" || "${variable}" == \#* ]]; then
        continue
    fi

    count="$(xmlstarlet select --template --value-of \
        "count(/serversettings/@*[translate(local-name(), '${UPPERCASE}', '${LOWERCASE}') = '${attribute,,}'])" \
        "${SETTINGS_FILE}")"
    if [[ "${count}" != 1 ]]; then
        echo "Barotrauma did not persist mapped attribute ${attribute} for ${variable}." >&2
        exit 1
    fi
done <"${MAP_FILE}"

echo "Barotrauma native settings schema matches the managed attribute map"
