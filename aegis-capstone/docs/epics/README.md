---
title: Индекс эпиков
status: stable
audience: [contributors, llm, reviewers]
last_verified: 2026-05-01
---

# Эпики

Тематические крупные изменения, разбитые на подзадачи. Один эпик = одна цель уровня "phase".

| ID | Название | Status |
|---|---|---|
| [EP-001](EP-001-phase-3-stateful-tier.md) | Phase 3 — переезд stateful tier на az-db через WG overlay | Open |
| [EP-002](EP-002-postgres-overlay.md) | PostgreSQL — переезд на az-db (PG-only подмножество EP-001) | Open |

## Формат

`EPNN-kebab-name.md` со структурой:
- **Контекст** — почему делаем
- **Definition of Done** — что считать завершением
- **Задачи (T-N)** — каждая со своим Plan, AC, Risks, Dependencies
- **Граф зависимостей** — Mermaid
- **Out of scope** — что отложено
