# SBOM (Software Bill of Materials) generation
#
# SBOM — реестр всех компонентов в образе.
# Требуется для compliance (FDA, NIST, EU CRA).
#
# Инструменты:
#   - Syft (anchore) — генерация SBOM
#   - Trivy — SBOM + vulnerability scan
#   - Grype — сканирование SBOM на уязвимости
#
# CI: генерируем SBOM при каждом push и сохраняем как артефакт.

# ── Генерация SBOM через Syft ──────────────────────────────────

# Локально:
# docker run --rm anchore/syft:latest registry:myimage:tag -o spdx-json > sbom.spdx.json
# docker run --rm anchore/syft:latest registry:myimage:tag -o cyclonedx-json > sbom.cdx.json

# ── GitHub Actions: SBOM в pipeline ────────────────────────────
# (добавить как шаг после build, перед push)

# - name: Generate SBOM
#   uses: anchore/sbom-action@v0
#   with:
#     image: ${{ env.IMAGE }}:${{ github.sha }}
#     format: spdx-json
#     output-file: sbom.spdx.json
#
# - name: Upload SBOM
#   uses: actions/upload-artifact@v4
#   with:
#     name: sbom
#     path: sbom.spdx.json

# ── Trivy: SBOM + scan одной командой ──────────────────────────
# trivy image --format spdx-json --output sbom.spdx.json myimage:tag
# trivy sbom sbom.spdx.json  → сканирование готового SBOM

# ── Grype: сканирование SBOM ───────────────────────────────────
# grype sbom:sbom.spdx.json --fail-on high

# ── GitLab CI шаг ──────────────────────────────────────────────
# sbom:
#   stage: scan
#   image: anchore/syft:latest
#   script:
#     - syft docker:image.tar -o spdx-json > sbom.spdx.json
#   artifacts:
#     paths:
#       - sbom.spdx.json
#   dependencies:
#     - build
