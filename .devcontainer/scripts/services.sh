#!/usr/bin/env bash
# Arranca/para/consulta los servicios del contenedor (no hay systemd).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_DIR}"

export OLLAMA_MODELS="${OLLAMA_MODELS:-${HOME}/.ollama/models}"
OLLAMA_BIND="${OLLAMA_BIND:-0.0.0.0:11434}"
OLLAMA_LOG="${OLLAMA_LOG:-${HOME}/.ollama/ollama.log}"

pg_up()     { pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1; }
apache_up() { curl -fsS --max-time 2 -o /dev/null http://127.0.0.1:8080/health.txt 2>/dev/null; }
ollama_up() { curl -fsS --max-time 2 http://127.0.0.1:11434/api/version >/dev/null 2>&1; }
sshd_up()   { pgrep -x sshd >/dev/null 2>&1; }

start_postgres() {
  if pg_up; then
    echo "PostgreSQL ya está en marcha."
    return 0
  fi
  echo "Arrancando PostgreSQL..."
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo chown -R postgres:postgres /var/lib/postgresql/18/main 2>/dev/null || true
    sudo chmod 700 /var/lib/postgresql/18/main 2>/dev/null || true
    sudo pg_ctlcluster 18 main start
  elif [ "$(id -u)" = "0" ]; then
    chown -R postgres:postgres /var/lib/postgresql/18/main 2>/dev/null || true
    chmod 700 /var/lib/postgresql/18/main 2>/dev/null || true
    pg_ctlcluster 18 main start
  else
    sudo chown -R postgres:postgres /var/lib/postgresql/18/main 2>/dev/null || true
    sudo chmod 700 /var/lib/postgresql/18/main 2>/dev/null || true
    sudo pg_ctlcluster 18 main start
  fi
  for _ in $(seq 1 30); do
    if pg_up; then echo "PostgreSQL listo."; return 0; fi
    sleep 1
  done
  echo "ERROR: PostgreSQL no respondió en 30s." >&2
  return 1
}

start_apache() {
  if apache_up; then
    echo "Apache ya está en marcha."
    return 0
  fi
  echo "Arrancando Apache..."
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo /etc/init.d/apache2 start
  elif [ "$(id -u)" = "0" ]; then
    /etc/init.d/apache2 start
  else
    sudo /etc/init.d/apache2 start
  fi
  for _ in $(seq 1 15); do
    if apache_up; then echo "Apache listo en :8080."; return 0; fi
    sleep 1
  done
  echo "ERROR: Apache no respondió en :8080." >&2
  (sudo tail -n 20 /var/log/apache2/error.log 2>/dev/null || tail -n 20 /var/log/apache2/error.log 2>/dev/null) >&2 || true
  return 1
}

start_ollama() {
  if ollama_up; then
    echo "Ollama ya está en marcha."
    return 0
  fi
  echo "Arrancando Ollama en ${OLLAMA_BIND}..."
  mkdir -p "${OLLAMA_MODELS}" "$(dirname "${OLLAMA_LOG}")"
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo chown -R vscode:vscode "${HOME}/.ollama" 2>/dev/null || true
  elif [ "$(id -u)" = "0" ]; then
    chown -R vscode:vscode "${HOME}/.ollama" 2>/dev/null || true
  else
    sudo chown -R vscode:vscode "${HOME}/.ollama" 2>/dev/null || true
  fi
  OLLAMA_HOST="${OLLAMA_BIND}" OLLAMA_MODELS="${OLLAMA_MODELS}" \
    nohup ollama serve >>"${OLLAMA_LOG}" 2>&1 &
  for _ in $(seq 1 30); do
    if ollama_up; then echo "Ollama listo en :11434."; return 0; fi
    sleep 1
  done
  echo "ERROR: Ollama no respondió en :11434." >&2
  tail -n 20 "${OLLAMA_LOG}" >&2 || true
  return 1
}

start_sshd() {
  if sshd_up; then
    echo "sshd ya está en marcha."
    return 0
  fi
  echo "Arrancando sshd en :2222..."
  if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    sudo mkdir -p /run/sshd
    sudo /usr/sbin/sshd
  elif [ "$(id -u)" = "0" ]; then
    mkdir -p /run/sshd
    /usr/sbin/sshd
  else
    sudo mkdir -p /run/sshd
    sudo /usr/sbin/sshd
  fi
  if sshd_up; then echo "sshd listo en :2222."; else echo "ERROR: sshd no arrancó." >&2; return 1; fi
}

stop_all() {
  if apache_up; then sudo /etc/init.d/apache2 stop || true; fi
  if pg_up; then sudo pg_ctlcluster 18 main stop || true; fi
  if pgrep -f 'ollama serve' >/dev/null 2>&1; then pkill -f 'ollama serve' || true; fi
  if sshd_up; then sudo pkill -x sshd || true; fi
  echo "Servicios detenidos."
}

status() {
  if pg_up; then
    echo "PostgreSQL :5432  OK  ($(pg_isready -h 127.0.0.1 -p 5432))"
  else
    echo "PostgreSQL :5432  CAÍDO"
  fi
  if apache_up; then
    echo "Apache     :8080  OK"
  else
    echo "Apache     :8080  CAÍDO"
  fi
  if ollama_up; then
    echo "Ollama     :11434 OK  ($(curl -fsS --max-time 2 http://127.0.0.1:11434/api/version))"
  else
    echo "Ollama     :11434 CAÍDO"
  fi
  if sshd_up; then
    echo "sshd       :2222  OK"
  else
    echo "sshd       :2222  CAÍDO"
  fi
}

case "${1:-start}" in
  start)
    start_postgres
    start_apache
    start_ollama
    start_sshd
    ;;
  stop)
    stop_all
    ;;
  restart)
    stop_all
    sleep 1
    "${BASH_SOURCE[0]}" start
    ;;
  status)
    status
    ;;
  *)
    echo "Uso: $(basename "$0") {start|stop|restart|status}" >&2
    exit 1
    ;;
esac
