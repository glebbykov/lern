#!/usr/bin/env bash
# Автотест 09: ping между netns через мост, ping наружу через NAT.
set -uo pipefail
. "$(dirname "$0")/../scripts/lib.sh"
require ip iptables

cleanup() {
  ip netns del a-check 2>/dev/null || true
  ip netns del b-check 2>/dev/null || true
  ip link del lab-br-c 2>/dev/null || true
  iptables -t nat -D POSTROUTING -s 10.66.0.0/24 -j MASQUERADE 2>/dev/null || true
  iptables -D FORWARD -i lab-br-c -j ACCEPT 2>/dev/null || true
  iptables -D FORWARD -o lab-br-c -j ACCEPT 2>/dev/null || true
}
trap cleanup EXIT
cleanup

ip link add lab-br-c type bridge
ip link set lab-br-c up
ip addr add 10.66.0.254/24 dev lab-br-c

for ns in a-check b-check; do
  ip netns add "$ns"
  ip link add "veth-${ns}" type veth peer name "br-${ns}"
  ip link set "br-${ns}" master lab-br-c
  ip link set "br-${ns}" up
  ip link set "veth-${ns}" netns "$ns"
done
ip netns exec a-check ip addr add 10.66.0.1/24 dev veth-a-check
ip netns exec b-check ip addr add 10.66.0.2/24 dev veth-b-check
for ns in a-check b-check; do
  ip netns exec "$ns" ip link set "veth-${ns}" up
  ip netns exec "$ns" ip link set lo up
  ip netns exec "$ns" ip route add default via 10.66.0.254
done

assert "ping a-check → b-check (через мост, L2)" \
  ip netns exec a-check ping -c 1 -W 1 10.66.0.2

assert "ping a-check → шлюз (мост на хосте)" \
  ip netns exec a-check ping -c 1 -W 1 10.66.0.254

# NAT outbound
sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -t nat -A POSTROUTING -s 10.66.0.0/24 -j MASQUERADE
iptables -A FORWARD -i lab-br-c -j ACCEPT
iptables -A FORWARD -o lab-br-c -j ACCEPT

assert "ping a-check → 1.1.1.1 через NAT (требует интернет на хосте)" \
  ip netns exec a-check ping -c 1 -W 3 1.1.1.1

summary
