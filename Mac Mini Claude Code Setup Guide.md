# Mac Mini Claude Code Setup Guide

A practical guide to running Claude Code on a dedicated Mac mini as an
always-on AI agent machine, accessed remotely from a laptop (or phone).
Three sections, in order of how you'll likely read them:

1. **Daily use** - what you type once everything works.
2. **Customize for your machine** - adjust paths, add aliases, change tmux config.
3. **Full setup from scratch** - for a fresh Mac mini.

---

## 1. Daily use

*(For the automation layer - scheduled jobs, managed agent sessions, and the
agent bus - see section 4.)*

These commands assume Section 2 has been run and the zsh aliases are installed.
The command is `agent-nexus` on every machine. (Naming your machine during
setup adds personal aliases like `rocky-nexus`; same tool.)

```
agent-nexus               Show grouped menu (arrow-key + fzf if installed)
agent-nexus new           Start a new tmux + Claude session, register it
agent-nexus sync          Manage tracked sessions - Attach, Archive, Drop, Reconnect
agent-nexus list          All projects and sessions (incl. dormant); Attach / Revive / Reconnect
agent-nexus restore       Recreate every Active session in tmux (post-reboot)
agent-nexus cycle         Cycle /remote-control off-then-on on running sessions
agent-nexus update        Regenerate tasks.json from sessions.md (housekeeping)
agent-nexus backfill  Scan ~/.claude/projects/ to fill missing UUIDs
agent-nexus revive        Recreate a single dormant Claude conversation
agent-nexus setup         Re-run setup (config + alias)
agent-nexus help          Usage

tmux ls                         See what's running
tmux attach -t <name>           Attach to a specific session
` d         (in tmux)           Detach (leave running)
` [         (in tmux)           Enter scroll mode; q to exit
` ?         (in tmux)           List all keybindings

In VS Code on the laptop:
  Cmd+Shift+B                   Reopen all active sessions as tabs (Reconnect All)
  Cmd+Alt+E                     Edit sessions.md
  Cmd+Alt+R                     Task picker - type "Reconnect" to pick a
                                specific project's tabs (lands in the
                                currently-focused split pane)
```

Connect from your laptop (VS Code Remote SSH):

```
Cmd+Shift+P → Remote-SSH: Connect to Host → <user>@<tailscale-ip>
```

Connect from a phone or any terminal:

```
ssh <user>@<tailscale-ip>
tmux attach -t <session-name>
```

### Creating a session manually (without the alias)

The `agent-nexus new` command does all of this automatically. Use these
bare commands if you want to do it step by step, or you're in a shell where
the alias isn't available.

```bash
# 1. Create + attach to a new tmux session
tmux new -s <session-name>

# 2. Navigate to the project
cd <projects-root>/<project-name>

# 3. Launch Claude Code with all permissions
claude --dangerously-skip-permissions

# 4. Inside Claude, rename the Claude session to match the tmux name
/rename <session-name>

# 5. (Optional) If you have the /remote-control command set up, enable it
/remote-control

# 6. Detach from tmux when done (leaves Claude running)
` d
```

To register a manually-created session so it shows up in `Cmd+Shift+B`, run
`agent-nexus sync` and toggle it Active.

To enable computer-use MCP (browser/computer control) inside the Claude
session - usually a separate decision per session - type:

```
/mcp
```

…and select `computer-use` → Enable. macOS will prompt for Accessibility and
Screen Recording permissions on first use; grant both and select **Try again**.

### tmux quick reference

