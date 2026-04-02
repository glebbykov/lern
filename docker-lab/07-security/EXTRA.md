# 07 — Дополнительные материалы

## Cosign: подпись образов (lab/cosign/)

Supply chain security: убедиться что образ не был подменён.

```bash
# Установка
go install github.com/sigstore/cosign/v2/cmd/cosign@latest

# Генерация ключей
cosign generate-key-pair
# → cosign.key (private), cosign.pub (public)

# Подписать (нужен registry)
cosign sign --key cosign.key localhost:5000/myapp:1.0.0

# Проверить
cosign verify --key cosign.pub localhost:5000/myapp:1.0.0
```

Подробный гайд: `lab/cosign/README.md`

---

## Broken: setuid обход cap_drop (broken/Dockerfile.setuid)

`cap_drop: ALL` не защищает от setuid-бинарников без `no-new-privileges`:

```bash
# Собрать
docker build -t setuid-test -f broken/Dockerfile.setuid .

# Без no-new-privileges:
docker run --rm --cap-drop ALL setuid-test
# id via setuid: uid=0(root)  ← повышение привилегий!

# С no-new-privileges (fix):
docker run --rm --cap-drop ALL --security-opt no-new-privileges:true setuid-test
# id via setuid: uid=1000(appuser)  ← setuid-бит игнорируется
```
