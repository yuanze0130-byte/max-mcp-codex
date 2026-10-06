$ErrorActionPreference = "Stop"

$root = (Resolve-Path $PSScriptRoot).Path
$venv = Join-Path $root ".venv"
$python = Join-Path $venv "Scripts\python.exe"
$codexDir = Join-Path $root ".codex"
$log = Join-Path $codexDir "install.log"
$marker = Join-Path $venv ".max_mcp_codex_installed"

New-Item -ItemType Directory -Force -Path $codexDir | Out-Null

if (-not (Test-Path $python)) {
    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $pyLauncher) {
        # Use the newest installed Python 3.x. pyproject.toml enforces >=3.10.
        & $pyLauncher.Source -3 -m venv $venv 1>> $log 2>&1
    }
    else {
        $pythonLauncher = Get-Command python -ErrorAction SilentlyContinue
        if ($null -eq $pythonLauncher) {
            [Console]::Error.WriteLine("Python 3.10 or newer is required. Install Python, then reopen this Codex project.")
            exit 1
        }
        & $pythonLauncher.Source -m venv $venv 1>> $log 2>&1
    }
}

if (-not (Test-Path $python)) {
    [Console]::Error.WriteLine("Could not create the Python virtual environment. See .codex/install.log.")
    exit 1
}

$installed = Test-Path $marker
if ($installed) {
    # A stale marker should not prevent repair after a partial cleanup.
    & $python -c "import max_mcp_codex" 1>> $log 2>&1
    if ($LASTEXITCODE -ne 0) {
        $installed = $false
    }
}

if (-not $installed) {
    & $python -m pip install --disable-pip-version-check -e $root 1>> $log 2>&1
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("MCP installation failed. See .codex/install.log.")
        exit $LASTEXITCODE
    }
    New-Item -ItemType File -Force -Path $marker | Out-Null
}

& $python -m max_mcp_codex.server
exit $LASTEXITCODE
