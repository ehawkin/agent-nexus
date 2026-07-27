#!/bin/bash
# notify-telegram.sh "<message>" — send yourself a Telegram message via a bot.
# This is the ready-made sender for Agent Nexus's notify-command setting.
#
# One-time setup (~5 minutes, done from your phone or any Telegram client):
#   1. Open Telegram, search for @BotFather, send: /newbot
#      Pick a name and a username; BotFather replies with a TOKEN like
#      123456789:AAF...xyz. Keep it secret (it IS the bot).
#   2. Open a chat with your new bot and send it any message
#      (bots may only message people who messaged them first).
#   3. Get your chat id:
#      curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | grep -o '"id":[0-9]*' | head -1
#      (the number after "id": is your chat id)
#   4. Create the credentials file (outside the repo and Dropbox), private
#      from the first byte (matters on a shared machine):
#        mkdir -p ~/.agent-nexus && chmod 700 ~/.agent-nexus
#        ( umask 077; printf 'TELEGRAM_BOT_TOKEN=<token>\nTELEGRAM_CHAT_ID=<chat id>\n' > ~/.agent-nexus/telegram.env )
#        chmod 600 ~/.agent-nexus/telegram.env
#      (Or just run the guided setup: <machine>-nexus setup-telegram.)
#   5. In Agent Nexus: Settings > notify-command, set it to:
#        bash "<full path to this script>"
#   Test any time:  bash notify-telegram.sh "hello from the machine"
#
# Test seam: TELEGRAM_ENV_FILE overrides the env file location.

# Same state-dir resolution as sessions.sh: new installs use ~/.agent-nexus;
# an install with the historical ~/.rocky-sessions keeps it.
_STATE_DIR="$HOME/.agent-nexus"
[ -d "$HOME/.rocky-sessions" ] && _STATE_DIR="$HOME/.rocky-sessions"
[ -n "${AGENT_NEXUS_STATE_DIR:-}" ] && _STATE_DIR="$AGENT_NEXUS_STATE_DIR"
ENV_FILE="${TELEGRAM_ENV_FILE:-$_STATE_DIR/telegram.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "notify-telegram: $ENV_FILE missing - see this script's header for setup" >&2
  exit 1
fi
. "$ENV_FILE"
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  echo "notify-telegram: TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID unset in $ENV_FILE" >&2
  exit 1
fi
MSG="${1:-Agent Nexus alert (no message given)}"
# The token goes to curl through a config file on STDIN, never in argv: an
# argv URL is visible to every local user in `ps -axww` for the length of the
# request. printf is a shell builtin, so it has no argv of its own.
printf 'url = "https://api.telegram.org/bot%s/sendMessage"\n' "$TELEGRAM_BOT_TOKEN" \
  | curl -sS --max-time 10 -X POST -K - \
      --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
      --data-urlencode "text=${MSG}" >/dev/null
