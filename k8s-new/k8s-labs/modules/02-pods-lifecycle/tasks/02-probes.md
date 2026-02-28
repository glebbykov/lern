# 02-probes

## Цель
Увидеть, как probes влияют на доступность через Service.

## Шаги
1. Запустить `manifests/probes`.
2. Применить broken вариант из `broken/02-readiness-fail`.
3. Проверить endpoints и события Pod.
4. Вернуть корректный вариант из `solutions/02-readiness-fail`.

## Проверка
- В broken-сценарии endpoints пустой.
- После fix Pod в статусе Ready.