Prefix key: backtick `` ` `` (configured in this setup; default tmux prefix is Ctrl-B).
Press the prefix, release, then the action key.

| Action | Keys |
|---|---|
| Detach (leave running) | `` ` `` then `d` |
| List / switch sessions | `` ` `` then `s` |
| Rename current session | `` ` `` then `$` |
| New window | `` ` `` then `c` |
| Switch window 0–9 | `` ` `` then `0–9` |
| Rename window | `` ` `` then `,` |
| Split pane vertically | `` ` `` then `%` |
| Split pane horizontally | `` ` `` then `"` |
| Switch panes | `` ` `` then arrow |
| Enter scroll mode | `` ` `` then `[` (q to exit) |
| List all keybindings | `` ` `` then `?` |

Mouse support is enabled, so trackpad scroll works in panes without entering scroll mode.

---

## 2. Customize for your machine

This assumes you already have:

- A Mac mini you can SSH into
- VS Code with the Remote - SSH extension on your laptop
- `tmux` installed on the Mac mini
- `claude` (Claude Code) installed on the Mac mini

If you don't, jump to Section 3 first.

### Run `setup.sh`

From a terminal on the Mac mini, in the `scripts/` folder:

```bash
bash setup.sh
```

It walks you through the machine config and every behavior setting (each with
an explanation and a proposed default you can accept or change):

| Prompt | What to enter |
|---|---|
| Machine / agent name | Optional. A short label (e.g. `rocky`, `helm`, `jarvis`) that adds personal aliases like `rocky-nexus` beside the canonical `agent-nexus` command. Blank is fine. |
| Projects root | Absolute path to where your project subdirectories live. Defaults to `~/Projects` if it exists, else `~/Dropbox`. |
| `tasks.json` path | Where VS Code's auto-generated tasks file lives. Default `~/.vscode/tasks.json` is right for most setups. |
| Enable `/remote-control` | Whether to send `/remote-control` inside Claude after each new session. Default `no`. Only set to `yes` if you have that custom Claude Code command set up. |
| Permission mode | Default permission posture for sessions: `bypass` / `auto` / `ask` (see the Config-keys table below). Fresh installs propose `auto`. |
| Enable Chrome | Launch sessions with `--chrome` (browser + computer-use tools). Default `yes`. |
| Boot-restore | Auto-relaunch every Active + managed session on the first scheduler tick after a reboot. Default `off`. |
| Catch-up window | How late a missed scheduled run may still fire, in hours. Default `12`. |

It writes the config block at the top of `scripts/sessions.md`, then offers
to add a single zsh alias to `~/.zshrc`. The alias lands between marker lines
(`# >>> claude-mac-mini-setup >>>` … `# <<< claude-mac-mini-setup <<<`) so
you can remove it cleanly later. Idempotent - safe to re-run.

After setup, open a new terminal (or `source ~/.zshrc`) and the alias works.

### What `agent-nexus` does

One alias, multiple subcommands. Run with no arguments for a compact
interactive menu of five groups. The five menu groups:

| Menu entry | What it opens |
|---|---|
| Sessions | The **Sessions hub** (`hub`): every session - active, archived, dormant conversations, untracked tmux - in one grouped table with an AUTOMATION column (managed / scheduled / memory / reset / checkpoint badges, legend at the top). Pick a session for its actions: Attach, Reconnect, Archive, Rename (changes the name everywhere: registry, tmux, managed settings, scheduled tasks, Claude title), Drop, Revive, Automation settings, Info. On open, the hub detects sessions renamed inside Claude via `/rename` and offers to adopt the new name system-wide or revert it. Bulk archive / reactivate / un-manage live here too. Group by project (default) or by state: Ctrl-P / Ctrl-S in fzf, bare `p` / `s` in the numbered fallback; rows are numbered so typing a number picks (handy on a phone). Typing filters by whole substring (each word must appear somewhere in the line), not scattered letters. |
| Start a new session | `new`: prompts for name + project; creates tmux + launches Claude with your launch settings; captures the conversation UUID; registers it. |
| Automation | Schedule tasks (`schedule`), agent bus status (`bus-status`), the SSH door for other machines (`install-bus-key`). |
| Tools and maintenance | Reconnect all (`restore`), boot-restore sweep (`boot-restore`), health check (`doctor`), remote-control cycle (`cycle`), regenerate tasks.json (`update`), fill missing UUIDs (`backfill`). |
| Settings | Global defaults - permission-mode, chrome, remote-control, boot-restore, catchup-hours - plus the setup wizard. |

Direct subcommand invocation works too: `agent-nexus hub`, `agent-nexus new`,
etc. - useful for keyboard shortcuts or shell scripts. The pre-hub flows
(`sync`, `list`, `managed`) still work as direct commands.

### tmux config used by this setup

Add to `~/.tmux.conf` on the Mac mini:

```
set -g prefix `                                    # backtick prefix
unbind C-a                                         # release Ctrl-A
unbind C-b                                         # release Ctrl-B (tmux's default)
bind ` send-prefix                                 # press backtick twice to send a literal backtick
set -g mouse on                                    # trackpad scroll, click panes
set -g allow-passthrough on                        # required for Option+Enter through tmux
set-option -g history-limit 10000                  # 10k lines of scrollback per pane
set-option -g set-titles on                        # set the terminal window title
set-option -g set-titles-string "#{session_name}"  # title content = tmux session name
setw -g aggressive-resize on                       # resize smartly when multi-attached
```

Reload without restarting tmux:

```
tmux source-file ~/.tmux.conf
```

### Where VS Code config files live (and how to open them)

VS Code stores user configuration in three JSON files. They all live on
**your laptop** (where VS Code itself runs), not on the Mac mini. Each file
also has a friendlier UI, but the JSON is the source of truth and sometimes
you want to edit it directly.

