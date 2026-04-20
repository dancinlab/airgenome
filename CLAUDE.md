# airgenome — environment notes for Claude Code

## Runtime environment (IMPORTANT)

Claude Code runs inside a **Linux VM**. The Mac host is where the user's tools live (launchctl, Homebrew, GitHub credentials, Xcode, menubar apps, etc.). The Mac home directory is mounted into the VM at `/mac_home/` (= `/Users/ghost/` on the Mac side).

**You cannot SSH to the Mac from the VM.** To run a command on the Mac host, use the file-based bridge:

```
bin/mac_exec 'COMMAND'
```

`bin/mac_exec` writes a request file into `/mac_home/.claude_mac_bridge/req/`, a launchd WatchPaths agent on the Mac (`com.airgenome.mac-bridge`) picks it up, runs the command, and writes the response. Stdout/stderr/exit-code are streamed back to the VM. 5-minute hard timeout per command.

### When to use `mac_exec`

Use it for anything that **must** execute on the Mac host:

- `launchctl` (load / kickstart / bootout launch agents)
- `git push` and `git pull` for this repo (Mac has GitHub credentials; the VM does not)
- `brew`, `open`, `osascript`, `security`, and other macOS-only tools
- Reading/writing files outside `/mac_home/` (e.g., `/private/tmp`, system paths)
- Anything that needs to see Mac-side processes, network interfaces, or daemons

For work that only touches this repo's files, prefer direct VM operations (Read/Edit/Write/Bash) — they're faster.

### Examples

```bash
bin/mac_exec 'cd ~/Dev/airgenome && git push'
bin/mac_exec 'launchctl kickstart -k gui/$(id -u)/com.airgenome.stability'
bin/mac_exec 'launchctl list | grep airgenome'
bin/mac_exec 'tail -20 ~/.airgenome/stability.jsonl'
```

### If the bridge is down

Symptom: `mac_exec: timeout 120s ... (worker not running?)`.

Recovery — ask the user to run this one-liner on the Mac (paste-safe, single line):

```
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.airgenome.mac-bridge.plist 2>/dev/null; launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.airgenome.mac-bridge.plist && echo BRIDGE_UP
```

Source files:
- Linux client: `bin/mac_exec`
- Mac worker: `bin/mac_bridge_worker`
- Plist: `~/Library/LaunchAgents/com.airgenome.mac-bridge.plist`
- Audit log: `~/.claude_mac_bridge/log.jsonl`

## Mac stability monitor

A launchd-managed watchdog (`com.airgenome.stability`, `bin/stability_monitor_loop` + `bin/stability_monitor`) polls system state ~every 0.7s and SIGKILLs runaway processes to prevent kernel panics.

**Protection invariants — never violate** (a 2026-04-18 incident killed live Claude sessions):

- Any process whose `comm` contains `claude` must never be touched.
- Only processes owned by the current user (`uid == $(id -u)`) are candidates.
- System processes (WindowServer, kernel_task, launchd, Finder, coreaudiod, mds*, etc.) and shells (bash, zsh, tmux, ssh) are hard-blacklisted.
- Every kill re-verifies `ps -o comm=` immediately before `kill -KILL`.

When editing `bin/stability_monitor*`, preserve these guards. Never write code where `claude` could appear on the same line as `kill`/`pkill`.

## Shell commands given to the user

If you need the user to paste a command into their terminal, keep it on **one logical line**. No literal newlines, no `\`-continuation — zsh paste breaks mid-arg and executes fragments. If too long, break into separate self-contained fenced snippets.
