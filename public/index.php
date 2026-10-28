<?php
declare(strict_types=1);

/**
 * Página de bienvenida / estado del entorno de desarrollo.
 * Solo para uso local dentro del contenedor.
 */

function run(string $command): string
{
    if (!function_exists('shell_exec')) {
        return 'shell_exec deshabilitado';
    }
    $output = @shell_exec($command . ' 2>&1');
    return trim((string) $output);
}

function firstLine(string $text): string
{
    $line = strtok($text, "\n");
    return $line === false ? $text : $line;
}

function portOpen(string $host, int $port, float $timeout = 0.5): bool
{
    $socket = @fsockopen($host, $port, $errno, $errstr, $timeout);
    if ($socket === false) {
        return false;
    }
    fclose($socket);
    return true;
}

function httpOk(string $url): bool
{
    $context = stream_context_create([
        'http' => ['timeout' => 1.0, 'ignore_errors' => true],
    ]);
    return @file_get_contents($url, false, $context) !== false;
}

$tools = [
    'Sistema'     => trim(run('grep PRETTY_NAME /etc/os-release | cut -d= -f2- | tr -d \'"\'')),
    'Python'      => firstLine(run('python3 --version')),
    'uv'          => firstLine(run('uv --version')),
    'ruff'        => firstLine(run('ruff --version')),
    'Node.js'     => firstLine(run('node --version')),
    'npm'         => firstLine(run('npm --version')),
    'fnm'         => firstLine(run('fnm --version')),
    'bun'         => firstLine(run('bun --version')),
    'OpenCode'    => firstLine(run('opencode --version')),
    'PHP'         => PHP_VERSION . ' (' . PHP_SAPI . ')',
    'Composer'    => firstLine(run('composer --version --no-ansi')),
    'Apache'      => firstLine(run('apache2 -v')),
    'PostgreSQL'  => firstLine(run('psql --version')),
    'Ollama'      => firstLine(run('ollama --version')),
];

$services = [
    'Apache (:8080)'   => httpOk('http://127.0.0.1:8080/health.txt'),
    'PostgreSQL (:5432)' => portOpen('127.0.0.1', 5432),
    'Ollama (:11434)'  => httpOk('http://127.0.0.1:11434/api/version'),
    'sshd (:2222)'     => portOpen('127.0.0.1', 2222),
];

$extensions = ['pdo_pgsql', 'pgsql', 'mbstring', 'curl', 'gd', 'intl', 'zip', 'opcache'];
$dbInfo = run('psql -h 127.0.0.1 -U dev -d dev -tAc "select version();"');
$dbReady = portOpen('127.0.0.1', 5432);

