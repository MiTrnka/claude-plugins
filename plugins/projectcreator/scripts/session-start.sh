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
  *[![:space:]]*)
    printf '%s\n' "$PC_BODY"
    printf '%s\n' "(Plugin projectcreator: postupuj podle skillu projectcreator:komunikace-agentu. Tooly ProjectCreatoru jsou mcp__plugin_projectcreator_projectcreator__*.)"
    ;;
esac

# Claude Desktop (záložka Code) monitory pluginů NESPOUŠTÍ (ověřeno 2026-11-09, engine 2.1.317) – agent by se
# o nové zprávě dozvěděl až při příštím startu session. Proto mu hook řekne, ať si hlídač pustí sám nástrojem
# Monitor (ten trvá nejvýš 30 min, pak ho agent spustí znovu). V terminálovém `claude` běží monitor pluginu sám.
if [ "$CLAUDE_CODE_ENTRYPOINT" = "claude-desktop" ]; then
  root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
  root=$(printf '%s' "$root" | sed 's|\\|/|g')
  proj="${PC_LINK_FILE%/.claude/projectcreator.json}"
  cmd="bash \"$root/scripts/monitor.sh\" \"$proj\" 1790"
  printf '%s\n' "ProjectCreator $PC_PROJECT – hlídač zpráv: Claude Desktop monitory pluginů nespouští, zapni si ho sám hned při první odpovědi uživateli (jen čte, bez ptaní). Nástroj Monitor (je odložený → nejdřív ToolSearch \"select:Monitor\") s parametry: command = $cmd ; description = \"ProjectCreator $PC_PROJECT: zprávy AI agentů\" ; timeout_ms = 1800000. Když monitor skončí nebo vyprší, spusť ho znovu stejně (dokud session běží). Každý jeho řádek je upozornění → postupuj podle skillu projectcreator:komunikace-agentu. Uživateli to jednou krátce zmiň, opakované spuštění už neohlašuj."
fi
exit 0
