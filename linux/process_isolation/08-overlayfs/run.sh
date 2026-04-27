#!/usr/bin/env bash
# Этап 08: руками собираем overlay, демонстрируем CoW и whiteout.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"

BASE=/lab/08
log "готовим слои в $BASE"
rm -rf "$BASE"
mkdir -p "$BASE"/{lower,upper,work,merged}

# готовим «base image»
echo "from base layer" > "$BASE/lower/readme.txt"
echo "untouched"      > "$BASE/lower/untouched.txt"
mkdir "$BASE/lower/etc"
echo "host=base"      > "$BASE/lower/etc/config"

log "1) монтируем overlay"
mount -t overlay overlay \
  -o "lowerdir=$BASE/lower,upperdir=$BASE/upper,workdir=$BASE/work" \
  "$BASE/merged"

note "содержимое merged/ (видит контейнер):"
ls "$BASE/merged" | sed 's/^/   /'
echo "   readme.txt:    $(cat "$BASE/merged/readme.txt")"

# ─── 2) CoW при записи ───────────────────────────────────────────────────
log "2) Copy-on-Write: меняем readme.txt через merged"
echo "modified by container" > "$BASE/merged/readme.txt"
note "lower остался прежним:"
echo "   lower/readme.txt: $(cat "$BASE/lower/readme.txt")"
note "upper получил копию с правкой:"
echo "   upper/readme.txt: $(cat "$BASE/upper/readme.txt")"

# ─── 3) Whiteout при удалении ────────────────────────────────────────────
log "3) Whiteout: удаляем untouched.txt через merged"
rm "$BASE/merged/untouched.txt"
note "в upper появился char device 0,0:"
ls -la "$BASE/upper/untouched.txt" | sed 's/^/   /'
note "при ls merged/ файл пропал, хотя в lower он есть:"
ls "$BASE/merged/" | sed 's/^/   /'
echo "   lower/untouched.txt: $(cat "$BASE/lower/untouched.txt")  (физически жив!)"

# ─── 4) добавление нового файла ──────────────────────────────────────────
log "4) добавляем новый файл — попадает в upper"
echo "fresh" > "$BASE/merged/new-from-container.txt"
note "upper:"; ls "$BASE/upper" | sed 's/^/   /'

# ─── 5) multi-layer ──────────────────────────────────────────────────────
log "5) multi-layer: добавляем второй lower (как ADD-слой)"
umount "$BASE/merged"
mkdir -p "$BASE/lower2"
echo "from layer2" > "$BASE/lower2/layer2.txt"
echo "host=layer2" > "$BASE/lower2/etc/config" 2>/dev/null || { mkdir -p "$BASE/lower2/etc"; echo "host=layer2" > "$BASE/lower2/etc/config"; }
mount -t overlay overlay \
  -o "lowerdir=$BASE/lower2:$BASE/lower,upperdir=$BASE/upper,workdir=$BASE/work" \
  "$BASE/merged"
note "merged видит файл из lower2:"
ls "$BASE/merged" | sed 's/^/   /'
note "etc/config — побеждает верхний слой (lower2):"
echo "   $(cat "$BASE/merged/etc/config")"

log "приборка"
umount "$BASE/merged"
rm -rf "$BASE"
