#!/usr/bin/env bash
# Этап 09: руками собираем сеть контейнеров — veth, bridge, NAT.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require ip iptables

cleanup() {
  ip netns del alpha 2>/dev/null || true
  ip netns del beta  2>/dev/null || true
  ip netns del gamma 2>/dev/null || true
  ip link del lab-br 2>/dev/null || true
  iptables -t nat -D POSTROUTING -s 10.55.0.0/24 -j MASQUERADE 2>/dev/null || true
  iptables -D FORWARD -i lab-br -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -o lab-br -j ACCEPT 2>/dev/null || true
}
trap cleanup EXIT
cleanup  # на случай если предыдущий запуск умер посередине

# ─── часть 1 ──────────────────────────────────────────────────────────────
log "1) veth pair: соединяем alpha ↔ beta напрямую"
ip netns add alpha
ip netns add beta
ip link add veth-a type veth peer name veth-b
ip link set veth-a netns alpha
ip link set veth-b netns beta
ip netns exec alpha ip addr add 10.55.0.1/24 dev veth-a
ip netns exec alpha ip link set veth-a up
ip netns exec alpha ip link set lo up
ip netns exec beta  ip addr add 10.55.0.2/24 dev veth-b
ip netns exec beta  ip link set veth-b up
ip netns exec beta  ip link set lo up

note "ping alpha → beta:"
ip netns exec alpha ping -c 2 -W 1 10.55.0.2 | tail -3 | sed 's/^/   /'

# ─── часть 2 ──────────────────────────────────────────────────────────────
log "2) bridge: добавляем gamma и подключаем всех к мосту lab-br"
# чистим прямую связку — будем работать через мост
ip netns del alpha
ip netns del beta

ip link add lab-br type bridge
ip link set lab-br up
ip addr add 10.55.0.254/24 dev lab-br

for ns in alpha beta gamma; do
  ip netns add "$ns"
  ip link add "veth-${ns}" type veth peer name "br-${ns}"
  ip link set "br-${ns}" master lab-br
  ip link set "br-${ns}" up
  ip link set "veth-${ns}" netns "$ns"
done
ip netns exec alpha ip addr add 10.55.0.1/24 dev veth-alpha
ip netns exec beta  ip addr add 10.55.0.2/24 dev veth-beta
ip netns exec gamma ip addr add 10.55.0.3/24 dev veth-gamma
for ns in alpha beta gamma; do
  ip netns exec "$ns" ip link set "veth-${ns}" up
  ip netns exec "$ns" ip link set lo up
  ip netns exec "$ns" ip route add default via 10.55.0.254
done

note "ping alpha → gamma через мост:"
ip netns exec alpha ping -c 2 -W 1 10.55.0.3 | tail -3 | sed 's/^/   /'

# ─── часть 3 ──────────────────────────────────────────────────────────────
log "3) NAT outbound: alpha должна пинговать 1.1.1.1"
sysctl -w net.ipv4.ip_forward=1 >/dev/null
EXT_IF=$(ip -o route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++)if($i=="dev"){print $(i+1);exit}}')
note "внешний интерфейс хоста: $EXT_IF"

iptables -t nat -A POSTROUTING -s 10.55.0.0/24 -j MASQUERADE
iptables -A FORWARD -i lab-br -j ACCEPT
iptables -A FORWARD -o lab-br -j ACCEPT

note "ping alpha → 1.1.1.1 (через NAT):"
ip netns exec alpha ping -c 2 -W 2 1.1.1.1 | tail -3 | sed 's/^/   /' || \
  echo "   (если не работает — проверь, что у хоста есть выход в инет)"
