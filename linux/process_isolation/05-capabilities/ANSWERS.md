# 05 — Capabilities: контрольные вопросы

**Чем capability лучше setuid?**
SUID-bit делает процесс полным root (все 40+ caps), даже если ему нужна
одна — это огромная attack surface. Capability даёт строго нужную
привилегию, остальные остаются недоступны.

**Что значит `+ep` в `setcap cap_net_bind_service+ep`?**
- `e` (effective) — capability сразу активна после execve.
- `p` (permitted) — может быть включена/выключена процессом.
- `i` (inheritable) — наследуется через execve в дочернюю программу.
Полный синтаксис: `man cap_from_text`.

**Где смотреть caps процесса?**
`/proc/<pid>/status` → `CapPrm`, `CapEff`, `CapInh`, `CapBnd`, `CapAmb`
(битмаски в hex). Декодировать: `capsh --decode=00000000a80425fb`.

**Что такое ambient capabilities?**
С ядра 4.3. Раньше не-setuid не-file-cap бинарь не мог унаследовать caps
от родителя. Ambient — это «caps, которые текут через execve без
файловых атрибутов». Используются systemd для `AmbientCapabilities=`.

**Почему `CAP_SYS_ADMIN` называют «новым root»?**
Эта capability разрешает сотни вещей: mount, namespace creation,
keyring management, arbitrary `setdomainname`, и т.д. Контейнерные
рантаймы её обычно дропают (Docker дефолтно — нет, и это известная
претензия безопасников).