| File | What's in it | How to open |
|------|--------------|-------------|
| `settings.json` | Editor / terminal / extension preferences | `Cmd+,` opens Settings UI. In the top-right, click the icon shaped like a sheet of paper with a curl (tooltip: **Open Settings (JSON)**). |
| `keybindings.json` | Custom keyboard shortcuts | `Cmd+K Cmd+S` opens the Keyboard Shortcuts UI. Same curl-paper icon top-right (tooltip: **Open Keyboard Shortcuts (JSON)**). |
| `tasks.json` | Defined tasks (where `Reconnect All` and `Edit Sessions` live) | `Cmd+Shift+P` → type `Tasks: Open User Tasks`, or open the file directly. |

Universal shortcut: hit **`Cmd+Shift+P`** to open the command palette and
start typing the file name. VS Code autocompletes commands like
`Open User Settings (JSON)`, `Open Keyboard Shortcuts (JSON)`,
`Tasks: Open User Tasks`.

File locations on disk:

| File | Path on the laptop (macOS) | Path on the Mac mini |
|---|---|---|
| `settings.json` | `~/Library/Application Support/Code/User/settings.json` | n/a |
| `keybindings.json` | `~/Library/Application Support/Code/User/keybindings.json` | n/a |
| `tasks.json` | n/a (the one this setup uses is on the Mac mini) | `~/.vscode/tasks.json` |

> Why `tasks.json` is on the Mac mini and the others are on the laptop:
> keybindings and settings belong to the VS Code window's UI (laptop). Tasks
> run shell commands, and shell commands run on whatever machine the workspace
> lives on - for this setup, the Mac mini via Remote SSH. So `tasks.json`
> lives with the workspace, while keybindings/settings live with the editor.

On Linux, replace `~/Library/Application Support/Code/` with `~/.config/Code/`.
On Windows, with `%APPDATA%\Code\`.

### VS Code settings the automation depends on

In your laptop's VS Code User settings JSON (`Cmd+Shift+P` → "Open User Settings (JSON)"):

```json
{
    "terminal.integrated.macOptionIsMeta": true,
    "terminal.integrated.tabs.title": "${sequence}",
    "terminal.integrated.defaultLocation": "editor"
}
```

| Setting | Why |
|---|---|
| `macOptionIsMeta: true` | Makes Option+Enter work in Claude Code (without it, Option becomes a special character) |
| `tabs.title: ${sequence}` | Lets terminal tab labels track tmux's `set-titles-string` (i.e. the session name) |
| `defaultLocation: editor` | New terminals open as full editor tabs, not in the bottom panel |

### How `sessions.md` is structured

Sessions are grouped under `### Project` headers. Each header's display name
defaults to a folder under `projects-root` (with `_` → spaces). Sessions under
a header inherit that path, so each session line is just `<name>  <session-id>`.

```markdown
# Sessions

## Config
machine-name: rocky
projects-root: /Users/<you>/Projects
tasks-file: /Users/<you>/.vscode/tasks.json
enable-remote-control: no
permission-mode: auto
enable-chrome: yes

## Active

### My Project
session-name-1                                  abc12345-6789-...
session-name-2                                  def67890-1234-...

### Other Project → some/relative/or/abs/path
another-session                                 fedcba09-...

### Uncategorized
legacy-without-path
one-off  /absolute/somewhere/else               ...uuid

## Archived
### My Project
session-i-stopped-using                         123456ab-...
```

Edit by hand (`Cmd+Alt+E` opens it in VS Code) or via `agent-nexus sync`.
Lines starting with `#` are comments. Blank lines are ignored.

**Path interpretation:**

- starts with `/` → absolute path
- starts with `~` → expanded to `$HOME`
- otherwise → relative to `projects-root`

**`<session-id>`** is the Claude Code conversation UUID (8-4-4-4-12 hex). When
present, `restore` uses `claude --resume <id>` to bring back that exact
conversation. Without one, `restore` falls back to `claude --continue` (which
resumes the most-recent conversation in that directory - risky if multiple
sessions share a directory). `new` captures the id automatically; legacy
entries can be backfilled with `agent-nexus backfill`.

Config keys:

