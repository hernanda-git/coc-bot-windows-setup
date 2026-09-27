# V0-V5 verification from README.md section 7. Run AFTER install, BEFORE first bot run.
# Any FAIL here means do not start the bot. Go to README.md section 11.
#
# Usage: powershell -ExecutionPolicy Bypass -File verify.ps1 -RepoDir C:\CoC_Bot
param(
    [string]$RepoDir = "C:\CoC_Bot"
)

$ErrorActionPreference = "Continue"
$py = Join-Path $RepoDir ".venv\Scripts\python.exe"
$script:fail = @()
$script:serial = $null
$tmpPy = Join-Path $env:TEMP "coc_bot_vocab_check.py"

function Say($m)  { Write-Host $m -ForegroundColor Cyan }
function Pass($m) { Write-Host "PASS: $m" -ForegroundColor Green }
function FailCheck($m) {
    Write-Host "FAIL: $m" -ForegroundColor Red
    $script:fail += $m
}

Say "Verifying CoC_Bot at $RepoDir"

# The venv must exist before any python-based check can run.
if (-not (Test-Path $py)) {
    Write-Host "VENV MISSING: $py not found. Run install.ps1 first." -ForegroundColor Red
    exit 1
}

# --- V0: the runtime GitHub-API dependency -----------------------------------
# The bot builds a spell-check vocabulary by listing the file tree of
# ClashKingInc/ClashKingAssets over the unauthenticated GitHub API
# (src/utils.py:235-275). No network means no vocabulary means broken
# upgrade matching. Check it up front so the failure is legible.
Say "`n--- V0: vocab source repo reachable (needed at runtime) ---"
@'
import sys
from github import Github
try:
    g = Github(timeout=8, retry=None)
    r = g.get_repo("ClashKingInc/ClashKingAssets")
    tree = r.get_git_tree(r.get_branch(r.default_branch).commit.sha, recursive=True)
    print("vocab entries:", len(tree.tree))
except Exception as e:
    print("VOCAB_ERROR:", type(e).__name__, e)
    sys.exit(1)
'@ | Set-Content -Path $tmpPy -Encoding ASCII

$v0 = & $py $tmpPy 2>&1
$v0 | Out-String | Write-Host
Remove-Item $tmpPy -ErrorAction SilentlyContinue
if ("$v0" -match "vocab entries:\s*[1-9]") { Pass "V0 vocab source reachable" }
else {
    FailCheck "V0"
    Write-Host "  -> the bot needs GitHub API access at runtime to spell-check upgrade names." -ForegroundColor Yellow
    Write-Host "     Behind a proxy, set `$env:HTTPS_PROXY before starting. Unauthenticated rate limit is 60 req/hr." -ForegroundColor Yellow
}

# --- V1: adb sees an authorized device, and pin its serial --------------------
# The bot talks to the emulator as 127.0.0.1:<port> (it reads the per-instance
# adb_port out of bluestacks.conf and calls `adb connect`), so the serial is
# normally 127.0.0.1:NNNN -- not emulator-5554. Accept either form.
# Every later check uses `-s <serial>` so a second attached device cannot break it.
Say "`n--- V1: adb sees an authorized device ---"
if (Get-Command adb -ErrorAction SilentlyContinue) {
    $dev = adb devices 2>&1
    $dev | Out-String | Write-Host
    foreach ($line in $dev) {
        if ("$line" -match '^(\S+)\s+device\s*$') { $script:serial = $Matches[1]; break }
    }
    if ($script:serial) {
        Pass "V1 adb device authorized (serial: $script:serial)"
    } else {
        FailCheck "V1"
        Write-Host "  -> no line matched '<serial>  device'. 'offline'/'unauthorized' means:" -ForegroundColor Yellow
        Write-Host "     enable ADB in the emulator, accept the RSA prompt, then: adb kill-server" -ForegroundColor Yellow
        Write-Host "  -> if the emulator is not running, start BlueStacks once so it writes bluestacks.conf," -ForegroundColor Yellow
        Write-Host "     confirm a device line appears, then stop it and let the bot launch it (AUTO_START_EMULATOR=True)." -ForegroundColor Yellow
    }
} else {
    FailCheck "V1 (adb not found on PATH)"
}

