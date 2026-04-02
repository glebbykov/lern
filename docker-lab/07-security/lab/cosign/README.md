# Cosign: подпись и верификация Docker-образов
#
# Supply chain security: убедиться что образ не подменён.
# cosign sign — подписывает образ закрытым ключом
# cosign verify — проверяет подпись публичным ключом
#
# Установка cosign:
#   go install github.com/sigstore/cosign/v2/cmd/cosign@latest
#   или: brew install cosign
#
# Использование:
#
# 1. Генерация ключей (один раз):
#    cosign generate-key-pair
#    → cosign.key (private), cosign.pub (public)
#
# 2. Подписать образ (после push в registry):
#    cosign sign --key cosign.key localhost:5000/myapp:1.0.0
#
# 3. Проверить подпись:
#    cosign verify --key cosign.pub localhost:5000/myapp:1.0.0
#
# 4. Keyless signing (через OIDC — GitHub, Google):
#    COSIGN_EXPERIMENTAL=1 cosign sign ghcr.io/owner/app:1.0.0
#    → подписывает через GitHub identity без локальных ключей
#
# Policy check в CI:
#    cosign verify --key cosign.pub $IMAGE || exit 1

# Этот файл — шпаргалка. Практика требует registry (модуль 09).
# Полный флоу:
#   1. Поднять registry:  docker run -d -p 5000:5000 registry:2
#   2. Собрать образ:     docker build -t localhost:5000/myapp:1.0.0 .
#   3. Запушить:          docker push localhost:5000/myapp:1.0.0
#   4. Подписать:         cosign sign --key cosign.key localhost:5000/myapp:1.0.0
#   5. Верифицировать:    cosign verify --key cosign.pub localhost:5000/myapp:1.0.0
