#!/usr/bin/env bash

set -Eeuo pipefail

readonly IMAGE_NAME="${IMAGE_NAME:-docker-barotrauma:test}"
readonly PRESERVE_VOLUME="docker-barotrauma-settings-preserve-${$}"
readonly BOOTSTRAP_VOLUME="docker-barotrauma-settings-bootstrap-${$}"

# shellcheck disable=SC2329
cleanup() {
    docker volume rm --force "${PRESERVE_VOLUME}" "${BOOTSTRAP_VOLUME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker volume create "${PRESERVE_VOLUME}" >/dev/null
docker volume create "${BOOTSTRAP_VOLUME}" >/dev/null

docker run --rm \
    --user root \
    --entrypoint install \
    --volume "${PRESERVE_VOLUME}:/data" \
    --volume "${PWD}/tests/fixtures/serversettings.xml:/fixture.xml:ro" \
    "${IMAGE_NAME}" \
    --directory --owner=steam --group=steam /data/barotrauma

docker run --rm \
    --user root \
    --entrypoint install \
    --volume "${PRESERVE_VOLUME}:/data" \
    --volume "${PWD}/tests/fixtures/serversettings.xml:/fixture.xml:ro" \
    "${IMAGE_NAME}" \
    --owner=steam --group=steam --mode=0644 /fixture.xml /data/barotrauma/serversettings.xml

docker run --rm \
    --volume "${PRESERVE_VOLUME}:/data" \
    --env UPDATE_ON_START=false \
    --env MANAGE_SERVER_SETTINGS=true \
    --env "BAROTRAUMA_NAME=Managed & escaped" \
    --env BAROTRAUMA_GAME_MODE_IDENTIFIER=campaign \
    "${IMAGE_NAME}" \
    sh -euc '
        settings=/data/barotrauma/serversettings.xml
        test "$(xmlstarlet select --text --template --value-of /serversettings/@ServerName "${settings}")" = "Managed & escaped"
        test "$(xmlstarlet select --template --value-of /serversettings/@GameModeIdentifier "${settings}")" = campaign
        test "$(xmlstarlet select --template --value-of /serversettings/@IsPublic "${settings}")" = False
        test "$(xmlstarlet select --template --value-of /serversettings/@FutureUpstreamSetting "${settings}")" = preserve-me
        test "$(xmlstarlet select --template --value-of "count(/serversettings/@name)" "${settings}")" = 0
        test "$(xmlstarlet select --template --value-of /serversettings/CampaignSettings/@PreservedChild "${settings}")" = true
    '

docker run --rm \
    --volume "${BOOTSTRAP_VOLUME}:/data" \
    --env UPDATE_ON_START=false \
    --env MANAGE_SERVER_SETTINGS=true \
    --env BAROTRAUMA_GAME_MODE_IDENTIFIER=campaign \
    "${IMAGE_NAME}" \
    sh -euc '
        settings=/data/barotrauma/serversettings.xml
        test "$(xmlstarlet select --template --value-of "name(/*)" "${settings}")" = serversettings
        test "$(xmlstarlet select --template --value-of /serversettings/@GameModeIdentifier "${settings}")" = campaign
    '

echo "Managed server settings merge verified"
