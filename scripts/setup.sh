#!/bin/bash

# ─────────────────────────────────────────────
# setup.sh
#
# First-run / re-run configuration for the Claude Code on a Mac mini
# automation. Run this on the agent machine (where Claude Code lives).
#
#   - Asks for your machine name, projects-root path, and a couple of
#     behavior flags. Writes them into the ## Config block of
#     sessions.md.
#   - Optionally appends the agent-nexus alias (plus personal machine-name
#     aliases) to ~/.zshrc, between markers so they're easy to remove later.
#   - Prints a VS Code keybindings snippet for you to add on the laptop.
#
# Safe to re-run any time. Existing values are shown as defaults; press
# Enter to keep them.
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The registry may live outside the script dir. Resolve it exactly the way
# sessions.sh does, or a re-run after the data-dir move writes your machine
# name and projects-root into a brand-new empty sessions.md beside the script
# while the real one sits untouched in the data directory.
DATA_DIR="$SCRIPT_DIR"
if [ -n "${AGENT_NEXUS_DATA_DIR:-}" ]; then
  DATA_DIR="$AGENT_NEXUS_DATA_DIR"
elif [ -f "$SCRIPT_DIR/data-dir.conf" ]; then
  _dd=$(grep -v '^[[:space:]]*#' "$SCRIPT_DIR/data-dir.conf" 2>/dev/null | grep -v '^[[:space:]]*$' | head -1)
  _dd="${_dd%"${_dd##*[![:space:]]}"}"
  _dd="${_dd#"${_dd%%[![:space:]]*}"}"
  case "$_dd" in "~"/*) _dd="$HOME/${_dd#\~/}" ;; esac
  [ -n "$_dd" ] && DATA_DIR="$_dd"
  unset _dd
fi
SESSIONS_FILE="${AGENT_NEXUS_SESSIONS_FILE:-$DATA_DIR/sessions.md}"
ZSHRC="$HOME/.zshrc"

ALIAS_BEGIN="# >>> claude-mac-mini-setup >>>"
ALIAS_END="# <<< claude-mac-mini-setup <<<"

# ANSI color codes for section dividers. Disabled if NO_COLOR is set or stdout
# isn't a terminal (so log files / pipes don't get garbled escape codes).
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_CYAN=$'\033[36m'
  C_YELLOW=$'\033[33m'
  C_GREEN=$'\033[32m'
  C_BLUE=$'\033[34m'
else
  C_RESET=""
  C_DIM=""
  C_BOLD=""
  C_CYAN=""
  C_YELLOW=""
  C_GREEN=""
  C_BLUE=""
fi

# section_divider <color> <title>
# Prints a colored full-width divider with a centered title; used between
# major prompts in setup so the flow is easy to scan visually.
section_divider() {
  local color="$1"
  local title="${2:-}"
  local width=64
  local line
  line=$(printf '─%.0s' $(seq 1 $width))
  echo ""
  echo "${color}${line}${C_RESET}"
  if [ -n "$title" ]; then
    echo "${color}${C_BOLD}  $title${C_RESET}"
    echo "${color}${line}${C_RESET}"
  fi
}

# Reuse parse_sessions_file, write_sessions_file, format_session_line, etc.
# from sessions.sh — single source of truth for the file format.
# shellcheck source=./sessions.sh
source "$SCRIPT_DIR/sessions.sh"

# ---------------------------------------------
# Helpers
# ---------------------------------------------

prompt_with_default() {
  local prompt="$1"
  local default="$2"
  local var
  if [ -n "$default" ]; then
    read -r -p "$prompt [$default]: " var
    [ -z "$var" ] && var="$default"
  else
    read -r -p "$prompt: " var
  fi
  echo "$var"
}

# --relink: re-point the ~/.zshrc aliases at this copy of the tool and exit.
# The full wizard asks seven questions; after moving the install directory the
# only thing that actually needs to change is the path inside two alias lines,
# and a runbook step should not require sitting through the rest.
RELINK_ONLY=0
case "${1:-}" in --relink|relink) RELINK_ONLY=1 ;; esac

alias_prefix() {
  if [ -n "$CFG_MACHINE_NAME" ]; then
    echo "$CFG_MACHINE_NAME"
  else
    echo "agent"
  fi
}

build_alias_block() {
  local prefix
  prefix=$(alias_prefix)
  # agent-nexus is THE command; every instruction the tool prints names it.
  # A machine name adds personal convenience aliases on top (and keeps old
  # muscle memory working on long-lived installs), but is never the identity.
  if [ -n "$CFG_MACHINE_NAME" ] && [ "$prefix" != "agent" ]; then
    cat <<EOF
$ALIAS_BEGIN
alias agent-nexus='bash "$SCRIPT_DIR/sessions.sh"'
# personal aliases for this machine; same tool:
alias ${prefix}-nexus='bash "$SCRIPT_DIR/sessions.sh"'
alias ${prefix}-sessions='bash "$SCRIPT_DIR/sessions.sh"'
$ALIAS_END
EOF
  else
    cat <<EOF
$ALIAS_BEGIN
alias agent-nexus='bash "$SCRIPT_DIR/sessions.sh"'
$ALIAS_END
EOF
  fi
}

install_aliases() {
  local block
  block=$(build_alias_block)
  touch "$ZSHRC"

  # ALWAYS take a timestamped backup before touching ~/.zshrc. The previous
  # version of this function used awk in a way that could silently lose the
  # alias block if both markers got out of sync. The new approach is paranoid:
  #   1. backup (kept indefinitely in ~/.zshrc.backups/)
  #   2. only strip an existing block if BOTH markers are present (otherwise
  #      a stray begin without end could nuke half the file)
  #   3. append the new block fresh
  #   4. verify the alias loads in a fresh zsh
  #   5. on failure, restore from backup
  local backup_dir="$HOME/.zshrc.backups"
  mkdir -p "$backup_dir"
  local backup="$backup_dir/zshrc.$(date +%Y%m%d-%H%M%S)"
  cp "$ZSHRC" "$backup"

  local has_begin has_end
  has_begin=$(grep -cF "$ALIAS_BEGIN" "$ZSHRC")
  has_end=$(grep -cF "$ALIAS_END" "$ZSHRC")

  # Build the cleaned (without our block) intermediate file.
  local tmpfile
  tmpfile=$(mktemp)

  if [ "$has_begin" -gt 0 ] && [ "$has_end" -gt 0 ]; then
    # Both markers present: safe to strip the range.
    sed "/$ALIAS_BEGIN/,/$ALIAS_END/d" "$ZSHRC" > "$tmpfile"
    # Sanity: stripped file shouldn't be larger than original (sed wouldn't add).
    local orig_sz strip_sz
    orig_sz=$(wc -c < "$ZSHRC")
    strip_sz=$(wc -c < "$tmpfile")
    if [ "$strip_sz" -gt "$orig_sz" ]; then
      echo "${C_YELLOW}!${C_RESET} sed produced a larger file than the original. Aborting (no changes made; backup at $backup)."
      rm -f "$tmpfile"
      return 1
    fi
  elif [ "$has_begin" -gt 0 ] || [ "$has_end" -gt 0 ]; then
    # Only one marker present — that's a malformed prior state. Don't touch
    # the existing content; just append, and warn so you can clean up later.
    cp "$ZSHRC" "$tmpfile"
    echo "${C_YELLOW}!${C_RESET} $ZSHRC has a partial alias block (only one of the markers is present)."
    echo "  Leaving existing content untouched and appending fresh block below."
    echo "  You may want to clean up the orphan marker manually."
  else
    # No markers — clean append.
    cp "$ZSHRC" "$tmpfile"
  fi

  # Append the (new) block.
  {
    echo ""
    echo "$block"
  } >> "$tmpfile"

  # Verify the result has the alias line.
  if ! grep -qF "alias agent-nexus=" "$tmpfile"; then
    echo "${C_YELLOW}!${C_RESET} Internal error: prepared file doesn't contain the alias. Backup preserved at $backup."
    rm -f "$tmpfile"
    return 1
  fi

  # Atomically swap.
  mv "$tmpfile" "$ZSHRC"

  # End-to-end verification: spawn a fresh zsh and check the alias loads.
  if zsh -i -c "alias agent-nexus" >/dev/null 2>&1; then
    echo "${C_GREEN}✓${C_RESET} Alias 'agent-nexus' installed in $ZSHRC$([ -n "$CFG_MACHINE_NAME" ] && printf " (plus '%s-nexus' / '%s-sessions')" "$(alias_prefix)" "$(alias_prefix)")"
    echo "  ${C_DIM}Backup: $backup${C_RESET}"
  else
    echo "${C_YELLOW}!${C_RESET} Verification failed — alias didn't load in a fresh zsh."
    echo "  Restoring from backup: $backup"
    cp "$backup" "$ZSHRC"
    return 1
  fi
}

# ---------------------------------------------
# Main
# ---------------------------------------------

# --show-config: print current config and exit. Cleanly, no preamble.
if [ "${1:-}" = "--show-config" ]; then
  if [ -f "$SESSIONS_FILE" ]; then
    parse_sessions_file
    echo "machine-name:           $CFG_MACHINE_NAME"
    echo "projects-root:          $CFG_PROJECTS_ROOT"
    echo "tasks-file:             $CFG_TASKS_FILE"
    echo "enable-remote-control:  $CFG_ENABLE_REMOTE_CONTROL"
    echo "permission-mode:        ${CFG_PERMISSION_MODE:-bypass}"
    echo "enable-chrome:          ${CFG_ENABLE_CHROME:-yes}"
    echo "boot-restore:           ${CFG_BOOT_RESTORE:-off}"
    echo "catchup-hours:          ${CFG_CATCHUP_HOURS:-12}"
    echo "notify-command:         ${CFG_NOTIFY_COMMAND:-(off)}"
    echo "notify-level:           ${CFG_NOTIFY_LEVEL:-failures}"
    echo "keep-alive:             ${CFG_KEEP_ALIVE:-on}"
    echo "stale-weeks:            ${CFG_STALE_WEEKS:-3}"
    echo "update-require-signed:  ${CFG_UPDATE_REQUIRE_SIGNED:-off}"
    echo "active sessions:        ${#ACTIVE_NAMES[@]}"
    echo "archived sessions:      ${#ARCHIVED_NAMES[@]}"
  else
    echo "No sessions.md exists yet at $SESSIONS_FILE"
    echo "Run setup.sh (no flags) to create one."
    exit 1
  fi
  exit 0
fi

# --relink: re-point the aliases at THIS copy and exit, without the wizard.
# Must be here, before the first prompt: the whole point is that moving the
# install directory should not require answering seven unrelated questions.
if [ "$RELINK_ONLY" = "1" ]; then
  [ -f "$SESSIONS_FILE" ] && parse_sessions_file
  install_aliases || exit 1
  echo ""
  echo "Aliases now run: $SCRIPT_DIR/sessions.sh"
  echo "Registry in use: $SESSIONS_FILE"
  echo "Open a new terminal, or run 'source ~/.zshrc'. Already-open shells keep"
  echo "the old alias baked in."
  exit 0
fi

section_divider "$C_CYAN" "Agent Nexus — Setup (Claude Code on an always-on Mac)"
echo ""
echo "What this script will do:"
echo ""
echo "  1. Ask for your machine name, projects-root path, the"
echo "     session launch defaults (permission mode, chrome,"
echo "     remote-control), and a few other flags — and write them"
echo "     into the ## Config block at the top of sessions.md."
echo ""
echo "  2. Optionally append a zsh alias to ~/.zshrc (between markers,"
echo "     easy to remove later):"
echo "       <prefix>-nexus       Single entry point. Subcommands:"
echo "                              new      create + register a session"
echo "                              sync     interactive picker"
echo "                              update   regenerate tasks.json"
echo "                              restore  recreate active sessions in tmux"
echo "                              setup    re-run this script"
echo "                              help     show usage"
echo ""
echo "  3. Print VS Code keybindings JSON for you to copy into"
echo "     your laptop's keybindings.json (this script runs on"
echo "     the agent machine; the laptop is a different machine,"
echo "     so the snippet is printed rather than written)."
echo ""
echo "Existing ## Active / ## Standby / ## Archived entries in sessions.md"
echo "are preserved. Safe to re-run any time."
echo ""

# Fresh install: pick where the tool's DATA lives, BEFORE anything writes it.
# Data inside a git clone means `git pull` updates code around live registries
# and your real session names sit one careless commit away from a fork, so the
# recommended default is outside the clone. Writes data-dir.conf next to the
# scripts; an existing install (sessions.md or a conf already present) never
# sees this question, and its layout is never changed.
if [ ! -f "$SESSIONS_FILE" ] && [ ! -f "$SCRIPT_DIR/data-dir.conf" ] && [ -z "${AGENT_NEXUS_DATA_DIR:-}" ]; then
  section_divider "$C_BLUE" "Where should your data live?"
  echo "The tool separates its DATA (your session registry, schedules, automation"
  echo "settings) from its code. Pick where the data goes:"
  echo ""
  DD_DEFAULT="$HOME/.agent-nexus/data"
  DD_CHOICE=$(pick_option "Data directory" \
    "$DD_DEFAULT   (recommended: survives re-clones, never lands in a commit)" \
    "Next to the scripts, inside this folder (the classic layout)" \
    "Somewhere else (type a path)")
  DD_PICKED=""
  case "$DD_CHOICE" in
    "$DD_DEFAULT"*) DD_PICKED="$DD_DEFAULT" ;;
    "Somewhere else"*)
      read -r -p "Full path for the data directory: " DD_IN
      DD_IN="${DD_IN/#\~/$HOME}"
      [ -n "$DD_IN" ] && DD_PICKED="$DD_IN" ;;
    *) ;;   # classic layout: no conf file, data stays beside the scripts
  esac
  if [ -n "$DD_PICKED" ]; then
    if mkdir -p "$DD_PICKED" 2>/dev/null; then
      printf '%s\n' "$DD_PICKED" > "$SCRIPT_DIR/data-dir.conf"
      DATA_DIR="$DD_PICKED"
      SESSIONS_FILE="${AGENT_NEXUS_SESSIONS_FILE:-$DATA_DIR/sessions.md}"
      # Re-point the data files sessions.sh resolved at source time, so THIS
      # run writes where future runs will read.
      MANAGED_FILE="${AGENT_NEXUS_MANAGED_FILE:-$DATA_DIR/managed-sessions.md}"
      SCHEDULED_TASKS_FILE="${AGENT_NEXUS_TASKS_FILE:-$DATA_DIR/scheduled-tasks.md}"
      echo "  ${C_GREEN}✓${C_RESET} data-dir.conf → $DD_PICKED"
    else
      echo "  ${C_YELLOW}!${C_RESET} could not create '$DD_PICKED'; data stays next to the scripts."
    fi
  else
    echo "  Data stays next to the scripts. Movable later: put a path in"
    echo "  $SCRIPT_DIR/data-dir.conf and move the .md files there."
  fi
  echo ""
fi

parse_sessions_file

# If a config already exists, show it and ask whether to keep/redo/quit. This is
# the overwrite guard: an existing install sees its current values BEFORE setup
# touches anything, and "Keep" round-trips them unchanged.
SKIP_CONFIG_PROMPTS=0
if [ -n "$CFG_MACHINE_NAME$CFG_PROJECTS_ROOT$CFG_TASKS_FILE$CFG_ENABLE_REMOTE_CONTROL$CFG_PERMISSION_MODE$CFG_ENABLE_CHROME$CFG_BOOT_RESTORE$CFG_CATCHUP_HOURS$CFG_KEEP_ALIVE" ]; then
  section_divider "$C_BLUE" "Existing config found in sessions.md"
  echo "  ${C_YELLOW}This machine is already configured.${C_RESET} Re-running the prompts will"
  echo "  OVERWRITE these values (existing ones are shown as the defaults, so"
  echo "  pressing Enter keeps each). Your ## Active / ## Archived sessions are"
  echo "  never touched. Current config:"
  echo ""
  echo "  machine-name:           $CFG_MACHINE_NAME"
  echo "  projects-root:          $CFG_PROJECTS_ROOT"
  echo "  tasks-file:             $CFG_TASKS_FILE"
  echo "  enable-remote-control:  $CFG_ENABLE_REMOTE_CONTROL"
  echo "  permission-mode:        ${CFG_PERMISSION_MODE:-bypass}"
  echo "  enable-chrome:          ${CFG_ENABLE_CHROME:-yes}"
  echo "  boot-restore:           ${CFG_BOOT_RESTORE:-off}"
  echo "  catchup-hours:          ${CFG_CATCHUP_HOURS:-12}"
  echo "  notify-command:         ${CFG_NOTIFY_COMMAND:-(off)}"
  echo "  notify-level:           ${CFG_NOTIFY_LEVEL:-failures}"
  echo "  keep-alive:             ${CFG_KEEP_ALIVE:-on}"
  echo "  stale-weeks:            ${CFG_STALE_WEEKS:-3}"
  echo "  update-require-signed:  ${CFG_UPDATE_REQUIRE_SIGNED:-off}"
  echo ""
  echo "Active sessions: ${#ACTIVE_NAMES[@]}    Archived: ${#ARCHIVED_NAMES[@]}"
  echo ""
  CFG_CHOICE=$(pick_option "What now?" \
    "Keep existing config — skip to alias / fzf / keybindings setup" \
    "Re-run interactive prompts — existing values shown as defaults" \
    "Quit setup — leaves everything untouched")
  case "$CFG_CHOICE" in
    "Keep"*) SKIP_CONFIG_PROMPTS=1 ;;
    "Re-run"*) SKIP_CONFIG_PROMPTS=0 ;;
    "Quit"*) echo "Quit. No changes made."; exit 0 ;;
    *) echo "Unknown choice — defaulting to keep."; SKIP_CONFIG_PROMPTS=1 ;;
  esac
  echo ""
fi

if [ "$SKIP_CONFIG_PROMPTS" -eq 1 ]; then
  # Skip the config prompts entirely. Existing CFG_* values are kept;
  # write_sessions_file below will round-trip them unchanged.
  :
else

section_divider "$C_BLUE" "Configure (Enter on each prompt to keep the default)"

# Machine name
DEFAULT_MACHINE="$CFG_MACHINE_NAME"
echo "Machine / agent name (optional)."
echo "  The command is agent-nexus everywhere; a machine name ADDS personal"
echo "  aliases like rocky-nexus / rocky-sessions beside it. Blank is fine."
NEW_MACHINE=$(prompt_with_default "Machine name" "$DEFAULT_MACHINE")
CFG_MACHINE_NAME="$NEW_MACHINE"
echo ""

# Projects root
DEFAULT_PROJECTS_ROOT="$CFG_PROJECTS_ROOT"
if [ -z "$DEFAULT_PROJECTS_ROOT" ]; then
  if [ -d "$HOME/Projects" ]; then
    DEFAULT_PROJECTS_ROOT="$HOME/Projects"
  elif [ -d "$HOME/Dropbox" ]; then
    DEFAULT_PROJECTS_ROOT="$HOME/Dropbox"
  else
    DEFAULT_PROJECTS_ROOT="$HOME/Projects"
  fi
fi
echo "Projects root — the directory the new-session script picks projects from."
NEW_ROOT=$(prompt_with_default "Projects root" "$DEFAULT_PROJECTS_ROOT")
NEW_ROOT="${NEW_ROOT/#\~/$HOME}"
CFG_PROJECTS_ROOT="$NEW_ROOT"
echo ""

# tasks.json path
DEFAULT_TASKS_FILE="$CFG_TASKS_FILE"
[ -z "$DEFAULT_TASKS_FILE" ] && DEFAULT_TASKS_FILE="$HOME/.vscode/tasks.json"
echo "VS Code tasks file — auto-generated by the updater. Default is fine for"
echo "most setups."
NEW_TASKS=$(prompt_with_default "tasks.json path" "$DEFAULT_TASKS_FILE")
NEW_TASKS="${NEW_TASKS/#\~/$HOME}"
CFG_TASKS_FILE="$NEW_TASKS"
echo ""

# enable-remote-control
DEFAULT_RC="$CFG_ENABLE_REMOTE_CONTROL"
[ -z "$DEFAULT_RC" ] && DEFAULT_RC="no"
echo "Run /remote-control inside Claude after each new session?"
echo "  This is a custom Claude Code slash command for enabling remote control."
echo "  If you don't have it set up, leave this as 'no'. You can change it later"
echo "  by editing sessions.md or re-running setup.sh."
NEW_RC=$(pick_yesno "enable-remote-control?" "Yes - run /remote-control after each launch" "No - leave it off" "$DEFAULT_RC")
case "$NEW_RC" in
  yes) CFG_ENABLE_REMOTE_CONTROL="yes" ;;
  no)  CFG_ENABLE_REMOTE_CONTROL="no" ;;
  *)   CFG_ENABLE_REMOTE_CONTROL="$DEFAULT_RC" ;;   # cancelled: keep what was there
esac
echo ""

# ---------------------------------------------
# Session launch defaults (permission-mode + chrome)
# ---------------------------------------------
# These become the flags every session launches with. A fresh install proposes
# 'auto' (a safety classifier vets each action) as the permission mode and
# chrome on; you can accept both with one key, or configure each. Existing
# values are proposed as-is so a re-run doesn't silently change your posture.
section_divider "$C_BLUE" "Session launch defaults"
PROP_PM="${CFG_PERMISSION_MODE:-auto}"
PROP_CH="${CFG_ENABLE_CHROME:-yes}"
echo "Every session launches with a permission mode and (optionally) --chrome."
echo "These are the DEFAULTS for new sessions; a managed automation session can"
echo "override its own permission mode, and 'new' lets you override for one"
echo "session. You can change all of this later in the menu (Session launch"
echo "settings) or by re-running setup."
echo ""
echo "  permission-mode  — how much each session's actions are gated:"
echo "      bypass  = --dangerously-skip-permissions. Auto-approves everything."
echo "                Nothing ever pauses, so unattended scheduled/bus runs never"
echo "                stall. Least safe for what an agent can do on its own."
echo "      auto    = --permission-mode auto. A second Claude vets each action for"
echo "                safety. Safer, but may pause on a risky action (fine for the"
echo "                interactive sessions you're watching; automation targets set"
echo "                their own mode, so this default won't stall them)."
echo "      ask     = normal prompting for each action. Safest when you're present;"
echo "                an unattended run would hang at the prompt."
echo "  enable-chrome    — launch with --chrome (browser + computer-use tools)."
echo ""
echo "Proposed defaults:  permission-mode=${C_BOLD}$PROP_PM${C_RESET}   enable-chrome=${C_BOLD}$PROP_CH${C_RESET}"
echo ""
LAUNCH_CHOICE=$(pick_option "Launch defaults" \
  "Accept these (permission-mode=$PROP_PM, chrome=$PROP_CH)" \
  "Configure each one")
case "$LAUNCH_CHOICE" in
  "Configure each"*)
    echo ""
    NEW_PM=$(pick_option "permission-mode" \
      "bypass - auto-approve everything; never pauses" \
      "auto - a second Claude vets each action" \
      "ask - prompt for every action")
    case "$NEW_PM" in
      bypass*) CFG_PERMISSION_MODE="bypass" ;;
      auto*)   CFG_PERMISSION_MODE="auto" ;;
      ask*)    CFG_PERMISSION_MODE="ask" ;;
      *)       echo "  (nothing picked, keeping '$PROP_PM')"; CFG_PERMISSION_MODE="$PROP_PM" ;;
    esac
    echo ""
    NEW_CH=$(pick_yesno "enable-chrome?" "Yes - launch with --chrome" "No - no browser tools" "$PROP_CH")
    case "$NEW_CH" in
      yes) CFG_ENABLE_CHROME="yes" ;;
      no)  CFG_ENABLE_CHROME="no" ;;
      *)   CFG_ENABLE_CHROME="$PROP_CH" ;;
    esac ;;
  *)
    CFG_PERMISSION_MODE="$PROP_PM"
    CFG_ENABLE_CHROME="$PROP_CH" ;;
esac
echo ""
echo "  ${C_GREEN}✓${C_RESET} permission-mode=$CFG_PERMISSION_MODE, enable-chrome=$CFG_ENABLE_CHROME"
if [ "$CFG_PERMISSION_MODE" = "auto" ]; then
  echo "  ${C_DIM}Note: 'auto' can pause on risky actions. A managed session that runs"
  echo "  unattended should be set to 'bypass' (it's the default when you promote one).${C_RESET}"
fi
echo ""

# ---------------------------------------------
# Boot-restore (auto-restore after reboot)
# ---------------------------------------------
section_divider "$C_BLUE" "Auto-restore after a reboot (boot-restore)"
DEFAULT_BR="${CFG_BOOT_RESTORE:-off}"
echo "After a reboot, tmux sessions (and the Claude inside each) are gone until"
echo "restored. With boot-restore ON, the scheduler's first tick after each boot"
echo "automatically relaunches every Active + managed session, resuming each"
echo "conversation where it left off. One-shot per boot: sessions you close on"
echo "purpose later stay closed."
echo ""
echo "  Requires: the launchd ticker (offered below) and, on a headless Mac,"
echo "  macOS auto-login (System Settings > Users & Groups), since sessions"
echo "  need your GUI login session to launch."
echo ""
NEW_BR=$(prompt_with_default "boot-restore (on/off)" "$DEFAULT_BR")
case "$NEW_BR" in
  on|ON|y|Y|yes|YES) CFG_BOOT_RESTORE="on" ;;
  *) CFG_BOOT_RESTORE="off" ;;
esac
# Arming stamps the CURRENT boot as seen, so enabling never triggers a full
# fleet relaunch on the next tick; only a REAL later reboot sweeps.
if [ "$CFG_BOOT_RESTORE" = "on" ] && [ "$DEFAULT_BR" != "on" ]; then
  boot_restore_mark_done 2>/dev/null
  echo "  ${C_GREEN}✓${C_RESET} armed for the NEXT reboot (nothing relaunches now)"
fi
echo ""

# ---------------------------------------------
# Missed-run catch-up window
# ---------------------------------------------
section_divider "$C_BLUE" "Missed-run catch-up window (catchup-hours)"
DEFAULT_CU="${CFG_CATCHUP_HOURS:-12}"
echo "If the machine sleeps through a scheduled run, the run still fires late,"
echo "as long as it's less than this many hours overdue. Anything older is"
echo "skipped (logged SKIP) so a Saturday-morning job can't fire Tuesday night."
echo "Raise it if you'd rather have very late runs than skipped ones."
echo ""
NEW_CU=$(prompt_with_default "catchup-hours (whole hours, > 0)" "$DEFAULT_CU")
if [[ "$NEW_CU" =~ ^[0-9]+$ ]] && [ "$NEW_CU" -gt 0 ]; then
  CFG_CATCHUP_HOURS="$NEW_CU"
else
  echo "  (not a positive whole number; keeping $DEFAULT_CU)"
  CFG_CATCHUP_HOURS="$DEFAULT_CU"
fi
echo ""

# ---------------------------------------------
# Keep-alive (managed sessions stay alive)
# ---------------------------------------------
section_divider "$C_BLUE" "Keep managed sessions alive (keep-alive)"
DEFAULT_KA="${CFG_KEEP_ALIVE:-on}"
echo "Managed sessions are your automation targets (scheduled tasks, the agent"
echo "bus). With keep-alive ON, every 15-minute tick relaunches any managed"
echo "session whose Claude has died, so a crash never silently kills your"
echo "automation. Note: killing a managed session's tmux on purpose brings it"
echo "back within 15 minutes unless that session's own keep-alive is set to"
echo "off (or you un-manage it). Recommended: on."
echo ""
NEW_KA=$(prompt_with_default "keep-alive (on/off)" "$DEFAULT_KA")
case "$NEW_KA" in
  off|OFF|n|N|no|NO) CFG_KEEP_ALIVE="off" ;;
  *) CFG_KEEP_ALIVE="on" ;;
esac
echo ""

# ---------------------------------------------
# Staleness suggestions
# ---------------------------------------------
section_divider "$C_BLUE" "Staleness suggestions (stale-weeks)"
echo "The Sessions hub can flag Active sessions whose conversation hasn't been"
echo "touched in a while and offer to archive them in one step (a suggestion"
echo "only - nothing is archived without your yes). Set how many weeks counts"
echo "as stale, or 'off' to disable the suggestion."
echo ""
NEW_SW=$(prompt_with_default "stale-weeks (number, or off)" "${CFG_STALE_WEEKS:-3}")
case "$NEW_SW" in
  off|OFF|0) CFG_STALE_WEEKS="off" ;;
  *) if printf '%s' "$NEW_SW" | grep -qE '^[0-9]+$'; then CFG_STALE_WEEKS="$NEW_SW"; else CFG_STALE_WEEKS="3"; fi ;;
esac
echo ""

# ---------------------------------------------
# Notifications (optional)
# ---------------------------------------------
section_divider "$C_BLUE" "Notifications (optional)"
echo "When something needs a human - a session logged out of Claude, a managed"
echo "session that can't be healed, a failed agent-bus request - the system can"
echo "run a command to alert you (it gets the message as its argument, throttled"
echo "to once per 4h per condition). A ready-made Telegram sender ships as"
echo "notify-telegram.sh. Easiest path: AFTER setup, run the guided flow"
echo "  agent-nexus setup-telegram"
echo "(it creates everything and tests it). Leave blank to keep notifications"
echo "off; configure later in Settings > notify-command."
echo ""
echo "${C_BOLD}Two-way control from your phone${C_RESET} is a separate, optional step:"
echo "  agent-nexus setup-telegram-control"
echo "That uses a SECOND bot and lets you send a fixed list of commands"
echo "(/status, /sessions, /heal, /launch, /login, /code) to THIS TOOL - never"
echo "free text into a session. It also installs an always-on poller so a"
echo "command is answered in about a second rather than on the 15-minute tick,"
echo "which matters because the whole point is reaching this machine when its"
echo "sessions are already down."
echo ""
NEW_NC=$(prompt_with_default "notify-command (blank = off)" "${CFG_NOTIFY_COMMAND:-}")
CFG_NOTIFY_COMMAND="$NEW_NC"
echo ""
echo "notify-level controls WHAT gets pushed through that command:"
echo "  failures = only problems that need a human (recommended)"
echo "  all      = also a one-line report after every scheduled run"
echo "(Everything is always recorded in the in-app logs either way; see the"
echo "menu under Tools and maintenance > Alerts and run reports.)"
NEW_NL=$(prompt_with_default "notify-level (failures/all)" "${CFG_NOTIFY_LEVEL:-failures}")
case "$NEW_NL" in all|ALL|All) CFG_NOTIFY_LEVEL="all" ;; *) CFG_NOTIFY_LEVEL="failures" ;; esac
echo ""

fi  # end of SKIP_CONFIG_PROMPTS conditional

# Write sessions.md
write_sessions_file
echo "Wrote config to $SESSIONS_FILE"
echo ""

# Aliases
PREFIX=$(alias_prefix)
section_divider "$C_GREEN" "Zsh aliases"
echo "Without an alias, you'd run the script by typing the full path:"
echo "  bash \"$SCRIPT_DIR/sessions.sh\" <subcommand>"
echo ""
echo "With the alias, you'd just type a short command:"
echo ""
echo "  ${PREFIX}-nexus             Show the menu, or pass a subcommand:"
echo "  ${PREFIX}-nexus new         Start a new tmux + Claude session"
echo "  ${PREFIX}-nexus sync        Open the interactive picker"
echo "  ${PREFIX}-sessions update   Regenerate tasks.json from sessions.md"
echo "  ${PREFIX}-sessions restore  Recreate all active sessions in tmux"
echo ""
echo "They get added to ~/.zshrc between markers (\"$ALIAS_BEGIN\" ..."
echo "\"$ALIAS_END\") so they're easy to remove later."
echo ""
ADD=$(pick_yesno "Add the aliases to ~/.zshrc now?" "Yes - add them" "No - skip" yes)

if [ "$ADD" = "yes" ]; then
  install_aliases
  echo ""
  echo "Open a new terminal, or run 'source ~/.zshrc', to activate the aliases."
else
  echo "Skipped. You can re-run setup.sh any time to add them."
fi

section_divider "$C_YELLOW" "VS Code keybindings (laptop side)"
echo "On your laptop (where VS Code runs), open the keybindings"
echo "file — Cmd+Shift+P → 'Open Keyboard Shortcuts (JSON)' —"
echo "and add these entries to the array. Cmd+Shift+B is bound"
echo "to the default build task by default and usually doesn't"
echo "need an explicit entry, but it's included for clarity."
echo ""
cat <<'EOF'
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
EOF
echo ""
echo "  cmd+shift+b → runs the default build task ('Reconnect All' — opens"
echo "                every active session as an editor tab)."
echo "  cmd+alt+e   → opens sessions.md for editing."
echo "  cmd+alt+r   → opens VS Code's task picker. Type 'Reconnect' to see"
echo "                per-project options like 'Reconnect Empathic Communication'."
echo "                Useful for opening just one project's tabs into a"
echo "                specific split-pane group."
echo ""
echo "These bind by task NAME, so they keep working even after"
echo "you re-run setup.sh or the updater regenerates tasks.json."

# fzf installation check
section_divider "$C_GREEN" "Optional: fzf for nicer menu navigation"
if command -v fzf >/dev/null 2>&1; then
  echo "${C_GREEN}✓${C_RESET} fzf is already installed."
  echo "  (Menus and pickers will use it automatically.)"
else
  echo "fzf is not installed. Without it, menus use numbered prompts."
  echo "With it, you get arrow-key navigation + fuzzy filtering."
  echo ""
  if command -v brew >/dev/null 2>&1; then
    INSTALL_FZF=$(pick_yesno "Install fzf via Homebrew now?" "Yes - brew install fzf" "No - keep numbered prompts" yes)
    if [ "$INSTALL_FZF" = "yes" ]; then
      brew install fzf
    fi
  else
    echo "Homebrew not found. Install it from https://brew.sh, then run:"
    echo "  brew install fzf"
  fi
fi

section_divider "$C_GREEN" "Optional: agent-bus SSH door"
echo "Lets an agent on ANOTHER machine hand tasks to a managed session here over"
echo "SSH, restricted to only 'submit' and 'process-inbox' (nothing else). Skip"
echo "this if you don't need cross-machine handoff yet; you can enable it later"
echo "with:  agent-nexus install-bus-key"
echo ""
if [ -f "$SCRIPT_DIR/bus-ssh-wrapper.sh" ]; then
  SETUP_BUSKEY=$(pick_yesno "Set up the agent-bus SSH door now?" "Yes - set it up" "No - later" no)
  if [ "$SETUP_BUSKEY" = "yes" ]; then
    cmd_install_bus_key
  fi
else
  echo "${C_DIM}(bus-ssh-wrapper.sh not found next to the scripts; skipping.)${C_RESET}"
fi

section_divider "$C_GREEN" "Optional: the scheduler + agent bus"
echo "Installs one launchd agent that ticks every 15 minutes: it fires your timed"
echo "tasks into sessions and drains the agent-bus queue. Skip if you only want the"
echo "session manager for now; enable it later from the menu (Automation > Schedule"
echo "tasks) or with:  agent-nexus install-scheduler"
echo ""
if declare -f cmd_install_scheduler >/dev/null 2>&1; then
  SCHED_DEFAULT="n"
  [ "${CFG_BOOT_RESTORE:-off}" = "on" ] && SCHED_DEFAULT="y" \
    && echo "${C_YELLOW}You enabled boot-restore above — it needs this ticker to fire.${C_RESET}"
  case "$SCHED_DEFAULT" in y) SCHED_DEFAULT="yes" ;; *) SCHED_DEFAULT="no" ;; esac
  SETUP_SCHED=$(pick_yesno "Install the scheduler now?" "Yes - install the 15-minute ticker" "No - later" "$SCHED_DEFAULT")
  if [ "$SETUP_SCHED" = "yes" ]; then
    cmd_install_scheduler
  elif [ "${CFG_BOOT_RESTORE:-off}" = "on" ]; then
    echo "${C_YELLOW}!${C_RESET} boot-restore is ON but the ticker isn't installed — it will never"
    echo "  fire until you install it: agent-nexus install-scheduler"
  fi
fi

section_divider "$C_CYAN" "Setup complete"
echo "${C_DIM}You can re-run this script any time. It defaults to keeping your existing config.${C_RESET}"
echo "${C_DIM}View current config without prompts:  bash setup.sh --show-config${C_RESET}"