| Key | What it does |
|---|---|
| `machine-name` | Optional label for this machine. Adds personal aliases (`<name>-nexus`, `<name>-sessions`) beside the canonical `agent-nexus`. |
| `projects-root` | Directory `new` offers as a picker for "where should this session run?" Also the base for relative paths in Active/Archived lines. |
| `tasks-file` | Where the updater writes the VS Code tasks file. |
| `enable-remote-control` | If `yes`, `new` and `restore` send `/remote-control` inside Claude after each new session. Off by default. |
| `permission-mode` | Default permission posture for launched sessions: `bypass` (`--dangerously-skip-permissions`, auto-approve everything), `auto` (`--permission-mode auto`, a safety classifier vets actions), or `ask` (normal prompting). A managed session can override this per-session (see §4.2). |
| `enable-chrome` | If `yes` (default), sessions launch with `--chrome` (browser + computer-use tools). |
| `boot-restore` | If `on`, the scheduler's first tick after a reboot automatically relaunches every Active + managed session (one-shot per boot). Needs the ticker installed, and auto-login on a headless Mac. Default `off`. |
| `catchup-hours` | Missed-run window in hours (default 12): a scheduled run the machine slept through still fires if less than this late; older ones are skipped so nothing fires absurdly late. |
| `notify-command` | Optional. A command run as `<command> "<message>"` to alert YOU when something needs a human: a session logged out of Claude, a managed session that can't be healed, a failed bus request (throttled to once per 4h per condition). `agent-nexus setup-telegram` walks the whole Telegram flow, from bot creation to a test message. Empty = off. |
| `keep-alive` | If `on` (default), every scheduler tick relaunches any managed session whose Claude died, so automation targets stay alive. Per-session override in `managed-sessions.md`. |

**These launch settings are user-controllable.** Edit them from the menu
("Session launch settings", or `agent-nexus settings`) or by re-running
`setup.sh`, which walks you through each one and explains its effect. On a fresh
install the wizard proposes `permission-mode: auto` (the safer, classifier-checked
mode) for the interactive sessions you create; unattended automation targets
default to `bypass` so a scheduled run never stalls at a prompt. If a setting is
absent from an older `sessions.md`, the tool behaves as it always did
(`bypass` + `--chrome`) until you set it.

### How `tasks.json` is structured

You don't edit this file - `agent-nexus update` regenerates it. For each
Active session, there's a task that runs `tmux attach -t <name>` in a new editor
terminal. There's also a `Reconnect All` task that depends on all of those (run
in parallel) and is the default build task - that's what `Cmd+Shift+B` triggers.
Plus an `Edit Sessions` task that opens `sessions.md` (bound to `Cmd+Alt+E` if
you add the keybinding).

To bind `Cmd+Alt+E` to the Edit Sessions task, add to your VS Code keybindings
(`Cmd+Shift+P` → "Open Keyboard Shortcuts (JSON)"):

```json
[
    {
        "key": "cmd+alt+e",
        "command": "workbench.action.tasks.runTask",
        "args": "Edit Sessions"
    },
    {
        "key": "cmd+shift+b",
        "command": "workbench.action.tasks.build"
    },
    {
        "key": "cmd+alt+r",
        "command": "workbench.action.tasks.runTask"
    }
]
```

`Cmd+Alt+R` is the task picker - type `Reconnect` and you'll see one entry per
project (`Reconnect <Project>`) plus a global `Reconnect All`. Lets you fire
just one project's tabs into the currently-focused editor pane. **Per-project
split-pane workflow:**

1. `Cmd+\` to split the editor (or drag a tab to create a new editor group).
2. Click into the pane you want to fill.
3. `Cmd+Alt+R` → type `Reconnect <Project>` → Enter.
4. Click into the next pane and repeat for another project.

---

## 3. Full setup from scratch

Starting from a fresh Mac mini you can already screen-share into.

### 3.1 Network access (Tailscale)

Tailscale gives you a stable address that works from anywhere - home, office, phone.
Free for personal use.

On the Mac mini:

1. Install Tailscale: download from <https://tailscale.com/download> or `brew install tailscale`.
2. Sign in. The Mac mini gets an IP like `100.x.x.x`. Note it down.
3. On your laptop, install Tailscale and sign into the same account. Both machines must be running Tailscale for the IP to resolve.

Verify: `ping 100.x.x.x` from the laptop.

### 3.2 SSH access

1. **Mac mini side:** System Settings → General → Sharing → enable **Remote Login**. Add your user to the allowed list.
2. **Laptop side:** generate an SSH key if you don't have one:
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```
   Press Enter to accept defaults. Then copy your public key to the Mac mini:
   ```bash
   ssh-copy-id <user>@<tailscale-ip>
   ```
   Test:
   ```bash
   ssh <user>@<tailscale-ip>
   ```

### 3.3 Headless reboot recovery (optional but useful)

If the Mac mini reboots, you want it back online without plugging in a monitor:

