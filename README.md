# Agent Nexus

Run [Claude Code](https://docs.anthropic.com/claude-code) on a dedicated
always-on Mac as a fleet of persistent agent sessions: named, schedulable,
self-healing, and controllable from your laptop or phone. A small set of bash
scripts plus a setup guide; no runtime dependencies beyond tmux and Claude
Code itself.

The idea: each project gets its own named tmux session running Claude Code.
Sessions stay alive on the Mac mini regardless of whether your laptop is open. From your laptop, a single
keyboard shortcut (`Cmd+Shift+B`) reconnects to all of them as VS Code editor tabs.

## What it can do

- **Sessions hub** - every Claude session on the machine in one numbered,
  phone-friendly menu: attach, archive, revive, rename, act on several at
  once. Archived sessions stay hidden until you ask.
- **Scheduled tasks** - fire a prompt into any session on a schedule
  ("Sat 08:00", "daily 05:30"). Missed runs catch up within a window you
  set; every run files a one-line report of what it did.
- **Self-healing automation** - managed sessions are relaunched
  automatically if they die (after a reboot too, with boot-restore on),
  resuming the same Claude conversation.
- **Agent bus** - other machines/agents can drop requests into your
  sessions through a shared folder or a locked-down SSH door.
- **Telegram alerts** - a guided 5-minute setup gives you a private bot
  that texts you when something needs a human (logged-out Claude, failed
  heals, runs that never fired) - and, if you want, each run's report.
- **Telegram control** - a second, optional bot you can send commands to:
  `/status`, `/sessions`, `/heal <name>`, `/launch <name>`, `/approve <name>`,
  `/deny <name>`, `/login <name>`, `/code <code>`. It drives the TOOL, never
  free text into a session, and it answers in about a second. That last part
  is the point: it exists for the moment your sessions are down and remote
  control is unreachable, so a slow reply would be useless. It also watches
  for approval dialogs parked in unattended sessions (Chrome's per-site gate,
  an auto-mode pause), texts you the question, and lets you answer it from
  the phone. Set up with `<machine>-nexus setup-telegram-control`.
- **Self-updating** - the menu tells you when a newer version is on GitHub
  and updates itself on request.
- **Health checks** - a doctor command that catches broken paths, dead
  tickers, stale sessions, and split conversations before you hit them.

## Install in 3 steps

You need `tmux` and `claude` (Claude Code) already installed on the Mac. Then, in
**Terminal on the Mac**:

```bash
# 1. Go into the scripts folder (drag the folder onto the Terminal to get its path,
#    then put "cd " in front). Example:
cd ~/Downloads/scripts

# 2. Run the installer and answer its few questions.
bash setup.sh

# 3. Load the new command (or just open a new Terminal window).
source ~/.zshrc
```

That's it. Now run the tool by typing its name (the prefix you chose in step 2,
followed by `-sessions`), e.g. `<machine>-nexus`. If a first-time setup step is
unfamiliar, the **Setup Guide** below walks through everything, including a fresh
Mac from scratch.


> **Scope of this page:** the session-manager basics and the laptop workflow.
> The tool also has three automation layers, not covered here: a **scheduler**
> (fire prompts into a session on a schedule), **managed agent sessions**
> (self-heal + a per-session permission mode + a durable `STATE.md` memory + a
> per-run `/compact`-or-`/clear` reset policy), and an **agent bus** (other machines hand
> off work via a shared queue). For the full feature set see `PITCH.md`; for
> setup of the automation see §4 of the Setup Guide; for how it works see
> `SYSTEM-NOTES.md`. (`PITCH.md` and `SYSTEM-NOTES.md` live at the project root.)

## What's in this repo

```
.
├── README.md                              this file
├── Mac Mini Claude Code Setup Guide.md    the full guide
└── scripts/
    ├── setup.sh                           one-time configuration; safe to re-run
    └── sessions.sh                        single entry point with subcommands:
                                             new         create a session
                                             sync        interactive picker
                                             restore     recreate active sessions in tmux
                                             schedule    timed tasks + install the ticker
                                             managed     managed agent session settings
                                             bus-status  queue + scheduler + heartbeat
                                             doctor      health check
                                             alerts      run reports + alert log
                                             update      pull the latest from GitHub
                                             submit      enqueue an agent-bus request
                                             setup       re-run setup.sh
                                             help        full usage
```

## Quick start

Assuming you already have:

- A Mac mini you can SSH into (Tailscale recommended for remote access)
- VS Code with the **Remote - SSH** extension on your laptop
- `tmux` and `claude` installed on the Mac mini

Then on the Mac mini:

```bash
cd path/to/scripts
bash setup.sh
```

`setup.sh` will:

1. Ask for your machine name, projects-root path, and a couple of behavior flags.
2. Write them into a config block at the top of `sessions.md`.
3. Optionally append a single zsh alias to `~/.zshrc` (e.g. `<machine>-nexus`
   if you set the machine name to `rocky`).
4. Print a VS Code `keybindings.json` snippet for you to add on your laptop.

After `source ~/.zshrc` (or opening a new terminal), you can run:

```bash
<machine>-nexus new
```

to start a new project session.

In VS Code on your laptop:

| Shortcut | What it does |
|---|---|
| `Cmd+Shift+B` | Reconnect **all** active sessions as editor tabs (`Reconnect All`) |
| `Cmd+Alt+R` | Open the task picker - type `Reconnect` and pick a single project (e.g. `Reconnect Empathic Communication`); those tabs land in the currently-focused editor pane |
| `Cmd+Alt+E` | Open `sessions.md` for editing |

