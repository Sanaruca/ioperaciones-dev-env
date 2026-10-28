#!/usr/bin/env bash
# Imprime versiones instaladas y estado de los servicios.
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_DIR}"

line() { printf '  %-14s %s\n' "$1" "$2"; }
cmd_version() {
  local label="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    line "${label}" "$("$@" 2>&1 | head -n1)"
  else
    line "${label}" "no instalado"
  fi
}

echo
echo "=== Entorno de desarrollo ==="
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  line "Sistema" "$(. /etc/os-release && echo "${PRETTY_NAME}")"
fi
line "Usuario" "$(id -un) @ $(hostname)"
line "Proyecto" "${PROJECT_DIR}"
echo
echo "--- Herramientas ---"
cmd_version "Python" python3 --version
cmd_version "uv" uv --version
cmd_version "ruff" ruff --version
cmd_version "Node" node --version
cmd_version "npm" npm --version
cmd_version "fnm" fnm --version
cmd_version "bun" bun --version
cmd_version "OpenCode" opencode --version
cmd_version "PHP" php --version
cmd_version "Composer" composer --version --no-ansi
cmd_version "Apache" apache2 -v
cmd_version "PostgreSQL" psql --version
cmd_version "Ollama" ollama --version
echo
echo "--- Servicios ---"
if pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
  line "PostgreSQL" "OK  ($(pg_isready -h 127.0.0.1 -p 5432))"
else
  line "PostgreSQL" "CAÍDO (bash .devcontainer/scripts/services.sh start)"
fi
if curl -fsS --max-time 2 -o /dev/null http://127.0.0.1:8080/health.txt 2>/dev/null; then
  line "Apache" "OK  http://localhost:8080"
else
  line "Apache" "CAÍDO (bash .devcontainer/scripts/services.sh start)"
fi
if curl -fsS --max-time 2 http://127.0.0.1:11434/api/version >/dev/null 2>&1; then
  line "Ollama" "OK  http://localhost:11434"
else
  line "Ollama" "CAÍDO (bash .devcontainer/scripts/services.sh start)"
fi
if pgrep -x sshd >/dev/null 2>&1; then
  line "sshd" "OK  puerto 2222"
else
  line "sshd" "CAÍDO (bash .devcontainer/scripts/services.sh start)"
fi
echo
echo "--- Base de datos ---"
line "DATABASE_URL" "${DATABASE_URL:-postgresql://dev:dev@localhost:5432/dev}"
if pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
  line "psql" "$(psql -h 127.0.0.1 -U dev -d dev -tAc 'select version();' 2>&1 | head -n1)"
fi
echo
