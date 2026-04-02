# Ответы: 16-docker-to-kubernetes

## Результаты выполнения

- [ ] Часть 1: изучена таблица маппинга Compose → K8s
- [ ] Часть 2: `kompose convert` выполнен, результат изучен
- [ ] Часть 3: ручные манифесты изучены и объяснены
- [ ] Часть 4: валидация манифестов (`kubectl --dry-run` или yamllint)
- [ ] Часть 5: security context маппинг из модуля 07
- [ ] Часть 6: найдены и объяснены проблемы в broken-манифестах

## Ответы на вопросы

1. Чем livenessProbe отличается от readinessProbe?

2. Почему depends_on не имеет аналога в Kubernetes?

3. Что делает requests в resources и чем оно отличается от limits?

4. Почему пароли должны быть в Secret, а не в ConfigMap?

5. Как NetworkPolicy соотносится с networks: в Compose?

6. Что произойдёт, если selector.matchLabels не совпадает с template.labels?

7. Зачем нужен init container и как он решает проблему depends_on?

8. Как emptyDir с medium: Memory соотносится с tmpfs в Docker?

9. Какие концепции Compose нельзя выразить в Kubernetes без дополнительных инструментов?

## Найденные проблемы в broken

- `bad-selector.yaml`:
- `no-readiness.yaml`:
- `password-in-configmap.yaml`:

## Что улучшить

-
