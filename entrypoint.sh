#!/usr/bin/env bash

set -Eeuo pipefail

readonly APP_ID="${APP_ID:-1026340}"
readonly CONFIG_DIR="${CONFIG_DIR:-/config/barotrauma}"
readonly SERVER_DIR="${SERVER_DIR:-/data/barotrauma}"
readonly SETTINGS_TEMPLATE_FILE="${SETTINGS_TEMPLATE_FILE:-/opt/barotrauma/serversettings.xml.tmpl}"
readonly SETTINGS_TEMPLATE="${SETTINGS_TEMPLATE:-${SETTINGS_ENVTPL:-true}}"
readonly STEAMCMD_VALIDATE="${STEAMCMD_VALIDATE:-false}"
readonly UPDATE_ON_START="${UPDATE_ON_START:-true}"
readonly WORKSHOP_APP_ID="${WORKSHOP_APP_ID:-602960}"
readonly WORKSHOP_INSTALL_DIR="${XDG_DATA_HOME:-/data/state}/Daedalic Entertainment GmbH/Barotrauma/WorkshopMods/Installed"
readonly MANAGED_CONFIG_MARKER="Managed by docker-barotrauma; configure with WORKSHOP_ITEMS."

is_boolean() {
    [[ "${1,,}" =~ ^(1|0|true|false|yes|no|on|off)$ ]]
}

is_true() {
    [[ "${1,,}" =~ ^(1|true|yes|on)$ ]]
}

ensure_writable_directory() {
    local directory="$1"
    local existing_path="${directory}"
    local ownership

    while [[ ! -e "${existing_path}" ]]; do
        existing_path="$(dirname -- "${existing_path}")"
    done

    if [[ ! -d "${existing_path}" || ! -w "${existing_path}" ]]; then
        ownership="$(stat --format='%u:%g %A' "${existing_path}")"
        cat >&2 <<EOF
Cannot create or update ${directory} as UID $(id -u):GID $(id -g).
The nearest existing path, ${existing_path}, is owned by ${ownership}.
Version 1 requires the mounted /data tree to be writable by UID/GID 1000:1000.
Stop the server and change the ownership of the named volume or bind-mounted host directory before restarting.
See the version 1 migration section in the README for exact commands.
EOF
        return 1
    fi

    mkdir --parents "${directory}"
    if [[ ! -w "${directory}" ]]; then
        echo "Directory ${directory} is not writable by UID $(id -u):GID $(id -g)." >&2
        return 1
    fi
}

normalize_workshop_items() {
    local raw_items="${1//,/ }"
    local item

    workshop_items=()
    read -r -a workshop_items <<<"${raw_items}" || true
    for item in "${workshop_items[@]}"; do
        if [[ ! "${item}" =~ ^[0-9]+$ ]]; then
            echo "Invalid Steam Workshop item ID: ${item}" >&2
            return 1
        fi
    done
}

run_steamcmd_update() {
    local description="$1"
    local metadata_app_id="$2"
    shift 2
    local attempt=1

    until steamcmd.sh +login anonymous +app_info_update 1 +app_info_print "${metadata_app_id}" +quit >/dev/null \
        && steamcmd.sh "$@"; do
        if (( attempt >= STEAMCMD_RETRIES )); then
            echo "${description} failed after ${attempt} attempts." >&2
            return 1
        fi

        echo "${description} attempt ${attempt} failed; retrying." >&2
        sleep $((attempt * 5))
        ((attempt += 1))
    done
}

update_server() {
    local -a update_args=(
        +force_install_dir "${SERVER_DIR}"
        +login anonymous
        +app_update "${APP_ID}"
    )

    if is_true "${STEAMCMD_VALIDATE}"; then
        update_args+=(validate)
    fi
    update_args+=(+quit)

    run_steamcmd_update "SteamCMD server update" "${APP_ID}" "${update_args[@]}"
}

