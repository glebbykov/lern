# project-c-broken-cluster-lab

Цель: набор типовых поломок и runbook для диагностики.

## Сценарии
- CrashLoopBackOff
- Readiness fail
- ImagePullBackOff
- OOMKilled

## Подход
1. Применить broken манифест.
2. Зафиксировать симптомы (`describe`, `logs`, `events`).
3. Сформулировать гипотезу причины.
4. Применить solution.
5. Повторно проверить состояние.
