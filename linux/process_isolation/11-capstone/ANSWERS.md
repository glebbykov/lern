# 11 — Capstone: рефлексия

**Что общего у нашего mycontainer и `docker run`?**
Оба используют одни и те же системные вызовы:
- `unshare(CLONE_NEW*)` или `clone(CLONE_NEW*)` — создание namespaces.
- `mount(MS_PRIVATE|MS_REC)` + `mount("overlay", ...)` — overlayfs.
- `pivot_root(2)` — смена корня.
- `setns()` / `prctl(PR_CAPBSET_DROP, ...)` — capabilities.
- `prctl(PR_SET_SECCOMP, MODE_FILTER, ...)` — seccomp.
- `write` в `/sys/fs/cgroup/.../*.max` — cgroup лимиты.
- `setns()` для подключения к bridge через veth.

`docker run` под капотом — это `dockerd → containerd → runc`, и runc
делает почти то же самое, что наш bash-скрипт, только на C/Go.

**Чем mycontainer отличается от Docker?**
- Нет registry / image distribution — только локальный rootfs.
- Нет multi-layer image build (Dockerfile).
- Нет сетевой автоматики — bridge надо собирать руками.
- Нет AppArmor profile по умолчанию.
- Нет user-ns и rootless-режима.
- Нет логов в journald.
- Нет healthchecks, restart policies, и сотни других фич.

Но **ядро видит наш контейнер ровно так же, как docker-овский** —
тот же `task_struct` с теми же ns inode-ами и cgroup путями.

**Как Kubernetes видит наш контейнер?**
Никак — kubelet общается с CRI (containerd, CRI-O), а не с произвольными
рантаймами. Чтобы наш mycontainer стал «kubernetes-совместимым»,
нужно реализовать CRI gRPC API. Это +5 тысяч строк кода.

**Что почитать дальше?**
- `runc` исходники — github.com/opencontainers/runc/libcontainer/
- OCI Runtime Specification — github.com/opencontainers/runtime-spec
- LWN серия "Namespaces in Operation" by Michael Kerrisk.
- Liz Rice, "Container Security" — главы 3-6 про namespaces/cgroups.
