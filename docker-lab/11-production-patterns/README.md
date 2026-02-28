# 11. Production patterns (Compose -> Kubernetes mindset)

## Цель
Отработать практики деплоя и понять, где Compose заканчивается и начинается необходимость оркестратора.

## Теория
- Compose удобен для single-host и интеграционных стендов.
- Для self-healing, scheduler, declarative rollout на масштабе нужен оркестратор.
- Blue/green можно смоделировать локально через reverse proxy.

## Практика
1. Поднимите blue/green стенд:
```bash
docker compose -f lab/compose.yaml up -d
```
2. Проверьте текущую активную версию:
```bash
curl http://localhost:8087
```
3. Переключите трафик на green:
```bash
./lab/scripts/switch-to-green.sh
curl http://localhost:8087
```
4. Верните на blue:
```bash
./lab/scripts/switch-to-blue.sh
```

## Проверка
- Переключение происходит без простоя прокси.
- Понимаете эквиваленты в Kubernetes (`Deployment`, `Service`, `ConfigMap`, `Secret`).

## Типовые ошибки
- Перезагрузка прокси без валидации конфига.
- Отсутствие rollback-команды.
- Смешивание статических и секретных конфигов.

## Вопросы
1. Какие ограничения blue/green через Compose на одном хосте?
2. Какой минимальный rollback-план нужен?
3. Как вы бы замапили этот стенд в Kubernetes примитивы?

## Дополнительные задания
- Добавьте pre-deploy миграцию БД.
- Добавьте smoke-test до переключения трафика.

## Cleanup
```bash
./cleanup.sh
```
