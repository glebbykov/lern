# Overview и установка

## Карта курса

```text
Docker Lab
├─ Images / Dockerfile
├─ Containers / Runtime
├─ Networks / DNS
├─ Volumes / Storage
├─ Registry / Release
└─ Build / Security / Ops
```

## Концептуальная схема

```text
[Dockerfile] --build--> [Image Layers] --run--> [Container]
      |                          |                   |
      |                          v                   v
      |                    [Registry]          [Logs / Metrics]
      |                                              |
      v                                              v
 [Build Cache]                                [Troubleshooting]

[Container] <--> [Network / DNS] <--> [Other Services]
[Container] <--> [Volume / Bind Mount] <--> [Persistent Data]
```

## Мини-чек установки
1. `docker version`
2. `docker info`
3. `docker run hello-world`
4. Проверка compose: `docker compose version`

## Definition of done
- Понимаете разницу `image` vs `container`.
- Можете объяснить, зачем нужны слои и кеш сборки.
- Окружение готово к запуску следующих модулей.
