# 04-quotas

## Задача
Ограничить namespace `lab`, чтобы избежать перегрузки нод 2GB.

## Проверка
- Применен `ResourceQuota`.
- Применен `LimitRange`.
- Pod без requests/limits получает дефолты.
