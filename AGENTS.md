# AGENTS.md — start here

You are an AI agent with shell access to a **Windows 11 laptop** (target: IT26). Your job is to install and run **[m24842/CoC_Bot](https://github.com/m24842/CoC_Bot)**, a Clash of Clans automation bot.

**Read `README.md` in full before executing anything.** It contains the verified install procedure, the emulator configuration steps, the config reference, the verification gates, and a troubleshooting table. Every command in it is PowerShell. Every claim in it was checked against upstream source at commit `2026-09-14`.

## Fast path

```powershell
# 1. Gates (OS, virtualisation, disk, RAM, python, adb, emulator) — exits 1 on failure
powershell -ExecutionPolicy Bypass -File scripts\preflight.ps1

# 2. Install (clone + venv + deps + configs.py) — non-interactive, ~15-25 min
#    Flags: -RepoDir <path>       where to clone (default C:\CoC_Bot)
#           -PythonVersion <ver>  default 3.11; upstream CI only tests 3.11
#           -WithWebApp           also install app\requirements.txt (flask)
powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -RepoDir C:\CoC_Bot -WithWebApp

# 3. Human must now: configure the emulator (README section 4) and edit src\configs.py (section 6)

# 4. Gates (6 checks) — exits 1 on failure, do NOT start the bot if it fails
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -RepoDir C:\CoC_Bot

# 5. Run
C:\CoC_Bot\.venv\Scripts\python.exe C:\CoC_Bot\src\main.py
```

**Web app only:** do not run `app\app.py` as shipped. It hardcodes `host="0.0.0.0"` with `debug=True` (README section 8.1) — an interactive Python debugger on an unauthenticated port. Change that line first, or skip the web app entirely and leave `WEB_APP_URL = ""`.

## Rules

1. **Do not skip step 1 or step 4.** Both exit non-zero on failure. A failed preflight means a missing prerequisite; a failed verify means the bot will misbehave silently.
2. **Do not invent success.** If a command's actual output differs from what README.md says to expect, report the real output verbatim and stop. Do not proceed on a partial result.
3. **Ask once, up front**, for the `[[NEEDS INPUT]]` items in README section 6.1, offering the documented default for each. Do not ask the same question twice.
4. **Two steps genuinely require a human** and cannot be automated: enabling ADB + setting 1920x1080@60 in the BlueStacks GUI, and logging the Clash of Clans account into the emulator. Ask the user to do those, then verify with step 4.
5. **Escalation:** if a check fails, find the matching row in README section 11 Troubleshooting. If nothing matches, report the failing command, its full output, and what you have already ruled out.
6. **The bot needs internet at runtime**, not just at install. It fetches a spell-check vocabulary from `ClashKingInc/ClashKingAssets` via the GitHub API. Verify V0 before blaming anything else for upgrade matching failing.
7. **Use a throwaway account.** The bot violates Supercell's Terms of Service and permanent bans are enforced. Never attach it to a valuable account.
8. **Do not expose the web app to the internet.** Port 1234 has no authentication. LAN or VPN only.

## Non-negotiable emulator settings

If these are wrong the bot does nothing, or touches the wrong pixels. There is no error message — it just fails quietly.

```
Resolution      1920 x 1080   (exact)
Frame rate      60            (exact)
Device profile  Samsung Galaxy S22 Ultra
ADB             enabled
Instance name   main           (must match INSTANCE_IDS in src/configs.py)
```
