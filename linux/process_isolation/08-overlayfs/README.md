# 08 — OverlayFS: слоистая файловая система

## Идея

Контейнерные образы — это слои. На рантайме слои объединяются в одну
ФС через **OverlayFS** (с ядра 3.18, единственный union-FS в mainline).

Терминология:

```
                        merged (то, что видит контейнер)
                           |
            ┌──────────────┼──────────────┐
            │              │              │
        upper (rw)     lowerdir 1     lowerdir 2
        изменения      (read-only)    (read-only)
        контейнера     слой image     слой image
```

`workdir` — служебная папка ядра для атомарных переименований при CoW.

## Что демонстрируем

1. **Сборка**: `mount -t overlay overlay -o lowerdir=...,upperdir=...,workdir=... merged`.
2. **CoW (Copy-on-Write)**: `echo X > merged/file.txt` → файл появляется
   в upper, lower не тронут. Открыли image заново — там по-прежнему
   оригинал.
3. **Whiteout**: `rm merged/file.txt` → в upper создаётся char device
   `0,0` с тем же именем. Это маркер удаления. Ядро при `readdir`
   видит его и не показывает файл из lower.
4. **Multi-layer**: несколько `lowerdir` через `:`-разделитель —
   как `FROM` ... `ADD` слои в Dockerfile.

## Запуск

```bash
sudo ./run.sh
sudo ./check.sh
```

## Карта в Docker

| Здесь | Docker |
|---|---|
| `lowerdir=base:lib:app` | слои image (от FROM до последнего RUN) |
| `upperdir=container-rw` | r/w слой контейнера (`/var/lib/docker/overlay2/.../diff`) |
| char device `0,0` | whiteout от `RUN rm` или удаления внутри контейнера |
| `merged/` | то, что видит процесс в контейнере |

`docker diff <container>` показывает содержимое upper-слоя — все
изменения относительно image.

`docker commit` — фактически делает `tar -c upper/` и сохраняет как
новый image-слой.
