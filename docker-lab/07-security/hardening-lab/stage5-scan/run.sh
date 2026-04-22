#!/usr/bin/env bash
# Этап 5 — скан уязвимостей. Сравниваем stage0 (ubuntu:latest) и stage3.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v trivy >/dev/null 2>&1; then
  echo "Trivy не установлен. Ставим в контейнере (однократно)..."
  # Не хотим модифицировать хост — запустим trivy через docker.
  TRIVY="docker run --rm \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v ${HOME}/.cache/trivy:/root/.cache/ \
      aquasec/trivy:0.50.1"
else
  TRIVY="trivy"
fi

mkdir -p reports

scan_image() {
  local image="$1"
  local out="reports/$(echo "$image" | tr '/:' '__').txt"
  echo "==> scan $image -> $out"
  # Сканируем ВСЕ severity: ubuntu:latest может быть чистым на HIGH/CRITICAL
  # (патчи накатываются), но будет кишеть LOW/MEDIUM. Именно этот
  # «long tail» и хочется видеть при сравнении с alpine.
  if $TRIVY image --severity LOW,MEDIUM,HIGH,CRITICAL --no-progress -q "$image" > "$out" 2>&1; then
    echo "   done"
  else
    echo "   trivy exited nonzero — смотрите $out"
  fi
  # Итоговая строка по severity.
  grep -E '^Total:' "$out" || true
}

echo "=== ожидаем, что stage0 (ubuntu:latest) — кошмар, stage3 (alpine) — почти пусто ==="
for img in hardening-lab/stage0:latest hardening-lab/stage3:latest; do
  if docker image inspect "$img" >/dev/null 2>&1; then
    scan_image "$img"
  else
    echo "Пропускаю $img — образ не собран. Прогоните соответствующий stage*/run.sh"
  fi
done

echo
echo "Отчёты лежат в $(pwd)/reports/"
ls -la reports/
