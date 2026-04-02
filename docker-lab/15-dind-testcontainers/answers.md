# Ответы: 15-dind-testcontainers

## Результаты выполнения

- [ ] Часть 1: socket mount — собрал образ изнутри CI-контейнера
- [ ] Часть 2: DinD — запустил отдельный daemon, собрал образ
- [ ] Часть 3: понимаю разницу socket mount vs DinD
- [ ] Часть 4: Testcontainers Go — тест с настоящим Postgres прошёл
- [ ] Часть 4: Testcontainers Python — тест с настоящим Redis прошёл
- [ ] Часть 5: понимаю как настроить Testcontainers в CI
- [ ] Часть 6: нашёл и объяснил проблемы в broken-сценариях

## Ответы на вопросы

1. Почему socket mount — это фактически root-доступ к хосту?

2. Чем DinD-изоляция лучше socket mount? В чём её минусы?

3. Что такое `--privileged` и какие ограничения он снимает?

4. Как Testcontainers решают проблему «у меня другая версия Postgres»?

5. Почему Sysbox безопаснее классического DinD?

6. Как настроить Testcontainers в GitLab CI с DinD-сервисом?

7. Что произойдёт с контейнерами, созданными через socket mount, при смерти CI-контейнера?

8. Почему Testcontainers используют рандомные порты, а не фиксированные?

## Найденные проблемы в broken

- `compose-no-cli.yaml`:
- `compose-wrong-perms.yaml`:
- `compose-dind-no-priv.yaml`:

## Что улучшить

-
