#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPOSITORY_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPOSITORY_ROOT
readonly IMAGE_NAME="${IMAGE_NAME:-docker-barotrauma:test}"
readonly CONTAINER_NAME="docker-barotrauma-test-${BASHPID}"
readonly VOLUME_NAME="docker-barotrauma-test-${BASHPID}"
readonly WORKSHOP_FIXTURE=2701251094

# shellcheck disable=SC2329 # Invoked by the EXIT trap.
cleanup() {
    docker rm --force "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    docker volume rm "${VOLUME_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cd "${REPOSITORY_ROOT}"

if [[ "${BUILD_IMAGE:-true}" == true ]]; then
    docker build --tag "${IMAGE_NAME}" .
fi

docker volume create "${VOLUME_NAME}" >/dev/null
docker run \
    --detach \
    --name "${CONTAINER_NAME}" \
    --env-file .env.example \
    --env BAROTRAUMA_NAME=integration \
    --env STEAMCMD_VALIDATE=false \
    --env WORKSHOP_ITEMS="${WORKSHOP_FIXTURE}" \
    --volume "${VOLUME_NAME}:/data" \
    "${IMAGE_NAME}" >/dev/null

for _ in {1..240}; do
    logs="$(docker logs "${CONTAINER_NAME}" 2>&1)"

    if grep --quiet 'Server started' <<<"${logs}"; then
        docker stop --timeout 60 "${CONTAINER_NAME}" >/dev/null
        logs="$(docker logs "${CONTAINER_NAME}" 2>&1)"
        state="$(docker inspect --format '{{.State.Status}} {{.State.ExitCode}}' "${CONTAINER_NAME}")"

        docker run --rm \
            --volume "${VOLUME_NAME}:/data" \
            --volume "${REPOSITORY_ROOT}/tests/validate-settings-schema.sh:/validate-settings-schema.sh:ro" \
            --entrypoint sh \
            "${IMAGE_NAME}" \
            -c "test -L '/data/state/Daedalic Entertainment GmbH/Barotrauma/WorkshopMods/Installed/${WORKSHOP_FIXTURE}' \
                && grep -R --quiet 'Shutting down the server' /data/barotrauma/ServerLogs \
                && grep --quiet '${WORKSHOP_FIXTURE}/filelist.xml' /data/barotrauma/config_player.xml \
                && grep --quiet 'MaxLagCompensation=' /data/barotrauma/serversettings.xml \
                && bash /validate-settings-schema.sh /data/barotrauma/serversettings.xml /opt/barotrauma/serversettings.envmap"

        if [[ "${state}" == 'exited 0' ]] \
            && grep --quiet 'asking Barotrauma to close cleanly' <<<"${logs}"; then
            echo "Barotrauma startup, Workshop installation, and graceful shutdown verified"
            exit 0
        fi

        echo "${logs}"
        echo "Unexpected container state after shutdown: ${state}" >&2
        exit 1
    fi

    if [[ "$(docker inspect --format '{{.State.Running}}' "${CONTAINER_NAME}")" != true ]]; then
        echo "${logs}"
        echo "Barotrauma container exited before startup completed" >&2
        exit 1
    fi

    sleep 2
done

docker logs "${CONTAINER_NAME}"
echo "Barotrauma did not complete startup within eight minutes" >&2
exit 1
