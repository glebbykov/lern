#!/usr/bin/env bash
# Прогоняет check.sh всех этапов по очереди. Считает PASS/FAIL.
# Если какой-то check упал, продолжаем (чтобы увидеть полную картину).
set -uo pipefail
cd "$(dirname "$0")"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "запусти как root: sudo ./run-all.sh" >&2
  exit 1
fi

STAGES=(
  00-setup
  01-chroot
  02-namespaces
  03-pivot-root
  04-cgroups-v2
  05-capabilities
  06-seccomp
  07-apparmor
  08-overlayfs
  09-networking
  10-rootfs-and-nspawn
  11-capstone
  12-rootless
  13-oci-runc
  14-ebpf
)

C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_YELLOW=$'\033[33m'; C_RESET=$'\033[0m'

OK=()
FAIL=()
SKIP=()

for s in "${STAGES[@]}"; do
  echo
  echo "############################################################"
  echo "##  STAGE $s"
  echo "############################################################"
  if [[ ! -x "./$s/check.sh" ]]; then
    echo "  $s: нет check.sh — пропускаем"
    SKIP+=("$s")
    continue
  fi
  if ./"$s"/check.sh; then
    OK+=("$s")
  else
    FAIL+=("$s")
  fi
done

echo
echo "============================================================"
echo "ИТОГО:"
echo "============================================================"
for s in "${OK[@]}";   do printf "  %s✓ PASS%s   %s\n" "$C_GREEN" "$C_RESET" "$s"; done
for s in "${FAIL[@]}"; do printf "  %s✗ FAIL%s   %s\n" "$C_RED"   "$C_RESET" "$s"; done
for s in "${SKIP[@]}"; do printf "  %s- SKIP%s   %s\n" "$C_YELLOW" "$C_RESET" "$s"; done

echo
echo "PASS: ${#OK[@]}  FAIL: ${#FAIL[@]}  SKIP: ${#SKIP[@]}"
[[ ${#FAIL[@]} -eq 0 ]]