?><!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>IOperaciones · entorno de desarrollo</title>
<style>
    :root {
        color-scheme: dark;
        --bg: #0e1116;
        --panel: #161b22;
        --border: #30363d;
        --text: #e6edf3;
        --muted: #8b949e;
        --accent: #58a6ff;
        --ok: #3fb950;
        --bad: #f85149;
    }
    * { box-sizing: border-box; }
    body {
        margin: 0;
        padding: 2.5rem 1.25rem 4rem;
        background: radial-gradient(1200px 500px at 20% -10%, #1f6feb22, transparent), var(--bg);
        color: var(--text);
        font-family: ui-sans-serif, system-ui, -apple-system, "Segoe UI", sans-serif;
        line-height: 1.5;
    }
    main { max-width: 1040px; margin: 0 auto; }
    h1 { margin: 0 0 .25rem; font-size: 1.9rem; letter-spacing: -.02em; }
    h1 span { color: var(--accent); }
    .subtitle { margin: 0 0 2rem; color: var(--muted); }
    h2 {
        margin: 2rem 0 .75rem;
        font-size: .8rem;
        text-transform: uppercase;
        letter-spacing: .12em;
        color: var(--muted);
    }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: .75rem; }
    .card {
        background: var(--panel);
        border: 1px solid var(--border);
        border-radius: 10px;
        padding: .8rem .95rem;
    }
    .card .label { font-size: .78rem; color: var(--muted); }
    .card .value { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .92rem; overflow-wrap: anywhere; }
    .status { display: flex; align-items: center; gap: .5rem; }
    .dot { width: .6rem; height: .6rem; border-radius: 50%; display: inline-block; }
    .dot.ok { background: var(--ok); box-shadow: 0 0 8px #3fb95088; }
    .dot.bad { background: var(--bad); box-shadow: 0 0 8px #f8514988; }
    .ok-text { color: var(--ok); }
    .bad-text { color: var(--bad); }
    code, pre {
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
        background: #0b0f14;
        border: 1px solid var(--border);
        border-radius: 8px;
    }
    code { padding: .1rem .35rem; font-size: .85rem; }
    pre { padding: .9rem 1rem; overflow-x: auto; font-size: .82rem; color: var(--muted); }
    .note {
        margin-top: 2rem;
        padding: .9rem 1rem;
        border: 1px dashed var(--border);
        border-radius: 10px;
        color: var(--muted);
        font-size: .88rem;
    }
    a { color: var(--accent); }
</style>
</head>
<body>
<main>
    <h1>IOperaciones <span>· entorno de desarrollo</span></h1>
    <p class="subtitle">Apache + PHP funcionando correctamente. Todo el stack vive en un único contenedor DevPod.</p>

    <h2>Servicios</h2>
    <div class="grid">
        <?php foreach ($services as $name => $up): ?>
            <div class="card">
                <div class="label"><?= htmlspecialchars($name, ENT_QUOTES, 'UTF-8') ?></div>
                <div class="status">
                    <span class="dot <?= $up ? 'ok' : 'bad' ?>"></span>
                    <span class="<?= $up ? 'ok-text' : 'bad-text' ?>"><?= $up ? 'en marcha' : 'caído' ?></span>
                </div>
            </div>
        <?php endforeach; ?>
    </div>

    <h2>Herramientas</h2>
    <div class="grid">
        <?php foreach ($tools as $name => $version): ?>
            <div class="card">
                <div class="label"><?= htmlspecialchars($name, ENT_QUOTES, 'UTF-8') ?></div>
                <div class="value"><?= htmlspecialchars($version !== '' ? $version : 'no disponible', ENT_QUOTES, 'UTF-8') ?></div>
            </div>
        <?php endforeach; ?>
    </div>

    <h2>PHP</h2>
    <div class="grid">
        <?php foreach ($extensions as $extension): ?>
            <div class="card">
                <div class="label">ext/<?= htmlspecialchars($extension, ENT_QUOTES, 'UTF-8') ?></div>
                <div class="status">
                    <?php $loaded = extension_loaded($extension); ?>
                    <span class="dot <?= $loaded ? 'ok' : 'bad' ?>"></span>
                    <span class="<?= $loaded ? 'ok-text' : 'bad-text' ?>"><?= $loaded ? 'cargada' : 'no cargada' ?></span>
                </div>
            </div>
        <?php endforeach; ?>
    </div>

    <h2>PostgreSQL</h2>
    <pre><?= htmlspecialchars(
        $dbReady && $dbInfo !== ''
            ? $dbInfo
            : 'Sin conexión. Ejecuta: bash .devcontainer/scripts/services.sh start',
        ENT_QUOTES,
        'UTF-8'
    ) ?></pre>

    <h2>Comandos rápidos</h2>
    <pre>devpod ssh .                                  # entrar al contenedor
bash .devcontainer/scripts/services.sh status  # estado de los servicios
bash .devcontainer/scripts/check-env.sh        # versiones y diagnóstico
psql "$DATABASE_URL"                           # consola de PostgreSQL
ollama run qwen3:4b                            # probar un modelo local
uv init / uv add &lt;paquete&gt;                     # Python con uv
bun install                                    # dependencias Node/bun</pre>

    <div class="note">
        Credenciales de desarrollo: <code>dev</code> / <code>dev</code> · base <code>dev</code>.
        Este panel es solo para desarrollo local; no lo expongas en producción.
    </div>
</main>
</body>
</html>
