# IOperaciones · entorno de desarrollo DevPod

Contenedor de desarrollo reproducible con todo el stack en una sola máquina:

| Herramienta | Versión | Notas |
|---|---|---|
| Debian | 13 (trixie) | Base `mcr.microsoft.com/devcontainers/base` |
| Python | 3.14.x | Gestionado por `uv` (versiones, venv, herramientas) |
| uv | última | `uv python`, `uv add`, `uv tool` |
| Node.js | 24 LTS | Gestionado por **fnm** |
| fnm | 1.39 | Hook `--use-on-cd` |
| bun | 1.4.4 | Global en `/usr/local/bin` |
| OpenCode | 2.2.0 | OpenCode v2 |
| Apache | 2.4 | Sirve `public/` en `:8080` |
| PHP | 8.4 + Composer | Extensiones `pgsql`, `mbstring`, `gd`, `intl`, `zip`, `opcache` |
| PostgreSQL | 18 | Cluster local persistente |
| Ollama | 0.40.12 | CPU |

> Las credenciales de PostgreSQL (`dev`/`dev`) y el acceso sin contraseña con `sudo` son
> **solo para desarrollo local**. No expongas este contenedor a Internet.

## Requisitos

- Docker en el host (probado con Docker 29).
- DevPod CLI (`devpod`) o VS Code con la extensión *Dev Containers*.
- ~6 GB de disco libre para la imagen (Ollama ocupa la mayor parte).

## Inicio rápido

```bash
# Construye y arranca el workspace
devpod up .

# Shell completa dentro del contenedor
devpod ssh .

# Estado del entorno dentro del contenedor
bash .devcontainer/scripts/check-env.sh
```

- Apache + PHP: <http://localhost:8080> (DevPod muestra el puerto reenviado).
- OpenCode: `opencode` dentro del contenedor.
- Con VS Code: `devpod up . --ide vscode` o *Dev Containers: Reopen in Container*.

El primer arranque tarda varios minutos (descarga de Ollama, PostgreSQL y dependencias).
Los siguientes arranques son rápidos.

## Servicios

No hay systemd dentro del contenedor; los servicios se gestionan con un script:

```bash
bash .devcontainer/scripts/services.sh status    # estado
bash .devcontainer/scripts/services.sh start     # arrancar todo
bash .devcontainer/scripts/services.sh stop      # parar todo
bash .devcontainer/scripts/services.sh restart   # reiniciar todo
```

`postStartCommand` los arranca automáticamente cada vez que haces `devpod up`.

| Servicio | Puerto | Acceso |
|---|---|---|
| Apache + PHP | 8080 | `http://localhost:8080` |
| PostgreSQL | 5432 (interno) | `postgresql://dev:dev@localhost:5432/dev` (túnel SSH para el host) |
| Ollama | 11434 | `http://localhost:11434` |
| sshd interno | 2222 | Solo con clave pública (ver abajo) |

Puertos adicionales reenviados para tus apps: `3000` (Node/bun), `5173` (Vite), `8000` (Python).

## SSH

La forma recomendada es el SSH nativo de DevPod (con reenvío de agente):

```bash
devpod ssh .
```

También se instala un `sshd` interno en el puerto **2222**:

1. Copia tu clave pública:

   ```bash
   cp .devcontainer/ssh/authorized_keys.example .devcontainer/ssh/authorized_keys
   # edita el archivo y pega tu clave (ssh-ed25519 AAAA...)
   ```

2. Recrea o reinicia el workspace:

   ```bash
   devpod up . --recreate
   ```

3. Conéctate (el puerto 2222 se reenvía a localhost):

   ```bash
   ssh -p 2222 vscode@localhost
   ```

El `sshd` solo acepta autenticación por clave pública y solo al usuario `vscode`.

## Python (uv)

`python`, `python3` y `python3.14` apuntan al Python gestionado por uv.

```bash
uv init mi-proyecto
uv add fastapi uvicorn
uv run python app.py
uv tool install ruff        # ya viene ruff instalado globalmente
uv python install 3.15      # instala otra versión (opcional)
```

- Fija la versión del proyecto con `.python-version`.
- `uv sync` se ejecuta automáticamente en `postCreate` si existe `pyproject.toml`.
- Caché persistente en el volumen `iop-uv-cache`.

## Node (fnm) y bun

```bash
node --version          # 24.x por defecto
fnm install 22          # instala otra versión
fnm use 22              # úsala en la sesión actual
echo "22" > .node-version   # fíjala en el proyecto (cambio automático)
bun install
bun run dev
```

La versión por defecto se puede cambiar en `devcontainer.json` (`NODE_VERSION`) y
reconstruyendo con `devpod up . --recreate`.

## Apache, PHP y Composer

- DocumentRoot: `/workspaces/ioperaciones/public`
- Configuración del sitio: `.devcontainer/apache/000-default.conf`
- PHP de desarrollo: `.devcontainer/php/99-dev.ini`
- Logs: `/var/log/apache2/error.log` y `access.log`
- Panel de estado: `public/index.php` (`http://localhost:8080`)

```bash
sudo apache2ctl configtest
sudo /etc/init.d/apache2 restart
composer install
php -v
```

El vhost incluye un **proxy reverso de ejemplo** (comentado) hacia `127.0.0.1:3000`
para servir una app Node/bun bajo `/app/`.

## PostgreSQL 18

