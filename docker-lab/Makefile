SHELL := /usr/bin/env bash

MODULE ?= 03-compose

.PHONY: up down lint test clean cleanup-all

up:
	@cd $(MODULE) && docker compose up -d

down:
	@cd $(MODULE) && docker compose down -v --remove-orphans

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