- System Settings → Users & Groups → Automatic login on (caveat: with FileVault on, autologin means the disk gets decrypted on boot; understand the security trade-off).
- System Settings → Battery / Energy → "Wake for network access" on, "Prevent sleep when display is off" on.

### 3.4 Homebrew + tools

Install Homebrew on the admin user (skip if already installed):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then install the tools used by this setup:

```bash
brew install tmux gh
```

If your AI-agent user is non-admin (recommended), Homebrew lives under the admin's path. To use it as the agent user, add to that user's `~/.zshrc`:

```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

To install new packages later, switch to admin first: `su - <admin-user>`, then `brew install`.

### 3.5 Claude Code

Install Claude Code on the Mac mini following the official instructions
(<https://docs.anthropic.com/claude-code> / `npm install -g @anthropic-ai/claude-code` or whichever method is current).

Sign in once interactively so the auth tokens are saved.

### 3.6 tmux config

Create `~/.tmux.conf` with the contents from Section 2 above.

### 3.7 VS Code Remote SSH on the laptop

1. Install the **Remote - SSH** extension.
2. `Cmd+Shift+P` → "Remote-SSH: Open SSH Configuration File" → pick `~/.ssh/config`. Add:
   ```
   Host mac-mini
       HostName <tailscale-ip>
       User <user>
   ```
3. `Cmd+Shift+P` → "Remote-SSH: Connect to Host" → `mac-mini`.
4. Open a terminal in VS Code (`Ctrl+\``) - you're now in a shell on the Mac mini.

Apply the VS Code settings from Section 2.

### 3.8 Drop in `scripts/` and run setup

1. Copy or clone the `scripts/` folder onto the Mac mini somewhere convenient (e.g. inside a Dropbox-synced project folder so you can edit `sessions.md` from your laptop).
2. From a terminal on the Mac mini, in that folder:
   ```bash
   bash setup.sh
   ```
3. Answer the prompts (see Section 2).
4. Open a new terminal so the aliases load.

### 3.9 Create your first session

```bash
agent-nexus new
```

Pick a name and a project directory. The script will create the tmux session, launch Claude, and attach.