$sh = "adb"
if ($script:serial) { $sh = "adb -s $script:serial" }

# --- V2: adbutils can enumerate and reach a device ----------------------------
# NOTE: the correct API is adbutils.adb.device_list(). There is no device_iter()
# in adbutils -- that name appears in StackOverflow answers for other libraries
# and raises AttributeError: 'AdbClient' object has no attribute 'device_iter'.
Say "`n--- V2: adbutils enumerates devices ---"
$v2 = & $py -c "import adbutils; print([d.serial for d in adbutils.adb.device_list()])" 2>&1
$v2 | Out-String | Write-Host
# Accept either form: 127.0.0.1:<port> (the bot's own connection, what
# BlueStacks/MuMu give you) or emulator-NNNN (a plain AVD).
if ("$v2" -match 'emulator-\d+|127\.0\.0\.1:\d+') { Pass "V2 adbutils sees a device" }
else { FailCheck "V2" }

# --- V3: Clash of Clans is installed in the emulator --------------------------
Say "`n--- V3: CoC installed in emulator ---"
$v3 = Invoke-Expression "$sh shell pm list packages" 2>&1 | Select-String "clashofclans"
if ($v3) { Pass "V3 com.supercell.clashofclans present" }
else {
    FailCheck "V3"
    Write-Host "  -> install Clash of Clans from Google Play INSIDE the emulator (not a sideloaded APK)" -ForegroundColor Yellow
}

# --- V4: emulator is at 1920x1080 ---------------------------------------------
# An Override size wins over Physical size when present, and a stale override is
# a real failure mode -- it silently desyncs every template match.
Say "`n--- V4: emulator resolution ---"
$v4 = Invoke-Expression "$sh shell wm size" 2>&1
$v4 | Out-String | Write-Host
$override = "$v4" | Select-String "Override size"
if ($override) {
    if ("$override" -match '(\d+)x(\d+)' -and $Matches[1] -eq "1920" -and $Matches[2] -eq "1080") {
        Pass "V4 Override size 1920x1080"
    } else {
        FailCheck "V4 (Override size set and is NOT 1920x1080)"
        Write-Host "  -> remove the override: $sh shell wm size reset" -ForegroundColor Yellow
    }
} elseif ("$v4" -match 'Physical size:\s*1920x1080') {
    Pass "V4 Physical size 1920x1080"
} else {
    FailCheck "V4 (emulator is not 1920x1080)"
    Write-Host "  -> set resolution to exactly 1920x1080 at 60 FPS in the emulator settings" -ForegroundColor Yellow
}

# --- V5: imports resolve inside the venv -------------------------------------
Say "`n--- V5: imports resolve ---"
$v5 = & $py -c "import cv2, easyocr, uiautomator2, adbutils, loguru; print('imports OK')" 2>&1
if ("$v5" -match "imports OK") { Pass "V5 imports resolve" }
else {
    $v5 | Out-String | Write-Host
    FailCheck "V5"
    Write-Host "  -> re-run install.ps1, or: $py -m pip install -r $RepoDir\src\requirements.txt" -ForegroundColor Yellow
}

# --- result -------------------------------------------------------------------
Say "`n=== RESULT ==="
if ($script:fail.Count -eq 0) {
    Write-Host "ALL 6 CHECKS PASS - safe to run:" -ForegroundColor Green
    Write-Host "  $py $RepoDir\src\main.py" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILED: $($script:fail -join ', ')" -ForegroundColor Red
    Write-Host "DO NOT start the bot. See README.md section 11 Troubleshooting." -ForegroundColor Red
    exit 1
}
