#!/usr/bin/env bash
# headersHelper MCP serveru ProjectCreator: vypíše JSON s hlavičkou Authorization z lokálního souboru s tokenem.
# Claude Code ho spouští při každém připojení (start session, /mcp reconnect, opakování po 401/403), limit 10 s.
# Bez platného tokenu skončí chybou s návodem (stderr) – server se pak ukáže jako nepřipojený, nic se neposílá.
. "$(dirname "$0")/pc-common.sh"

if ! pc_read_token; then
  echo "ProjectCreator: chybí platný token v $PC_TOKEN_FILE – spusť /projectcreator:setup." >&2
  exit 1
fi
printf '{"Authorization":"Bearer %s"}\n' "$PC_TOKEN"
