# 03-securitycontext

## Задача
Запустить workload с ограничениями безопасности.

## Минимум
- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true` (если приложение позволяет)