Detach with `` ` `` then `d`. From your laptop's VS Code window, press `Cmd+Shift+B` - the session opens as an editor tab, attached to the same tmux session that's still running on the Mac mini.

---

## 3b. Controlling the Mac from your phone (Telegram)

Optional, and separate from Telegram *alerts*. Alerts are one-way, from the Mac
to you. This is the other direction: a small, fixed set of commands you can send
to the Mac.

```
agent-nexus setup-telegram-control
```

The guided flow creates a **second** bot, records exactly one chat as the only
one allowed to command it, and offers to install the always-on poller.

**Say yes to the poller.** Without it, commands are only read on the 15-minute
scheduler tick. That sounds acceptable until you remember what this is for: you
are away from the Mac, a session has died, Remote Control is therefore
unreachable, and your phone is the only way in. A reply that might be a quarter
of an hour away is not a recovery tool. With the poller, commands land in about
a second. It is a LaunchAgent with `KeepAlive`, so it survives crashes and
reboots.

```
agent-nexus install-telegram-daemon      # start it (setup offers this too)
agent-nexus uninstall-telegram-daemon    # stop and remove it
```

`doctor` warns if Telegram control is configured but the poller is missing, or
loaded but not checking in.

### The commands

| Command | What it does |
|---|---|
| `/status` | What is up, what is down, sign-in health, ticker state |
| `/sessions` | Every active and standby session with its status |
| `/heal <name>` | Relaunch a session that has died |
| `/launch <name>` | Start a tracked session that is not running |
| `/rc <name>` | Check Remote Control for a session |
| `/approve <name>` | Take option 1 of the approval dialog waiting in that session |
| `/deny <name>` | Dismiss that dialog (Escape) instead |
| `/login <name>` | Run `/login` there and send the sign-in URL back to you |
| `/code <code>` | Paste the sign-in code back (single use, 10 minutes) |
| `/digest` | The latest digest note |
| `/help` | The list above |

### What it deliberately cannot do

There is no command that sends free text into a session. This drives the tool,
not the agents. The rest of the design follows from that:

- Exactly one chat id may issue commands. Anything else is logged and dropped
  **silently**, because replying tells whoever found the bot that it is live.
- The verb list is closed, not parsed. Unknown verbs never reach code that
  touches a session.
- A session name must both look like a name and already be a session the tool
  knows, so no message can name a target that does not exist.
- Anything typed into a pane goes through `tmux send-keys -l` (literal), so text
  can never be interpreted as tmux key names.
- The sign-in slot is single-use, expires in 10 minutes, and is pinned to the
  session that asked for it.
- `/approve` and `/deny` only ever press `1`, Enter or Escape, and only when a
  dialog is on screen at that moment (the pane is re-checked right before the
  keypress, so a stale command presses nothing).
- Every command, accepted or refused, is written to
  `<state dir>/telegram-control.log`. Login codes never are.

### The approval watch

With `--chrome` on, Claude renders its per-site approval gate as a dialog in
the terminal, exactly like a file or shell approval in `auto` mode. In an
unattended session that dialog just sits there: the session looks alive and
does nothing. The watch scans every tracked session's pane (every ~25 seconds
while the poller runs; each 15-minute tick otherwise), and when it finds a
waiting dialog it texts you the question itself, so you decide with the words
in front of you. Answer with `/approve <name>` or `/deny <name>`. The same
dialog is never texted twice; a new, different one alerts immediately.

## 4. Automation: scheduler, managed sessions, and the agent bus

Beyond managing sessions, agent-nexus can run sessions on a schedule and let
other machines hand them work. All of this is reachable from the main menu
(`agent-nexus`) under the **Automation** group.

This section is the task-oriented quickstart (how to set each one up). For the
internals and design rationale (firing/gating logic, the self-heal matrix, the
bus queue mechanics, the double-attach guard), the canonical reference is
`SYSTEM-NOTES.md` §8 / §8b in the project root, so those details live in one
place and are not restated here.

> **Command prefix in the examples below:** they are written with `agent-nexus`
> for readability.
> The one exception is the agent-bus SSH door: the sender must type the literal
> `agent-nexus` there, because that is the fixed grammar the restricted wrapper
> matches (independent of your machine name).

### 4.1 The scheduler (timed prompts)

A single launchd LaunchAgent (`com.agent-nexus.ticker`) wakes every 15
minutes and fires due tasks. Set it up once:

```
agent-nexus schedule        # menu: Add a task, then "Install / reload the ticker"
```

Each task lives in `scheduled-tasks.md` as `id | schedule | prompt | enabled`
under a `### <target-session>` header. Schedules: a time alone means daily
(`18:00`, `8am`, `7:30 pm`), `daily <time>` works too, and a weekday makes it
weekly (`Sat 08:00`, `saturday 8pm`). Case, abbreviations, leading zeros, and
am/pm spacing or periods all wash out; a bare hour with no am/pm is rejected
as ambiguous. Best practice for the prompt: point it at an instruction file
(the wizard offers this as a picker over the files in the session's
directory), which stores `Read <file> and follow it.` The ticker gates each
task per-occurrence (no double-fires), catches up a missed run within 12h,
and skips a target that's busy (retries next tick).

The wizard walks the whole setup: target session (shown with its project),
id, schedule, what to do, and the target's automation settings (managed
status, reset, memory, permission mode). `Edit a task` changes any of it
later, except the id, which run history is keyed by. Removing a task offers
to remove its now-jobless session too (keep is the default; the saved
conversation is never deleted).

After a reboot, run `agent-nexus restore` to bring your sessions back, or
set `boot-restore: on` in Settings and the first tick after a boot does it
for you; self-heal also recreates a missing target on the next fire.

### 4.2 Managed agent sessions

A **managed agent session** is just one of your sessions that you've switched
automation on for: it self-heals if its Claude dies (relaunches and resumes the
same conversation), has its own permission mode and a memory policy, and can
receive scheduled tasks and agent-bus requests. Settings live in
`managed-sessions.md`, keyed by the session's own name (the working dir + UUID
come from `sessions.md`).

```
agent-nexus managed         # menu: Manage agent sessions
```

- **heal**: `resume` (default; relaunch + `--resume` the same conversation) or
  `fresh` (new conversation each heal, for long-running sessions whose history
  has grown large).
