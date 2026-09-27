# Pre-flight checks. Run this FIRST from an elevated PowerShell.
# Exits non-zero on any hard gate. Read README.md section 3 for what each gate means.

$ErrorActionPreference = "Continue"
$fail = @()

Write-Host "=== OS / Architecture ===" -ForegroundColor Cyan
$PSVersionTable.PSVersion
[System.Environment]::OSVersion.Version
$env:PROCESSOR_ARCHITECTURE

Write-Host "`n=== Virtualisation (must be True) ===" -ForegroundColor Cyan
$vtx = (Get-CimInstance Win32_Processor).VirtualizationFirmwareEnabled
$hyper = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent
"VirtualizationFirmwareEnabled : $vtx"
"HypervisorPresent             : $hyper"
if ($vtx -ne $true) {
    Write-Host "GATE FAIL: VT-x/AMD-V not enabled in BIOS. Emulator will not run." -ForegroundColor Red
    $fail += "virtualization"
}

Write-Host "`n=== Free disk on C: (GB, need >= 10) ===" -ForegroundColor Cyan
$free = [math]::Round((Get-PSDrive C).Free / 1GB, 1)
"Free: $free GB"
if ($free -lt 10) {
    Write-Host "GATE FAIL: less than 10 GB free." -ForegroundColor Red
    $fail += "disk"
}

Write-Host "`n=== RAM (GB) ===" -ForegroundColor Cyan
$ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
"TotalPhysicalMemory: $ram GB"
if ($ram -lt 8) {
    Write-Host "WARN: under 8 GB RAM. One instance will be slow." -ForegroundColor Yellow
}

Write-Host "`n=== Python launchers ===" -ForegroundColor Cyan
try { py -0p } catch { Write-Host "WARN: py launcher not found. Install Python 3.11." -ForegroundColor Yellow }

Write-Host "`n=== adb ===" -ForegroundColor Cyan
if (Get-Command adb -ErrorAction SilentlyContinue) {
    adb --version
} else {
    Write-Host "NOT FOUND. Run: winget install --id Google.PlatformTools -e" -ForegroundColor Yellow
    $fail += "adb"
}

Write-Host "`n=== BlueStacks / MuMu presence ===" -ForegroundColor Cyan
$bs = Test-Path "C:\Program Files\BlueStacks_nxt\HD-Player.exe"
$mumu = Test-Path "C:\Program Files\Netease\MuMuPlayer\nx_main\MuMuManager.exe"
"BlueStacks HD-Player.exe : $bs"
"MuMu MuMuManager.exe      : $mumu"
if (-not ($bs -or $mumu)) {
    Write-Host "NOT FOUND. Run: winget install --id BlueStacks.BlueStacks5 -e" -ForegroundColor Yellow
    $fail += "emulator"
}

Write-Host "`n=== adb devices ===" -ForegroundColor Cyan
if (Get-Command adb -ErrorAction SilentlyContinue) { adb devices }

Write-Host "`n=== RESULT ===" -ForegroundColor Cyan
if ($fail.Count -eq 0) {
    Write-Host "ALL HARD GATES PASS" -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAILED GATES: $($fail -join ', ')" -ForegroundColor Red
    exit 1
}
