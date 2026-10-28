#!/usr/bin/env bash
# Tareas de inicialización (se ejecutan una vez al crear el contenedor).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_DIR}"

echo "==> post-create: preparando el entorno"

# Node disponible también en shells no interactivos
export FNM_DIR=/usr/local/share/fnm
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --shell bash)" 2>/dev/null || true
fi

# Claves públicas opcionales para el sshd interno (:2222)
KEYS_FILE="${PROJECT_DIR}/.devcontainer/ssh/authorized_keys"
if [ -f "${KEYS_FILE}" ]; then
  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  touch "${HOME}/.ssh/authorized_keys"
  chmod 600 "${HOME}/.ssh/authorized_keys"
  while IFS= read -r key || [ -n "${key}" ]; do
    [ -z "${key}" ] && continue
    case "${key}" in \#*) continue ;; esac
    grep -qxF "${key}" "${HOME}/.ssh/authorized_keys" 2>/dev/null || echo "${key}" >> "${HOME}/.ssh/authorized_keys"
  done < "${KEYS_FILE}"
  echo "Claves SSH añadidas al usuario $(id -un)."
fi

# .env de desarrollo a partir del ejemplo
if [ ! -f .env ] && [ -f .env.example ]; then
  cp .env.example .env
  echo "Creado .env a partir de .env.example."
fi

# Los volúmenes nuevos pueden heredar propietario root; lo corregimos por si acaso.
if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  sudo chown -R "$(id -u):$(id -g)" \
    "${HOME}/.ollama" "${HOME}/.cache/uv" "${HOME}/.cache/composer" \
    "${HOME}/.config/opencode" "${HOME}/.local/share/opencode" 2>/dev/null || true
  sudo chown -R postgres:postgres /var/lib/postgresql/18/main 2>/dev/null || true
  sudo chmod 700 /var/lib/postgresql/18/main 2>/dev/null || true
elif [ "$(id -u)" = "0" ]; then
  chown -R vscode:vscode \
    "${HOME}/.ollama" "${HOME}/.cache/uv" "${HOME}/.cache/composer" \
    "${HOME}/.config/opencode" "${HOME}/.local/share/opencode" 2>/dev/null || true
  chown -R postgres:postgres /var/lib/postgresql/18/main 2>/dev/null || true
  chmod 700 /var/lib/postgresql/18/main 2>/dev/null || true
fi

# Aseguramos que los servicios están arriba antes de inicializar la base de datos
bash "${SCRIPT_DIR}/services.sh" start || true

# Base de datos de desarrollo (idempotente)
if pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; then
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='dev'" 2>/dev/null | grep -q 1; then
      sudo -u postgres psql -v ON_ERROR_STOP=1 \
        -c "CREATE ROLE dev WITH LOGIN PASSWORD 'dev' SUPERUSER;" 2>/dev/null || true
      echo "Rol PostgreSQL 'dev' creado."
    fi
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='dev'" 2>/dev/null | grep -q 1; then
      sudo -u postgres createdb --owner=dev dev 2>/dev/null || true
      echo "Base de datos 'dev' creada."
    fi
  elif [ "$(id -u)" = "0" ]; then
    if ! su -s /bin/bash postgres -c "psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='dev'\"" 2>/dev/null | grep -q 1; then
      su -s /bin/bash postgres -c "psql -v ON_ERROR_STOP=1 -c \"CREATE ROLE dev WITH LOGIN PASSWORD 'dev' SUPERUSER;\"" 2>/dev/null || true
      echo "Rol PostgreSQL 'dev' creado."
    fi
    if ! su -s /bin/bash postgres -c "psql -tAc \"SELECT 1 FROM pg_database WHERE datname='dev'\"" 2>/dev/null | grep -q 1; then
      su -s /bin/bash postgres -c "createdb --owner=dev dev" 2>/dev/null || true
      echo "Base de datos 'dev' creada."
    fi
  else
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='dev'" 2>/dev/null | grep -q 1; then
      sudo -u postgres psql -v ON_ERROR_STOP=1 \
        -c "CREATE ROLE dev WITH LOGIN PASSWORD 'dev' SUPERUSER;" 2>/dev/null || true
      echo "Rol PostgreSQL 'dev' creado."
    fi
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='dev'" 2>/dev/null | grep -q 1; then
      sudo -u postgres createdb --owner=dev dev 2>/dev/null || true
      echo "Base de datos 'dev' creada."
    fi
  fi
else
  echo "AVISO: PostgreSQL no está disponible; se omite la creación de la base de datos." >&2
fi

# Dependencias Python del proyecto, si existen
if [ -f pyproject.toml ]; then
  echo "Sincronizando dependencias Python con uv..."
  uv sync || echo "AVISO: 'uv sync' falló; ejecútalo manualmente." >&2
fi

mkdir -p "${HOME}/.cache/composer" "${HOME}/.ollama/models" 2>/dev/null || true

bash "${SCRIPT_DIR}/check-env.sh" || true
echo "==> post-create: listo"
exit 0