`Cmd+Alt+R` enables a **per-project split-pane workflow**: split the editor (`Cmd+\`), focus a pane, fire `Reconnect <Project>` into it; focus another pane, fire a different one.

Other subcommands:

```bash
<machine>-nexus              # grouped interactive menu (Day-to-day / Recovery / etc.)
<machine>-nexus sync         # Manage tracked sessions - Attach, Archive, Drop, Reconnect
<machine>-nexus list         # All projects and sessions (incl. dormant); Attach / Revive / Reconnect
<machine>-nexus restore      # Recreate every Active session in tmux (post-reboot)
<machine>-nexus cycle        # Cycle /remote-control off-then-on on running sessions
<machine>-nexus alerts       # What automation did + what it tried to tell you
<machine>-nexus update       # Update the tool from GitHub (git installs)
<machine>-nexus regen-tasks  # Regenerate tasks.json (housekeeping)
<machine>-nexus backfill     # Scan ~/.claude/projects/ to fill missing UUIDs
<machine>-nexus revive       # Recreate a single dormant Claude conversation
<machine>-nexus help         # usage
```

### Per-session actions inside `sync` and `list`

When you pick a session inside `Manage tracked sessions` or `All projects and sessions`, the action menu is state-aware:

| Session state | Available actions |
|---|---|
| Tracked + tmux running | **Attach now** (drop into the running Claude Code session in tmux) · Move to Archived · Drop · cancel |
| Tracked + tmux not running | **Reconnect** (recreate the tmux session and run `claude --resume <uuid>` to resume the same conversation) · Move to Archived · Drop · cancel |
| Archived | Move to Active · Drop · cancel |
| Untracked tmux (NEW) | Attach now · Add to Active · Add to Archived · cancel |
| Dormant Claude conversation | **Revive** (create a new tmux session for an old `.jsonl` not in your list) · Show info · Back |

**Attach** = enter an existing running session. **Reconnect** = bring a tracked-but-stopped session back to life (single-session equivalent of `restore`). **Revive** = pick up a forgotten conversation from `~/.claude/projects/` history that was never in your tracked list.

If you don't have the prerequisites yet, the **Setup Guide** walks through everything
including Tailscale, SSH keys, VS Code Remote SSH config, and tmux setup.

## Read this

📘 **[Mac Mini Claude Code Setup Guide](Mac%20Mini%20Claude%20Code%20Setup%20Guide.md)**
- the full, step-by-step doc. Three sections in order: Daily use, Customize for
your machine, Full setup from scratch.

## How it fits together

```
┌────────────────────────┐         ┌──────────────────────────────────┐
│  Laptop                │         │  Mac mini (always-on agent)      │
│  ────────              │  Remote │  ─────────                       │
│  VS Code               │   SSH   │  zsh + aliases                   │
│   • keybindings.json   │ ──────► │   • <machine>-nexus new       │
│   • Cmd+Shift+B        │         │   • <machine>-nexus sync      │
│   • Cmd+Alt+R (picker) │         │   • <machine>-nexus hub       │
│   • Cmd+Alt+E          │         │   • <machine>-nexus restore   │
│                        │         │                                  │
│                        │         │  scripts/                        │
│                        │         │   • sessions.md  ◄── source of   │
│                        │         │     (config + active + archived)  │
│                        │         │                                  │
│                        │         │  ~/.vscode/tasks.json  ◄── auto- │
│                        │         │     generated from sessions.md    │
│                        │         │                                  │
│                        │         │  tmux sessions (one per project) │
│                        │         │   each running `claude` inside   │
└────────────────────────┘         └──────────────────────────────────┘
```

`Cmd+Shift+B` on the laptop fires the default VS Code build task, which is `Reconnect All` in `tasks.json`. That task runs `tmux attach -t <name>` once per Active session, in parallel, in new editor terminals. Tab labels track the tmux session name via `terminal.integrated.tabs.title: ${sequence}` plus tmux's `set-titles-string`.

`Cmd+Alt+R` opens VS Code's task picker. The updater also generates one `Reconnect <Project>` task per project group (each depending on its sessions in parallel), so the picker shows `Reconnect All` plus one entry per project - useful for opening a single project's tabs into a focused split pane.

## Requirements

- macOS (Mac mini as the agent machine; laptop can be macOS, Linux, or Windows)
- `bash` (the scripts work with macOS's default `bash` 3.2)
- `tmux`
- `zsh` (default macOS shell - for the aliases; you can also run scripts directly without aliases)
- VS Code + Remote - SSH extension (on the laptop)
- Claude Code installed on the Mac mini

## Customizing further

Most things you'd want to tweak live in the config block at the top of `sessions.md`:

| Key | What it does |
|---|---|
| `machine-name` | Prefix used in the alias names |
| `projects-root` | Directory the `new` subcommand offers as a picker; also the base for relative paths |
| `tasks-file` | Where the updater writes the VS Code tasks file |
| `enable-remote-control` | If `yes`, sends `/remote-control` inside Claude after each new session |

Edit `sessions.md` directly, or re-run `setup.sh` (idempotent - your existing
Active and Archived entries are preserved).

The scripts are pure bash, no external dependencies beyond `tmux` and `claude`.
Read them - they're short.

## License

Pick whatever you like - this is intended as starter scaffolding, not a maintained product.
