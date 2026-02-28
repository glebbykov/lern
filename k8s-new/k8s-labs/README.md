# k8s-labs

Практический репозиторий для поэтапного освоения Kubernetes на небольшом кластере (включая 2x2GB).

## Структура
- `docs/` базовые документы, чеклисты, runbook.
  - `docs/01-k8s-knowledge-checklist.md` общий чеклист понятий по темам (базовый/продвинутый).
- `scripts/` bootstrap, верификация и очистка стенда.
- `common/` общие namespaces, quotas, debug pod и шаблоны.
- `modules/` учебные модули 01-10 с заданиями, манифестами, поломками и проверками.
- `projects/` итоговые практические проекты.
- `.github/workflows/` CI-проверки YAML/манифестов.

## Быстрый старт
```bash
kubectl cluster-info
kubectl get nodes -o wide
./scripts/bootstrap/00-create-namespaces.sh
./scripts/bootstrap/01-apply-quotas.sh
```

## Рекомендуемый порядок
1. База и kubectl: `docs/00-prereqs.md`, `modules/01-kubectl-basics`
2. Lifecycle Pod: `modules/02-pods-lifecycle`
3. Workloads: `modules/03-workloads`
4. Сеть: `modules/04-networking`
5. Storage: `modules/05-storage`
6. Scheduling и ресурсы: `modules/06-scheduling`
7. Config и Security: `modules/07-config-security`
8. Observability: `modules/08-observability`
9. Helm и GitOps: `modules/09-helm-gitops`
10. kubeadm admin: `modules/10-kubeadm-admin`

## Верификация
```bash
./scripts/verify/verify-module.sh modules/01-kubectl-basics
./scripts/verify/verify-all.sh
```

## Профиль для 2GB нод
```bash
./scripts/bootstrap/02-install-metrics-server.sh
./scripts/bootstrap/03-install-ingress.sh
./scripts/bootstrap/04-apply-2gb-profile.sh
```

```powershell
./scripts/bootstrap/02-install-metrics-server.ps1
./scripts/bootstrap/03-install-ingress.ps1
./scripts/bootstrap/04-apply-2gb-profile.ps1
```