- **permission-mode**: `bypass` (default, `--dangerously-skip-permissions`),
  `auto` (`--permission-mode auto`, the classifier-driven mode), or `ask`
  (normal prompting). This overrides the global `permission-mode` (the Config
  block in §2) for this session. `bypass` is the default for automation targets because an
  unattended run must never stall at a prompt. Before switching a session to
  `auto`, generate its least-privilege allowlist:
  `agent-nexus gen-session-settings <dir>` (this denies writes to the
  control plane so a compromised session can't escalate). Don't use `ask` for a
  session that receives scheduled/bus runs, it would hang waiting for input.
  (The old key name `profile` with value `legacy` is still accepted and reads as
  `permission-mode: bypass`.)
- **memory**: `none`, `read`, or `read-write` - the STATE.md contract, a durable
  notebook in the session's dir that survives clears/compacts/crashes. `read`
  tells a fresh or cleared brain to READ `STATE.md` first (you supply your own
  instructions for what to write, in the session's `CLAUDE.md`); `read-write` also
  appends a built-in protocol to each run so it WRITES `STATE.md` back (Last run /
  Carry-forward / Issues / For the human) and flags you if the file grows past ~60
  lines. See `STATE.md.template` for the shape.
- **reset**: `none` (default), `compact`, or `clear` - what to do to the
  conversation *before* each scheduled run, so a recurring job doesn't
  accumulate context run over run. `compact` runs `/compact` (summarize, same
  conversation); `clear` runs `/clear` (a brand-new empty conversation, best for
  stateless instruction-file jobs; the scheduler waits for it to settle, then
  re-captures the new conversation id into `sessions.md` automatically). Pair
  `reset: clear` with `memory: read-write` to keep durable notes across the wipe.
- **keep-alive**: `default` (follow the global `keep-alive` setting), `on`, or
  `off`. When effective-on, the scheduler heals this session every tick if its
  tmux or Claude has died. Set `off` for a managed session you want to stay
  down when you kill it.
- **checkpoint-compact**: `off` (default) or `on` - lets a long-running session
  shed its own context to cut token cost. When on, the session compacts at
  boundaries *it* declares: after committing a unit and updating its docs, it runs
  `agent-nexus compact-checkpoint --next "<next step>"` and ends its turn; the
  tool injects `/compact` (Claude Code can't self-trigger it), waits for it to
  settle, confirms the session is responsive, then re-prompts it to continue. Set it
  up with `agent-nexus enable-checkpoint-compact <session>` (also in the
  Automation menu), which installs the hooks and offers a compaction-safe
  documentation discipline for the project's `CLAUDE.md` (so nothing is lost when the
  history is compacted).

### 4.3 The agent bus (request-triggered work)

Other machines' agents ask a managed session to do something. There are two
ways in: over SSH, or by dropping one Markdown file per request into a queue
folder both machines can see. The ticker drains the queue every 15 minutes
(the "sweep"); a direct poke delivers instantly.

- **Local / SSH front door:** `agent-nexus submit --target <session> "<ask>"`
  writes a request and processes it immediately.
- **File front door:** write a request file into
  `<projects-root>/_agent-bus/inbox/` (format in `BUS-PROTOCOL.md`), then
  optionally `ssh mini "agent-nexus process-inbox"` to trigger it now.
- **Enabling the SSH door (one time):** run `agent-nexus install-bus-key`
  (the setup wizard also offers it). Paste the *public* key from the sending
  machine; it installs that key behind a restricted forced-command wrapper that
  permits only `submit` and `process-inbox`, then prints the exact SSH commands
  to hand to the sender's agent. Key generation happens on the sender
  (`ssh-keygen -t ed25519`); you only install the `.pub` it gives you. This is a
  machine-level grant: once enabled, that machine's agent can target *any*
  managed session, same as the file door.
- Requests may only target a registered managed agent session. Delivery treats
  the request as untrusted input, heals a dead target first, and never types
  over a working session or a human at the keyboard.

Queue state is the folder a request sits in: `inbox → processing → done`
(delivered; outcome appended) or `waiting` (busy/retry) or `failed`. See
`BUS-PROTOCOL.md` for the sender contract and `SENDER-RECIPE.md`
for how to teach a laptop agent to use it.

For a compromised-sender / prompt-injection threat model and its mitigations
(control-plane write-deny, forced-command ssh key), see `Agent Bus - Design
Spec.md`.

#### Do you need Dropbox (or any sync service)?

Short answer: **no, not for the tool itself.** Sessions, the scheduler, and
everything in sections 1 to 4.2 run entirely on one machine with no sync
service involved. Sync only enters the picture for the *file* door of the
agent bus, and even there it is optional:

| What you want | What you need |
| --- | --- |
| One machine (sessions + scheduler) | Nothing. No sync service. |
| Drive the Mini from a laptop | Nothing. Use SSH, or Remote Control in the Claude app. |
| Another machine's agent sends requests | **Either** the SSH door (no shared folder at all) **or** a shared folder for the file door. |

The **SSH door needs no synced folder**: `submit` runs on the Mini over SSH
and writes into the Mini's own local queue. If you set up the restricted key
(`install-bus-key`), you can skip shared storage entirely. That is the
simplest and the most locked-down option, since the forced command permits
only two verbs.

The **file door** needs a folder that both machines can see, and the tool does
not care how it gets there. The queue lives at `<projects-root>/_agent-bus/`,
derived from the projects-root you set during setup, so the sync provider is
whatever that path happens to sit in. Any of these work:

- **Dropbox, iCloud Drive, Google Drive, OneDrive** — easiest if you already
  run one. The protocol is deliberately conflict-free: files are only ever
  *moved* between folders in one direction, never edited in place by two
  machines, so no provider's conflicted-copy logic gets a chance to fire.
- **Syncthing** — peer-to-peer, no third-party servers. Good fit if you would
  rather not put request text in a commercial cloud.
- **An SMB/NFS share or a mounted volume** — fine on a LAN.
- **`rsync` or `scp` on a timer** — crude but sufficient, since a request file
  only needs to arrive before the next 15-minute sweep.

Two things to know if you choose a cloud provider:

1. **Request text passes through that provider.** The queue holds the ask, the
   session name, and the outcome the session appends. Treat it as you would a
   shared document folder.
2. **Sync must actually be running.** `doctor` warns when the queue is inside
   a Dropbox path and the Dropbox process is not running, since a paused
   client silently strands inbound requests.

**Should your project folders be synced?** That is a separate choice from the
bus, and it is a genuine tradeoff. Keeping projects in a synced folder gives
you version history, off-machine backup, and the ability to edit a project's
files from your laptop directly. The cost is that the folder holding
executable code becomes a remote-write surface: anything that can write to
your sync account can change code that later runs on the host machine. A
reasonable middle ground is to sync your project *data* while running the
tool itself from a local path outside the synced folder.

### 4.4 Checking on it

```
agent-nexus bus-status      # queue counts, ticker + heartbeat, managed sessions
agent-nexus doctor          # health check across sessions, scheduler, bus
```

Operational state (fire ledger, logs, locks) lives in the state dir: `~/.agent-nexus/` on new installs (installs from before the rename keep `~/.rocky-sessions/`)
(local, not synced). The bus queue lives in `<projects-root>/_agent-bus/`.

## Troubleshooting

| Problem | Fix |
|---|---|
| Can't SSH in | Tailscale running on both machines? `ping <tailscale-ip>` from laptop. Mac mini awake (System Settings → Battery)? |
| `Cmd+Shift+B` opens fewer sessions than expected | Some aren't running, OR aren't in `sessions.md`. Run `agent-nexus sync`. |
| Just rebooted, `Cmd+Shift+B` does nothing | tmux server is gone after reboot. Run `agent-nexus restore` to recreate every Active session whose project path is stored, then `Cmd+Shift+B`. |
| `Cmd+Shift+B` says "No build task to run found" | VS Code has no folder open as the workspace. `tasks.json` only loads when its parent `.vscode/` folder is in your workspace. Fix: **File → Open Folder** → your home directory (or wherever you set `tasks-file` to live), then `Cmd+Shift+B`. |
| `Cmd+Shift+B` shows "Couldn't resolve dependent task '<name>'" for every session | SSH disconnected. Check the bottom-left status bar - if it says "Disconnected from SSH", click it to reconnect. tmux sessions on the agent machine are unaffected. |
| Claude Desktop shows two entries for the same session (one broken, one working) | Auth on the underlying Claude Code process expired and prompted for `/login`. Claude Desktop saw it as "stopped responding"; after re-login + re-toggling `/remote-control` it registered the recovered connection as a NEW entry without reaping the old one. Fix: fully quit Claude Desktop (`Cmd+Q` on macOS) and reopen - usually flushes the stale entries. |
| Claude Desktop shows "Remote Control disconnected" or duplicate session entries | Claude auth tokens expired inside the tmux Claude processes. The Claude REPL prompts for `/login`. After re-authing and re-toggling `/remote-control`, Claude Desktop may show both the new and stale connections. Fix: quit Claude Desktop fully and reopen - flushes stale registry. |
| Tab title shows "zsh" not session name | `set-titles on` missing from `~/.tmux.conf`, or you didn't reload (`tmux source-file ~/.tmux.conf`). |
| Option+Enter not working in Claude Code | Check `macOptionIsMeta: true` in laptop VS Code settings, AND `allow-passthrough on` in Mac mini's tmux config. |
| Compound `cd && git` prompts | Per-project. Add `"Bash(cd * && git *)"` to that project's `.claude/settings.local.json` allow list. |
| VS Code Remote SSH won't connect | `Cmd+Shift+P` → "Remote-SSH: Kill VS Code Server on Host", then reconnect. |
| `brew install` fails as the agent user | Switch to admin: `su - <admin-user>`, then install. |
| tmux sessions vanished | Mac mini rebooted. tmux sessions don't survive reboots. Run `agent-nexus restore` to recreate them in bulk; Claude Code will offer to resume each from `.claude/` history. |