- Cluster: `18/main`, datos en el volumen `iop-pgdata`.
- Rol/base/contraseña: `dev` / `dev` / `dev` (superusuario, solo desarrollo).
- Configuración: `/etc/postgresql/18/main/`.
- Log: `/var/log/postgresql/postgresql-18-main.log`.

```bash
psql "$DATABASE_URL"
psql -h 127.0.0.1 -U dev -d dev
pg_isready -h 127.0.0.1 -p 5432
sudo pg_lsclusters
```

PostgreSQL escucha en todas las interfaces con autenticación por contraseña para
permitir el reenvío de puertos de DevPod. No lo expongas fuera de tu equipo.

Si quieres usar `psql`/DBeaver desde el host, crea un túnel (el host ya tiene el
puerto 5432 ocupado en este equipo):

```bash
devpod ssh . -L 15432:localhost:5432
# en otra terminal:
psql "postgresql://dev:dev@127.0.0.1:15432/dev"
```

## Ollama

El servidor se arranca con `services.sh` y escucha en `0.0.0.0:11434`; los modelos
se guardan en el volumen `iop-ollama-models`.

```bash
ollama list
ollama pull qwen3:4b
ollama run qwen3:4b
ollama ps
```

- Al ser CPU, usa modelos pequeños/medianos (1B–8B).
- Log: `~/.ollama/ollama.log`.
- No ejecutes `ollama serve` a mano: ya está gestionado (evita duplicados).
- Los runners CUDA/ROCm se eliminaron de la imagen para ahorrar espacio. Si más
  adelante quieres GPU NVIDIA, hay que reinstalar Ollama con soporte GPU y añadir
  `--gpus all` al `runArgs` (requiere `nvidia-container-toolkit` en el host).

## OpenCode

```bash
opencode
opencode auth login     # credenciales de proveedores
opencode --version
```

- Sesiones y credenciales: volumen `iop-opencode-data`.
- Configuración global: volumen `iop-opencode-config`.
- La autenticación sobrevive a reconstrucciones del workspace.
- Documentación: <https://opencode.ai/v2/docs/>

## Persistencia y reconstrucción

| Volumen | Contenido |
|---|---|
| `iop-pgdata` | Datos de PostgreSQL |
| `iop-ollama-models` | Modelos descargados |
| `iop-opencode-data` | Sesiones y credenciales de OpenCode |
| `iop-opencode-config` | Configuración de OpenCode |
| `iop-uv-cache` | Caché de uv |
| `iop-composer-cache` | Caché de Composer |

El resto del home (`~/.bash_history`, paquetes instalados con `apt`, etc.) es
**efímero**: se pierde con `devpod up . --recreate`.

```bash
devpod up . --recreate     # reconstruye la imagen y el contenedor
devpod delete .            # elimina el workspace (los volúmenes persisten)
devpod stop .              # detiene el contenedor
```

Para borrar también los datos (¡destructivo!):

```bash
docker volume rm iop-pgdata iop-ollama-models iop-opencode-data \
  iop-opencode-config iop-uv-cache iop-composer-cache
```

## Cambiar versiones

Edita `build.args` en `.devcontainer/devcontainer.json`:

```json
"args": {
  "PYTHON_VERSION": "3.14",
  "NODE_VERSION": "24",
  "BUN_VERSION": "1.4.4",
  "OPENCODE_VERSION": "2.2.0",
  "OLLAMA_VERSION": "0.40.12"
}
```

y reconstruye:

```bash
devpod up . --recreate
```

## Estructura

```
.devcontainer/
  devcontainer.json
  Dockerfile
  apache/000-default.conf
  php/99-dev.ini
  ssh/authorized_keys.example
  scripts/
    post-create.sh
    post-start.sh
    services.sh
    check-env.sh
public/index.php
.env.example
.gitignore
```

## Problemas frecuentes

**Apache no arranca**

```bash
sudo apache2ctl configtest
sudo tail -n 50 /var/log/apache2/error.log
```

**PostgreSQL no arranca**

```bash
sudo pg_lsclusters
sudo tail -n 50 /var/log/postgresql/postgresql-18-main.log
```

Si el volumen quedó con permisos incorrectos, revisa que `/var/lib/postgresql/18/main`
sea propiedad de `postgres:postgres`.

**Ollama no responde**

```bash
tail -n 50 ~/.ollama/ollama.log
curl http://127.0.0.1:11434/api/version
```

**`postCreate` falló**

Entra con `devpod ssh .` y ejecuta manualmente:

```bash
bash .devcontainer/scripts/post-create.sh
```

**El puerto 8080/5432 está ocupado en el host**

DevPod reenvía los puertos a localhost; si ya están en uso, detén el servicio local
o cambia el puerto en `devcontainer.json` (`forwardPorts`) y en el vhost de Apache.

**Quiero reiniciar todo desde cero**

```bash
devpod up . --recreate
# o, además, borrando datos:
docker volume rm iop-pgdata iop-ollama-models
```

## Seguridad

- Credenciales de PostgreSQL y `sudo` sin contraseña: entorno de desarrollo, no producción.
- Apache sirve el proyecto y muestra un panel con versiones; no lo publiques.
- El `sshd` interno usa solo claves públicas y está limitado al usuario `vscode`.
- No guardes secretos reales en `.env`; usa variables de entorno o `opencode auth login`.
