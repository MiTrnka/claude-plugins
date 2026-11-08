#!/usr/bin/env bash
# SessionStart hook: co v ProjectCreatoru čeká na tohoto AI agenta v projektu navázaném na repo.
# Výstup (prostý text na stdout) přidá Claude Code do kontextu. Bez navázaného repa, bez tokenu, při chybě
# sítě nebo serveru MLČÍ a vždy končí 0 – nikdy neblokuje start session.
. "$(dirname "$0")/pc-common.sh"

pc_find_link || exit 0
pc_read_token || exit 0
pc_get "/api/agent/status?project=$PC_PROJECT" 5
[ "$PC_CODE" = "200" ] || exit 0
case "$PC_BODY" in
  *[![:space:]]*) ;;
  *) exit 0 ;;
esac
printf '%s\n' "$PC_BODY"
printf '%s\n' "(Plugin projectcreator: postupuj podle skillu projectcreator:komunikace-agentu. Tooly ProjectCreatoru jsou mcp__plugin_projectcreator_projectcreator__*.)"
exit 0