install_workshop_items() {
    local -a workshop_args=(
        +force_install_dir "${SERVER_DIR}"
        +login anonymous
    )
    local source_dir
    local item

    normalize_workshop_items "${WORKSHOP_ITEMS:-}"
    if (( ${#workshop_items[@]} == 0 )); then
        return
    fi

    for item in "${workshop_items[@]}"; do
        workshop_args+=(+workshop_download_item "${WORKSHOP_APP_ID}" "${item}")
        if is_true "${STEAMCMD_VALIDATE}"; then
            workshop_args+=(validate)
        fi
    done
    workshop_args+=(+quit)

    run_steamcmd_update "SteamCMD Workshop update" "${WORKSHOP_APP_ID}" "${workshop_args[@]}"

    mkdir --parents "${WORKSHOP_INSTALL_DIR}"
    for item in "${workshop_items[@]}"; do
        source_dir="${SERVER_DIR}/steamapps/workshop/content/${WORKSHOP_APP_ID}/${item}"
        if [[ ! -f "${source_dir}/filelist.xml" ]]; then
            echo "Workshop item ${item} does not contain a Barotrauma filelist.xml." >&2
            return 1
        fi
        ln --symbolic --force --no-dereference "${source_dir}" "${WORKSHOP_INSTALL_DIR}/${item}"
    done
}

write_managed_player_config() {
    local config_file="${SERVER_DIR}/config_player.xml"
    local temporary_file
    local item
    local -a xml_edit

    if [[ -f "${CONFIG_DIR}/config_player.xml" ]]; then
        install --mode=0644 "${CONFIG_DIR}/config_player.xml" "${config_file}"
        return
    fi

    if [[ ! -v WORKSHOP_ITEMS ]]; then
        return
    fi

    temporary_file="$(mktemp "${config_file}.XXXXXX")"
    if [[ -f "${config_file}" ]]; then
        cp "${config_file}" "${temporary_file}"
    else
        printf '<?xml version="1.0" encoding="utf-8"?>\n<!-- %s -->\n<config />\n' \
            "${MANAGED_CONFIG_MARKER}" >"${temporary_file}"
    fi

    xml_edit=(
        --inplace
        --delete /config/contentpackages
        --subnode /config --type elem --name contentpackages --value ''
        --subnode /config/contentpackages --type elem --name corepackage --value ''
        --insert /config/contentpackages/corepackage --type attr --name path --value Content/ContentPackages/Vanilla.xml
        --subnode /config/contentpackages --type elem --name regularpackages --value ''
    )
    for item in "${workshop_items[@]}"; do
        xml_edit+=(
            --subnode /config/contentpackages/regularpackages --type elem --name package --value ''
            --insert '/config/contentpackages/regularpackages/package[last()]' --type attr --name path
            --value "${WORKSHOP_INSTALL_DIR}/${item}/filelist.xml"
        )
    done
    xmlstarlet edit "${xml_edit[@]}" "${temporary_file}"
    mv "${temporary_file}" "${config_file}"
}

configure_server() {
    local settings_tmp

    if is_true "${SETTINGS_TEMPLATE}"; then
        settings_tmp="$(mktemp "${SERVER_DIR}/serversettings.xml.XXXXXX")"
        envsubst <"${SETTINGS_TEMPLATE_FILE}" >"${settings_tmp}"
        mv "${settings_tmp}" "${SERVER_DIR}/serversettings.xml"
    elif [[ -f "${CONFIG_DIR}/serversettings.xml" ]]; then
        install --mode=0644 "${CONFIG_DIR}/serversettings.xml" "${SERVER_DIR}/serversettings.xml"
    elif [[ ! -f "${SERVER_DIR}/serversettings.xml" ]]; then
        echo "No server settings found. Provide ${CONFIG_DIR}/serversettings.xml or enable SETTINGS_TEMPLATE." >&2
        return 1
    fi

    if [[ -f "${CONFIG_DIR}/clientpermissions.xml" ]]; then
        install --mode=0644 \
            "${CONFIG_DIR}/clientpermissions.xml" \
            "${SERVER_DIR}/Data/clientpermissions.xml"
    fi
}

for value in "${SETTINGS_TEMPLATE}" "${STEAMCMD_VALIDATE}" "${UPDATE_ON_START}"; do
    if ! is_boolean "${value}"; then
        echo "Boolean settings accept only true/false, yes/no, on/off, or 1/0; received: ${value}" >&2
        exit 1
    fi
done

if [[ ! "${STEAMCMD_RETRIES:-3}" =~ ^[1-9][0-9]*$ ]]; then
    echo "STEAMCMD_RETRIES must be a positive integer." >&2
    exit 1
fi

ensure_writable_directory "${SERVER_DIR}/Data"
ensure_writable_directory "${HOME}/.steam/sdk64"
ensure_writable_directory "${XDG_DATA_HOME:-/data/state}"

if is_true "${UPDATE_ON_START}"; then
    update_server
fi

ln --symbolic --force --no-dereference \
    /opt/steamcmd/linux64/steamclient.so \
    "${HOME}/.steam/sdk64/steamclient.so"

configure_server
install_workshop_items
write_managed_player_config

cd "${SERVER_DIR}"
if [[ "${1:-}" == "./DedicatedServer" || "${1:-}" == "${SERVER_DIR}/DedicatedServer" ]]; then
    exec /usr/local/bin/barotrauma-console "$@"
else
    exec "$@"
fi
