# Install CoC_Bot from source on Windows. Non-interactive - safe for an agent to run.
# Usage:  powershell -ExecutionPolicy Bypass -File install.ps1 -RepoDir C:\CoC_Bot
param(
    [string]$RepoDir = "C:\CoC_Bot",
    [string]$PythonVersion = "3.11",
    [switch]$WithWebApp
)

$ErrorActionPreference = "Stop"

function Say($m) { Write-Host $m -ForegroundColor Cyan }
function Ok($m)  { Write-Host $m -ForegroundColor Green }
function Die($m)  { Write-Host $m -ForegroundColor Red; exit 1 }

Say "=== CoC_Bot installer ==="

if (Test-Path (Join-Path $RepoDir "src\main.py")) {
    Ok "Already cloned at $RepoDir"
} else {
    Say "Cloning https://github.com/m24842/CoC_Bot.git -> $RepoDir"
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die "git not found. Run: winget install Git.Git" }
    git clone https://github.com/m24842/CoC_Bot.git $RepoDir
    if ($LASTEXITCODE -ne 0) { Die "git clone failed" }
}

Set-Location $RepoDir
$gitLog = (git log -1 --format="%h %ad" --date=short)
Say "Upstream commit: $gitLog"

# --- venv -------------------------------------------------------------------
$venvPy = Join-Path $RepoDir ".venv\Scripts\python.exe"
if (Test-Path $venvPy) {
    Ok "venv already exists"
} else {
    Say "Creating venv with py -$PythonVersion"
    & py "-$PythonVersion" -m venv (Join-Path $RepoDir ".venv")
    if ($LASTEXITCODE -ne 0) { Die "venv creation failed. Is Python $PythonVersion installed? Run: winget install Python.Python.$($PythonVersion.Replace('.',''))" }
    Ok "venv created"
}

& $venvPy --version
$verCheck = & $venvPy -c "import sys; print(sys.version_info >= (3,11))"
if ($verCheck.Trim() -ne "True") { Die "Python >= 3.11 required (setup.py asserts this)" }
Ok "Python version OK"

# --- deps -------------------------------------------------------------------
Say "Upgrading pip (this takes a minute)"
& $venvPy -m pip install -U pip setuptools wheel --quiet

Say "Installing bot dependencies - torch/easyocr pull ~2.5 GB, expect 10-20 min"
& $venvPy -m pip install -r (Join-Path $RepoDir "src\requirements.txt")
if ($LASTEXITCODE -ne 0) { Die "pip install of src\requirements.txt failed" }
Ok "Bot dependencies installed"

if ($WithWebApp) {
    Say "Installing web app dependencies"
    & $venvPy -m pip install -r (Join-Path $RepoDir "app\requirements.txt")
    if ($LASTEXITCODE -ne 0) { Die "pip install of app\requirements.txt failed" }
    Ok "Web app dependencies installed"
}

# --- configs ----------------------------------------------------------------
$cfg = Join-Path $RepoDir "src\configs.py"
if (Test-Path $cfg) {
    Ok "src\configs.py already exists - left untouched"
} else {
    Copy-Item (Join-Path $RepoDir "src\configs.template.py") $cfg
    Ok "Created src\configs.py from template"
}

# --- report -----------------------------------------------------------------
Say ""
Say "=== Installation complete ==="
Ok "Repo    : $RepoDir"
Ok "Python  : $venvPy"
Ok "Configs : $cfg"
Say ""
Say "NEXT:"
Say "  1. Edit src\configs.py - see README.md section 6"
Say "  2. Configure BlueStacks: ADB on, 1920x1080, 60 FPS, instance named 'main' - README section 4"
Say "  3. Log your THROWAWAY account into the emulator"
Say "  4. Run: powershell -ExecutionPolicy Bypass -File verify.ps1 -RepoDir $RepoDir"
Say "  5. Then: $venvPy src\main.py"
