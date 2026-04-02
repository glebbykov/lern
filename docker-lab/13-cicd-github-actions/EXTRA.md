# 13 — Дополнительные материалы

## GitLab CI Template (lab/gitlab-ci/)

Эквивалент GitHub Actions workflow для GitLab CI/CD:

```bash
cat lab/gitlab-ci/.gitlab-ci.yml
```

**Сравнение GitHub Actions vs GitLab CI:**

| Аспект | GitHub Actions | GitLab CI |
|---|---|---|
| Конфиг | `.github/workflows/*.yml` | `.gitlab-ci.yml` |
| Docker build | `docker/build-push-action` | DinD service |
| Registry | GHCR (`ghcr.io`) | GitLab Registry (`registry.gitlab.com`) |
| Cache | `type=gha` | `docker save/load` + artifacts |
| Secrets | `${{ secrets.TOKEN }}` | Variables (Settings → CI/CD) |
| Auth | `GITHUB_TOKEN` (auto) | `CI_REGISTRY_USER/PASSWORD` (auto) |
| Matrix builds | `strategy.matrix` | `parallel: / rules:` |

---

## SBOM Generation (lab/sbom/)

Software Bill of Materials — реестр всех компонентов в образе.

```bash
# Syft: генерация SBOM
docker run --rm anchore/syft:latest alpine:3.20 -o spdx-json

# Trivy: SBOM + vulnerability scan
docker run --rm aquasec/trivy:latest image --format spdx-json alpine:3.20

# Grype: сканирование готового SBOM
# grype sbom:sbom.spdx.json --fail-on high
```

Подробный гайд: `lab/sbom/README.md`
