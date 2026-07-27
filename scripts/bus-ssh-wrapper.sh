#!/bin/bash
# bus-ssh-wrapper.sh — forced command for a sender agent's restricted key (Agent Nexus bus door).
#
# Install (authorized_keys on the Mini; ONE line):
#   command="/path/to/bus-ssh-wrapper.sh",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty ssh-ed25519 AAAA... sender-agent
#
# Grammar (exactly two verbs; everything else rejected + logged):
#   agent-nexus process-inbox
#   agent-nexus submit --target <A-Za-z0-9-> --from <A-Za-z0-9-> <ask>
# ("rocky-sessions" is accepted as a legacy prefix so senders provisioned
# before the Agent Nexus rename keep working.)
# The ask is the remainder; it may contain spaces but NO shell metacharacters
# or newlines. It is passed through argv (never eval), so quoting tricks
# cannot become shell.
#
# Test hook: BUS_WRAPPER_DRYRUN=1 prints the parsed argv instead of executing.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSIONS_SH="$SCRIPT_DIR/sessions.sh"
# Same state-dir resolution as sessions.sh: new installs use ~/.agent-nexus;
# an install with the historical ~/.rocky-sessions keeps it.
LOGDIR="$HOME/.agent-nexus"
[ -d "$HOME/.rocky-sessions" ] && LOGDIR="$HOME/.rocky-sessions"
[ -n "${AGENT_NEXUS_STATE_DIR:-}" ] && LOGDIR="$AGENT_NEXUS_STATE_DIR"
mkdir -p "$LOGDIR" 2>/dev/null
LOG="$LOGDIR/bus.log"

log() { printf '%s %s %s\n' "$(date +%s)" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" >> "$LOG"; }
reject() { log "WRAPPER-REJECT ${SSH_ORIGINAL_COMMAND:-<empty>}"; echo "rejected" >&2; exit 1; }

run() {
  if [ "${BUS_WRAPPER_DRYRUN:-}" = "1" ]; then printf 'DRYRUN:%s\n' "$*"; exit 0; fi
  exec /bin/bash "$SESSIONS_SH" "$@"
}

CMD="${SSH_ORIGINAL_COMMAND:-}"
[ -z "$CMD" ] && reject
# no newlines, no shell metacharacters anywhere in the command
case "$CMD" in
  *$'\n'*|*';'*|*'&'*|*'|'*|*'`'*|*'$'*|*'<'*|*'>'*|*'('*|*')'*|*'\'*) reject ;;
esac

# Normalize the accepted prefixes (new + legacy) to one token, then match verbs.
PFX=""
case "$CMD" in
  "agent-nexus "*)    PFX="agent-nexus" ;;
  "rocky-sessions "*) PFX="rocky-sessions" ;;
  *) reject ;;
esac
VERB="${CMD#"$PFX" }"

if [ "$VERB" = "process-inbox" ]; then
  log "WRAPPER-OK process-inbox"
  run process-inbox
fi

# submit --target <t> --from <f> <ask...>   (ask = remainder, quotes stripped)
if printf '%s' "$VERB" | grep -qE "^submit --target [A-Za-z0-9-]+ --from [A-Za-z0-9-]+ .+"; then
  rest="${VERB#submit --target }"
  target="${rest%% *}"; rest="${rest#* }"          # past target
  rest="${rest#--from }"
  from="${rest%% *}"; ask="${rest#* }"             # past from; remainder = ask
  # strip one layer of optional surrounding quotes from the ask
  case "$ask" in
    \'*\') ask="${ask#\'}"; ask="${ask%\'}" ;;
    \"*\") ask="${ask#\"}"; ask="${ask%\"}" ;;
  esac
  [ -z "$target" ] || [ -z "$from" ] || [ -z "$ask" ] && reject
  log "WRAPPER-OK submit target=$target from=$from"
  run submit --target "$target" --from "$from" "$ask"
fi

reject
