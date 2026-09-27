# CoC_Bot — Windows Setup Guide (agent-executable)

Setup documentation for **[m24842/CoC_Bot](https://github.com/m24842/CoC_Bot)** on a **Windows 11 laptop**.

This repo exists so an AI agent (Hermes on IT26) can read one file and set the bot up end-to-end without further questions. Every command below is copy-pasteable PowerShell. Every decision that requires human input is marked with a `[[NEEDS INPUT]]` gate and has a documented default.

## Read this first

> [!IMPORTANT]
> **This violates Supercell's Terms of Service.** Supercell runs recurring ban waves and permanently bans accounts using third-party software — that is their published policy, not a rumour. Use a **throwaway account** you can afford to lose. Do not attach this to a valuable account, a purchased account, or an account with a meaningful war league record.
>
> Source: <https://supercell.com/en/games/clashofclans/blog/misc/update-to-our-fair-play-policy-and-next-steps>

**Target: `m24842/CoC_Bot`** — most feature-complete open-source CoC bot (35★, last commit Sep 2026). Chosen over `alisakkaf/Clash-of-Clans-Bot-Auto-Farmer` because it has web-app control, Telegram notifications, multi-account, and automatic emulator lifecycle management.

**Reference:** <https://github.com/m24842/CoC_Bot> · Releases: <https://github.com/m24842/CoC_Bot/releases/latest>

---

## TL;DR — the whole setup

```powershell
# 0. From an ELEVATED PowerShell (Run as Administrator):
winget install Google.PlatformTools
winget install BlueStacks.BlueStacks5
adb --version                       # verify

# 1. Configure BlueStacks: ADB on, 1920x1080, 60 FPS, instance named "main"
# 2. Then:
git clone https://github.com/m24842/CoC_Bot.git
cd CoC_Bot
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -U pip
.\.venv\Scripts\python.exe -m pip install -r src\requirements.txt
Copy-Item src\configs.template.py src\configs.py
# 3. Edit src\configs.py  (see "Configuration" below)
.\.venv\Scripts\python.exe src\main.py
```

Full detail and the failure modes are below.

---

## 1. Agent contract

An agent reading this file must, in order:

1. Run **§3 Pre-flight** and **§4 prerequisites** automatically. Do not ask the user to click through them; the only things that need a human are the `[[NEEDS INPUT]]` items.
2. Ask the user **once**, up front, for the `[[NEEDS INPUT]]` values, offering the documented default for each.
3. Execute **§5 install**, **§6 configure**, **§7 verify**, **§8 run**.
4. If any verification step in **§7** fails, go to the matching entry in **§11 Troubleshooting**. Do not proceed to §8 on a failed check.
5. Never invent success. If a command's output does not match the expected output quoted in this document, report the actual output and stop.

**Operating system assumption:** Windows 11 x64, admin rights available, laptop with ≥16 GB RAM and an x86 CPU with hardware virtualisation (VT-x/AMD-V) enabled.

---

## 2. Requirements checklist

| Item | Requirement | Notes |
|---|---|---|
| OS | Windows 11 x64 | Windows 10 works; Windows 8 and below do not |
| Python | **3.11** (upstream's only CI-tested version) | `setup.py:7` asserts `sys.version_info >= (3, 11)`, so newer interpreters are not *blocked* — but upstream's release workflow (`.github/workflows/build_release.yml`) builds on 3.11 and nothing else. Use 3.11. |
| Emulator | BlueStacks 5 **or** MuMu Player (MuMu = Windows only) | BlueStacks is the better-tested path |
| Emulator resolution | **1920 × 1080** | Hard requirement. See §4.2 |
| Emulator FPS | **60** | Hard requirement — "Inconsistent touch events at lower fps" (upstream README) |
| Device profile | Samsung Galaxy S22 Ultra | Preset in the emulator |
| ADB | platform-tools on PATH | `winget install Google.PlatformTools` |
| Internet | Required at runtime, not just at install | The bot fetches a word list from `ClashKingInc/ClashKingAssets` on the GitHub API (`src/utils.py:235-275`) to spell-check upgrade names |
| RAM | 16 GB+ | 8 GB works with one instance, painfully |
| Instance name | `main` | Must match `INSTANCE_IDS` in configs |
| Clash of Clans | Installed from Google Play inside the emulator | Default troop deployment size, Standard or XL scenery |

**Disk:** ~10 GB is an estimate, not a measured figure — emulator ~3 GB, clone + `.venv` ~4 GB, prebuilt release ~300 MB. `src/requirements.txt` pins no torch version, so the exact footprint depends on which build your resolver picks. Free more than 10 GB if unsure.

---

## 3. Pre-flight (agent runs this first)

```powershell
# Confirm Windows build and architecture
$PSVersionTable.PSVersion
[System.Environment]::OSVersion.Version
$env:PROCESSOR_ARCHITECTURE

# Virtualisation support (expects True)
(Get-CimInstance Win32_Processor).VirtualizationFirmwareEnabled
(Get-CimInstance Win32_ComputerSystem).HypervisorPresent

# Free disk on C: (needs >= 10 GB)
(Get-PSDrive C).Free / 1GB

# Python launchers available
py -0p
```

**Gate:** if `(Get-CimInstance Win32_Processor).VirtualizationFirmwareEnabled` is `False`, the emulator will not run at usable speed. Stop and tell the user to enable VT-x in BIOS/UEFI. Do not attempt to work around it.

**Gate:** if `py -0p` lists no 3.11/3.12, install it: `winget install Python.Python.3.11` then reopen PowerShell.

---

## 4. Prerequisites

### 4.1 Android platform-tools (ADB)

```powershell
winget install --id Google.PlatformTools -e
# close and reopen PowerShell so PATH updates
adb --version
```

Expected: a line starting `Android Debug Bridge version 1.0.x`. Exact build number varies by platform-tools release; the guide does not pin one.

If `winget` is unavailable, download from <https://developer.android.com/tools/releases/platform-tools>, unzip to `C:\platform-tools`, and add `C:\platform-tools` to PATH.

`src/configs.py` has `ADB_ABS_DIR = ""` — empty means "use system PATH". Set it to the full adb folder only if auto-detection fails.

### 4.2 BlueStacks 5 (recommended)

```powershell
winget install --id BlueStacks.BlueStacks5 -e
```

Then, **in the BlueStacks UI**:

1. **Enable Android Debug Bridge.** Upstream says only "Enable Android Debug Bridge in 'Advanced' settings" and does not name the exact menu path; BlueStacks 5 has moved this toggle between releases. Look under *Settings → Advanced* (or *Settings → Debug bridge*, depending on your BlueStacks build). If you cannot find it, update BlueStacks to the current release and check again.
2. **Settings → Display**:
   - Resolution → **1920 x 1080** (Custom if not listed)
   - DPI → 240
   - **Frame rate → 60 FPS**
3. **Settings → Performance**: allocate RAM, enable **Virtualization-based platform / Hyper-V** if offered.
4. **Device profile → Advanced → Samsung Galaxy S22 Ultra.**
5. **Multi-Instance Manager**: rename the instance to **`main`** (lowercase). This is load-bearing — the bot resolves the emulator's internal instance name by matching `display_name` in `C:\ProgramData\BlueStacks_nxt\bluestacks.conf` against `INSTANCE_IDS`. A mismatch raises:
   `RuntimeError: BlueStacks instance 'main' was not found. Rename the emulator instance to match INSTANCE_IDS.`
6. Install Clash of Clans **from inside Google Play in the emulator** (not a sideloaded APK). The bot launches `com.supercell.clashofclans` and uses its Play Store update path.
7. Leave the emulator running, or set `AUTO_START_EMULATOR = True` (default) and let the bot launch it.

Verify ADB sees the instance:

```powershell
adb devices
```

Expected: one line with state `device` — typically `127.0.0.1:5555` (not `emulator-5554`). The bot reads the per-instance `adb_port` out of `C:\ProgramData\BlueStacks_nxt\bluestacks.conf` and calls `adb connect 127.0.0.1:<port>` itself (`src/utils.py:1372-1397`), so **do not assume 5555** — with several instances running, BlueStacks assigns 5555, 5557, 5559, … and the bot will pick up whatever its named instance was given.

If the emulator is not running, the bot starts it itself (`AUTO_START_EMULATOR = True`) — so `adb devices` can legitimately be empty before the first bot run. In that case start BlueStacks manually once, confirm the device line appears, then stop it and let the bot take over.

**Which adb binary the bot uses:** on Windows it prefers the bundled `C:\Program Files\BlueStacks_nxt\HD-Adb.exe` — but **only when `EMULATOR_TYPE = "bluestacks"`** (`src/utils.py:1380-1382`). With `EMULATOR_TYPE = "mumu"` it falls back to whatever `adb` is on PATH. If neither is found it raises `FileNotFoundError("ADB executable not found. Set ADB_ABS_DIR to its directory.")`.

### 4.3 MuMu Player (alternative, Windows only)

```powershell
# no winget package — download from https://www.mumuplayer.com/
```

- MuMu instance display name must also be `main`.
- MuMu is driven through `MuMuManager.exe`. Auto-detected at
  `C:\Program Files\Netease\MuMuPlayer\nx_main\MuMuManager.exe`; if it lives elsewhere set `MUMU_BIN_PATH` in `src/configs.py`.
- Set `EMULATOR_TYPE = "mumu"`.
- The bot runs `MuMuManager.exe info --vmindex all`, walks the returned JSON, and finds the entry whose `name` field equals your bot instance ID — that entry's `index` is the vmindex it drives. So the MuMu instance **name** must match `INSTANCE_IDS`; the vmindex is derived from the name, not the other way round.

### 4.4 Emulator settings — non-negotiable

The bot matches UI elements by screenshot template matching. Wrong resolution or FPS and template matches fail silently or touch the wrong pixel.

```
Resolution      1920 x 1080      (exact)
Frame rate      60               (exact)
Device profile  Samsung Galaxy S22 Ultra
```

---

## 5. Install the bot

```powershell
git clone https://github.com/m24842/CoC_Bot.git
cd CoC_Bot

# 3.11 recommended
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -U pip setuptools wheel

# Bot dependencies (torch/easyocr pull ~2.5 GB — expect 10-20 min)
.\.venv\Scripts\python.exe -m pip install -r src\requirements.txt

# Only if you want the web app / Flask server
.\.venv\Scripts\python.exe -m pip install -r app\requirements.txt

Copy-Item src\configs.template.py src\configs.py
```

Expected: `configs.py` exists at `CoC_Bot\src\configs.py`, and `.venv\Scripts\python.exe` exists.

> **Note:** upstream's `setup.py` does the same thing but prompts interactively (`Install bot dependencies? (y/n)`), which blocks an unattended agent. Installing from the two `requirements.txt` files directly is the non-interactive equivalent. `setup.py` also writes `scripts/start.sh` (a tmux wrapper) — macOS/Linux only, irrelevant here.

> **OCR speed:** local OCR uses EasyOCR on CPU and is slow. For a laptop, get a free Groq key at <https://console.groq.com> and set `GROQ_API_KEY` in configs — it offloads OCR and falls back to local when rate-limited.

### 5.1 Alternative: prebuilt release (not recommended for automation)

```powershell
# v0.1.0, 2026-07-08 — 288 MB, Windows GUI variant
Invoke-WebRequest -Uri "https://github.com/m24842/CoC_Bot/releases/download/v0.1.0/CoC_Bot-v0.1.0-win-gui.zip" -OutFile CoC_Bot.zip
Expand-Archive CoC_Bot.zip -DestinationPath CoC_Bot-prebuilt
```

Upstream explicitly warns: "Prebuilt releases generally will not have the most up-to-date features and may contain unpatched bugs." Only release is `v0.1.0` from July 2026 while the repo has commits through September 2026. **Prefer running from source.**

---

## 6. Configure `src/configs.py`

### 6.1 `[[NEEDS INPUT]]` — ask the user these

| Variable | Default | Question to ask |
|---|---|---|
| `TELEGRAM_BOT_TOKEN` | `""` (off) | "Want Telegram notifications? If yes, create a bot via @BotFather, send it `/start`, and paste the token." |
| `GROQ_API_KEY` | `""` (local OCR) | "Want a free Groq key to speed up OCR? Optional but strongly recommended on a laptop." |
| `WEB_APP_URL` | `""` (off) | "Want remote control via web app? If yes, give the host:port it will be reachable at, e.g. `192.168.1.50:1234` (scheme optional — the code does a bare `f"{WEB_APP_URL}/instances"` POST)." |
| `PA_USERNAME` / `PA_PASSWORD` | `""` | Only if `WEB_APP_URL` contains `pythonanywhere.com`. Leave empty otherwise. |
| Attack aggressiveness | template | See §6.3. |
| Throwaway account login | — | "Which throwaway account should be loaded into the emulator? Log in manually in the emulator GUI first, then confirm." |

### 6.2 Minimum working config

The template is already runnable — the only settings that usually need changing:

```python
# src/configs.py
WEB_APP_URL = ""                    # leave "" for a purely local setup
TELEGRAM_BOT_TOKEN = ""             # paste token if wanted
GROQ_API_KEY = ""                   # paste key if wanted

INSTANCE_IDS = ["main"]             # must match emulator instance display name
DEFAULT_INSTANCE_ID = INSTANCE_IDS[0]

LOCAL_GUI = True                    # desktop GUI window; set False for headless
CHECK_INTERVAL = 5                  # minutes between check cycles

EMULATOR_TYPE = "bluestacks"        # or "mumu"
AUTO_START_EMULATOR = True          # bot launches/closes the emulator itself
WINDOW_DIMS = (1920, 1080)          # must match emulator
DISABLE_DEVICE_SLEEP = True         # keeps the laptop awake
DEBUG = False                       # set True on first run to see what's happening
```

### 6.3 Behaviour flags worth deciding

```python
MAX_UPGRADES_PER_CHECK = 10        # home + builder base per cycle
OPEN_HOME_BUILDERS = 0              # 0 = use every builder
OPEN_BUILDER_BUILDERS = 0
START_FROM_MENU_TOP = True

UPGRADE_HEROES = True
UPGRADE_HOME_BASE = True
UPGRADE_HOME_LAB = True
ASSIGN_LAB_ASSISTANT = True
ASSIGN_BUILDER_APPRENTICE = True
ATTACK_HOME_BASE = True
ATTACK_BUILDER_BASE = True

PRIORITY_HOME_BASE_UPGRADES = True  # honour the priority lists below
PRIORITY_HOME_LAB_UPGRADES = True
PRIORITY_BUILDER_BASE_UPGRADES = True
PRIORITY_BUILDER_LAB_UPGRADES = True
```

**Attack settings:**

```python
TROOP_DEPLOY_TIME = 2               # seconds between troop drops — LOWER = riskier to the defender's base, i.e. better loot
ATTACK_SLOT_RANGE = (0, 100)        # inclusive, 0-indexed from the left
EXCLUDE_CLAN_TROOPS = True          # skip targets in your own clan
```

> [!WARNING]
> The priority lists (`HOME_BASE_UPGRADE_PRIORITY`, etc.) must match in-game text **exactly** — capitalisation and spacing. `Blacksmith` is correct; `blacksmith` or `Black Smith` will never match and that row is silently skipped. A typo does not raise; it just degrades to random upgrades. `Dragon Duke` only exists for accounts that have unlocked it.

**`TROOP_DEPLOY_TIME` and ban risk:** a fixed 2-second cadence with identical troop order every attack is exactly the behavioural signature Supercell looks for. Raising it to 4-6 makes the pattern less machine-like at a small loot cost. This is a judgement call, not a guarantee.

### 6.4 Multi-account

Create extra BlueStacks/MuMu instances, rename each to the desired id, log in a different account in each, then:

```python
INSTANCE_IDS = ["main", "alt2", "alt3"]
```

Run one per instance:

```powershell
.\.venv\Scripts\python.exe src\main.py --id alt2
```

---

## 7. Verify before declaring success

Run these in order. **Do not proceed to §8 until all six pass.**

```powershell
# V0 — the bot's runtime vocabulary fetch works (needs internet)
.\.venv\Scripts\python.exe -c "from github import Github; g=Github(timeout=8,retry=None); r=g.get_repo('ClashKingInc/ClashKingAssets'); t=r.get_git_tree(r.get_branch(r.default_branch).commit.sha, recursive=True); print('vocab entries:', len(t.tree))"
# PASS: vocab entries: <some positive number>

# V1 — ADB sees the emulator
adb devices
# PASS: a line reading "<serial>  device" (usually 127.0.0.1:5555)

# V2 — adbutils can reach it
.\.venv\Scripts\python.exe -c "import adbutils; print([d.serial for d in adbutils.adb.device_list()])"
# PASS: a list containing 127.0.0.1:5555 or emulator-5554
# NOTE: the method is device_list(), NOT device_iter() — that name does not exist
# in adbutils and raises AttributeError. Verified against adbutils 2.12.0.

# V3 — Clash of Clans is installed in the emulator
adb shell pm list packages | Select-String clashofclans
# PASS: package:com.supercell.clashofclans

# V4 — emulator geometry (proves the bot's templates can match)
adb shell wm size
# PASS: Physical size: 1920x1080   (and NO "Override size" line)

# V5 — imports resolve inside the venv
.\.venv\Scripts\python.exe -c "import cv2, easyocr, uiautomator2, adbutils, loguru; print('imports OK')"
# PASS: imports OK
```

`scripts\verify.ps1` runs all six with fail-closed exit codes. Three details it handles that a hand-typed session usually gets wrong:

- **Checks V0 first.** The bot hits the GitHub API at runtime to build a spell-check vocabulary. No internet → no vocabulary → upgrade names never match → silent, confusing failures much later.
- **Pins `-s <serial>`** on V3/V4 once V1 finds a device, so a second attached device cannot make `adb shell` return `more than one device`.
- **Treats an `Override size:` line as a failure** if it is not 1920x1080. A leftover `wm size` override silently desyncs every template match and is invisible in the emulator settings UI.

**Resolution mismatch is the #1 cause of "the bot does nothing".** If V4 is not `1920x1080`, fix the emulator before continuing.

---

## 8. Run

```powershell
# GUI mode (default, LOCAL_GUI = True) — desktop window appears
.\.venv\Scripts\python.exe src\main.py

# Named instance
.\.venv\Scripts\python.exe src\main.py --id main

# Debug — verbose logging, use this for any first-run diagnosis
.\.venv\Scripts\python.exe src\main.py --debug
```

> [!IMPORTANT]
> **There is no `--no-gui` flag.** The accepted flags are `--debug`, `--id`, `--gui`, `--gui-port` (`src/utils.py:33-36`), and `--gui` is a `store_true` whose *default* comes from `LOCAL_GUI` — so it can only turn the GUI **on**, never off. To run headless, set `LOCAL_GUI = False` in `src/configs.py`; the desktop window will not appear and the bot runs in the console.
>
> `--gui-port` is accepted but is a **no-op**: `src/launch.py:33` overwrites it with the port the GUI actually bound (`args.gui_port = get_gui().server_port`). The GUI picks a free port itself. Don't pass it.

**Logs:** the log path is derived from the module's own location, not your shell's working directory — `src/utils.py:19-24` sets `DEBUG_DIR = Path(__file__).parent.parent / "debug"`, i.e. `C:\CoC_Bot\debug\` when you cloned to `C:\CoC_Bot`. One log per instance, `main.log` by default. 10 MB rotation, 5 files kept, zipped. `DEBUG = True` in configs is the equivalent of `--debug`.

> `src/log.py:13-14` also defines a `LOG_DIR`, but `utils.py` overrides it — trust the path above, not `log.py`.

**First run behaviour:** the bot starts the emulator, launches CoC, then enters this loop (`src/coc_bot.py:14-58`), repeating every `CHECK_INTERVAL` minutes:

```
start_coc (auto-updates CoC from the Play Store first)
  → to_home_base
  → upgrader.run_home_base:  building upgrades (up to MAX_UPGRADES_PER_CHECK)
                             → builder apprentice → lab upgrade → lab assistant
  → attacker.run_home_base:  normal multiplayer attack
  → to_builder_base
  → collect_builder_attack_elixir   ← the only resource collection in the cycle
  → upgrader.run_builder_base: building upgrades → star lab
  → attacker.run_builder_base: builder base attack
  → to_home_base → stop_coc(sleep=True) → sleep CHECK_INTERVAL
```

**Correction worth knowing:** upstream's feature list advertises "Resource collection 💰", but the only collection routine in the code is `collect_builder_attack_elixir` (the elixir the builder base attack gave you). Gold, elixir and dark elixir from the home village are **not** collected by a standalone collector — home-base collection only happens incidentally as a side effect of the upgrade loop, which reads the builder count. Do not expect a dedicated "collect everything" pass.

**Emulator window can be minimised** — all interaction is via ADB, not screen scraping of the host desktop.

### 8.1 Web app (optional)

```powershell
.\.venv\Scripts\python.exe app\app.py    # serves on 0.0.0.0:1234
```

> [!CAUTION]
> `app/app.py:209` hardcodes `app.run(host="0.0.0.0", port=1234, debug=True)`. **`debug=True` is not overridable from configs** — the Flask/Werkzeug interactive debugger is on, which accepts arbitrary Python on an unauthenticated port. That is a remote-code-execution surface, not just a status page.
>
> To use the web app safely, edit `app/app.py:209` to `app.run(host="127.0.0.1", port=1234, debug=False)` before running it, and reach it only from the LAN via an SSH/port-forward, or put it behind a reverse proxy with authentication. If you cannot do that, leave `WEB_APP_URL = ""` and use the desktop GUI or Telegram instead.

Set `WEB_APP_URL = "http://<host>:1234"` in configs so instances register. Then set `PA_USERNAME`/`PA_PASSWORD` and the bot auto-extends PythonAnywhere hosting daily if you host it there.

For LAN-only access, add a Windows Firewall rule:

```powershell
New-NetFirewallRule -DisplayName "CoC Bot Web" -Direction Inbound -LocalPort 1234 -Protocol TCP -Action Allow -Profile Private
```

Note the `-Profile Private` — the web app has no authentication of its own.

> [!CAUTION]
> The web app has **no authentication**. `CORS(app)` is wide open. Anyone who reaches it can pause and control your bot. Never expose port 1234 to the internet.

### 8.2 Telegram notifications

1. Create a bot with @BotFather → get `TELEGRAM_BOT_TOKEN`.
2. **Send `/start` to your bot first** (upstream note — the bot cannot message you until you have).
3. Paste the token into `TELEGRAM_BOT_TOKEN`.

### 8.3 Run at startup (optional)

```powershell
# Run once as Administrator
# Headless is the right default for a scheduled task: no GUI window, no LOCAL_GUI edit needed
# on the command line -- but note --no-gui does NOT exist. Headless = LOCAL_GUI = False in configs.py.
$action = New-ScheduledTaskAction -Execute "C:\path\to\CoC_Bot\.venv\Scripts\python.exe" `
  -Argument "C:\path\to\CoC_Bot\src\main.py" -WorkingDirectory "C:\path\to\CoC_Bot"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "CoC Bot" -Action $action -Trigger $trigger `
  -Description "CoC_Bot runner" -RunLevel Highest
```

**For this to run headless you must first set `LOCAL_GUI = False` in `src/configs.py`** — there is no command-line switch for it. Leave `LOCAL_GUI = True` if you want the window.

---

## 9. Optional: iPhone shortcut

Only relevant with the web app. Download Scriptable (<https://apps.apple.com/us/app/scriptable/id1405459188>), create a script named "CoC Bot Script" from `shortcut/CoC_Bot_Script.js`, open `shortcut/CoC Bot Auto Pause.shortcut`, set `WEB_APP_URL` in the Dictionary and add instance ids to `ids`, then create an iOS Automation that runs it when CoC opens.

> Upstream's own README links `shortcut/Scriptable.js`, which does not exist. The real filename is `shortcut/CoC_Bot_Script.js`. Use the real one.
>
> A non-Scriptable variant also exists: `shortcut/CoC Bot Auto Pause Old.shortcut`. It cannot handle request errors.

> iOS kills long-running shortcuts after ~30-60 min. Set the shortcut to "Run After Confirmation" so the pause duration is set through the web app instead.

---

## 10. What this bot does and does not do

**Does:** building and lab upgrades with priority control (home + builder base), builder-apprentice and lab-assistant assignment, normal multiplayer attacks on both villages, multi-account, web-app and Telegram remote control, automatic CoC app update via the Play Store, automatic emulator launch/shutdown. The only resource collection is builder-base elixir from the attack.

**Does not:** read or modify game memory, intercept network traffic, inject code, or patch the APK. Everything is OS-level ADB screenshot analysis and touch events. This is why it breaks after game updates — new UI, new pixel positions, template match failures.

**Does not, despite the upstream feature list:** collect home-village gold/elixir/dark elixir. See the cycle diagram in §8.

---

## 11. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `AttributeError: 'AdbClient' object has no attribute 'device_iter'` | Using a StackOverflow snippet instead of the real adbutils API | Use `adbutils.adb.device_list()` — `device_iter` does not exist in adbutils (verified on 2.12.0) |
| `FileNotFoundError: ADB executable not found` | adb not on PATH and the bundled BlueStacks adb not found — note the bundled one is only used when `EMULATOR_TYPE = "bluestacks"` | `winget install Google.PlatformTools`, reopen the shell, or set `ADB_ABS_DIR` to the adb folder |
| `Python 3.11 or higher is required!` | Too old an interpreter | `py -3.11 -m venv .venv` and recreate the venv |
| `BlueStacks instance 'main' was not found` | Instance display name ≠ `INSTANCE_IDS` | Rename in Multi-Instance Manager to exactly `main`, restart BlueStacks |
| `ADB port for BlueStacks instance ... not found` | BlueStacks config not written yet | Launch the instance once in the GUI, then retry |
| `adb devices` shows `offline` | ADB not enabled in emulator, or port conflict | Enable ADB in BlueStacks settings; `adb kill-server`, reopen BlueStacks |
| `unauthorized` | ADB RSA prompt never accepted | Look at the emulator window and accept the fingerprint prompt |
| Bot runs but does nothing | Resolution/FPS mismatch | Verify V4; set exactly 1920x1080 @ 60 FPS |
| Clicks land on the wrong element | Same | Same — also confirm the Samsung Galaxy S22 Ultra profile |
| GUI window won't open | `pywebview` + Edge WebView2 runtime missing | Install "Microsoft Edge WebView2 Runtime" from Microsoft |
| OCR very slow / loop appears stuck | CPU-only EasyOCR | Set `GROQ_API_KEY`, or raise `CHECK_INTERVAL` |
| `MuMuManager.exe not found` | Non-default MuMu path | Set `MUMU_BIN_PATH` in `src/configs.py` |
| Laptop asleep mid-run | Power policy | `DISABLE_DEVICE_SLEEP = True` (default) — it calls `SetThreadExecutionState` |
| Upgrades random despite priority list | Text mismatch in priority list | Fix capitalisation/spacing; compare against in-game text character by character |
| Works, then stops after a game update | Template assets stale | Re-clone upstream, or re-capture the affected templates in `assets/` |

**Log locations:** `C:\CoC_Bot\debug\<instance_id>.log`. The directory is anchored to the repo, not your shell's CWD (`src/utils.py:19-24`: `Path(__file__).parent.parent / "debug"`), so you can launch from anywhere and still find the log. Run with `--debug` for per-step tracing.

```powershell
Get-Content C:\CoC_Bot\debug\main.log -Tail 40
```

---

## 12. Upstream

- **Repo:** <https://github.com/m24842/CoC_Bot>
- **Issues:** <https://github.com/m24842/CoC_Bot/issues>
- **Q&A:** <https://github.com/m24842/CoC_Bot/discussions/categories/q-a>
- **Latest release at time of writing:** `v0.1.0`, 2026-07-08 (Windows GUI/CLI, macOS GUI/CLI)
- **Verified against:** upstream commit `2026-09-14`

## 13. Licence

This documentation repo is MIT-licensed. `m24842/CoC_Bot` carries its own licence — check upstream before redistribution. Automation of online multiplayer games violates Supercell's Terms of Service; that risk is the operator's to accept.
