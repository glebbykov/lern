SHELL := /usr/bin/env bash

MODULE ?= 03-compose
LAB_COMPOSE := $(MODULE)/lab/compose.yaml
ROOT_COMPOSE := $(MODULE)/compose.yaml

.PHONY: up down lint test clean cleanup-all

up:
	@if [ -f "$(LAB_COMPOSE)" ]; then \
		docker compose -f "$(LAB_COMPOSE)" up -d --build; \
	elif [ -f "$(ROOT_COMPOSE)" ]; then \
		docker compose -f "$(ROOT_COMPOSE)" up -d --build; \
	else \
		echo "compose file not found for $(MODULE)"; \
		exit 1; \
	fi

down:
	@if [ -f "$(LAB_COMPOSE)" ]; then \
		docker compose -f "$(LAB_COMPOSE)" down -v --remove-orphans; \
	elif [ -f "$(ROOT_COMPOSE)" ]; then \
		docker compose -f "$(ROOT_COMPOSE)" down -v --remove-orphans; \
	else \
		echo "compose file not found for $(MODULE)"; \
		exit 1; \
	fi

lint:
	@./scripts/lint.sh

test:
	@./scripts/test-compose.sh

cleanup-all:
	@./scripts/cleanup-all.sh

clean: cleanup-all
	@docker image prune -f >/dev/null 2>&1 || true
	@docker container prune -f >/dev/null 2>&1 || true
	@docker network prune -f >/dev/null 2>&1 || true
