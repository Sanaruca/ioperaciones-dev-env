#!/usr/bin/env bash
# Se ejecuta en cada arranque del contenedor.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/services.sh" start
bash "${SCRIPT_DIR}/check-env.sh" || true
