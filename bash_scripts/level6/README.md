# Level 6 — getopts, trap, lockfile, конфиг-файл

## Что нового на этом уровне

| Приём | Зачем |
|-------|-------|
| `getopts` | стандартный парсинг флагов `-d`, `-m`, `-h` |
| `trap ... EXIT` | гарантированная очистка при любом завершении (сигнал, ошибка, exit) |
| lockfile (`/tmp/*.lock`) | защита от параллельного запуска двух копий скрипта |
| `--dry-run` / `-n` | безопасный режим: показать что будет сделано, ничего не трогать |
| конфиг-файл `.conf` | вынести параметры из кода, читать через `source` |
| `set -euo pipefail` | строгий режим: выход при ошибке, неизвестной переменной, сломанном пайпе |

## Скрипты

- `cleanup_old_files.sh` — удаление старых файлов с dry-run, lockfile и getopts
- `disk_usage_report.sh` — отчёт с записью в лог-файл, конфиг, флаги

## Ключевые идеи

```bash
set -euo pipefail

# getopts
while getopts "d:m:nh" opt; do
    case "$opt" in
        d) TARGET_DIR="$OPTARG" ;;
        m) MIN_AGE_DAYS="$OPTARG" ;;
        n) DRY_RUN=true ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

# lockfile — один экземпляр
LOCKFILE="/tmp/$(basename "$0").lock"
if ! mkdir "$LOCKFILE" 2>/dev/null; then
    die "Скрипт уже запущен (lock: $LOCKFILE)"
fi
trap 'rm -rf "$LOCKFILE"' EXIT

# dry-run
if $DRY_RUN; then
    log "[DRY-RUN] Удалить: $file"
else
    rm "$file"
fi
```
