.DEFAULT_GOAL := help

IMAGE_NAME ?= docker-barotrauma

.PHONY: build down help integration logs run start stop test

help:
	@echo "Barotrauma dedicated server"
	@echo
	@echo "Targets:"
	@echo "  build        Build the local image"
	@echo "  test         Run fast syntax and configuration checks"
	@echo "  integration  Download, start, and stop a real server"
	@echo "  run          Build and start the server"
	@echo "  logs         Follow server logs"
	@echo "  start        Start the existing server"
	@echo "  stop         Stop the server gracefully"
	@echo "  down         Remove the container and network (preserves data)"

build:
	docker build --tag "$(IMAGE_NAME):latest" .

test:
	bash -n entrypoint.sh tests/integration.sh
	BAROTRAUMA_ENV_FILE=.env.example docker compose config --quiet

integration:
	bash tests/integration.sh

run:
	docker compose up --detach --build

logs:
	docker compose logs --follow barotrauma

start:
	docker compose start barotrauma

stop:
	docker compose stop barotrauma

down:
	docker compose down
