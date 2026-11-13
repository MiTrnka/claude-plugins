#!/usr/bin/env bash
# SessionStart hook: co v ProjectCreatoru čeká na tohoto AI agenta v projektu navázaném na repo.
# Výstup (prostý text na stdout) přidá Claude Code do kontextu. Bez navázaného repa, bez tokenu, při chybě
# sítě nebo serveru MLČÍ a vždy končí 0 – nikdy neblokuje start session.
# Od pluginu 1.0.4: session, která startuje (nebo se obnovuje), PŘEVEZME hlídání zpráv agenta v projektu
# (POST /api/agent/listen). Starší otevřená session tím hlídání ztratí – „naposledy otevřená session vyhrává“.
. "$(dirname "$0")/pc-common.sh"

input=""
[ -t 0 ] || input=$(cat 2>/dev/null)
session=$(pc_clean_session "$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)")
[ -n "$session" ] || session=$(pc_clean_session "$CLAUDE_CODE_SESSION_ID")

pc_find_link || exit 0
pc_read_token || exit 0

if [ -n "$session" ]; then
  pc_post "/api/agent/listen?project=$PC_PROJECT&session=$session" 4
  # Tahle session hlídání převzala → případná stará značka „hlídá jiná session“ už neplatí.
  if [ "$PC_CODE" = "200" ]; then
    pc_monitor_files "$PC_PROJECT" "$session"
    rm -f "$PC_MONITOR_LOST" 2>/dev/null
  fi
fi

pc_get "/api/agent/status?project=$PC_PROJECT" 4
[ "$PC_CODE" = "200" ] || exit 0
case "$PC_BODY" in
  *[![:space:]]*)
    printf '%s\n' "$PC_BODY"
    printf '%s\n' "(Plugin projectcreator: postupuj podle skillu projectcreator:komunikace-agentu. Tooly ProjectCreatoru jsou mcp__plugin_projectcreator_projectcreator__*.)"
    ;;
esac

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
root=$(printf '%s' "$root" | sed 's|\\|/|g')
proj="${PC_LINK_FILE%/.claude/projectcreator.json}"
takeover="bash \"$root/scripts/monitor.sh\" \"$proj\" 1790 \"$session\" claim"

# Claude Desktop (záložka Code) monitory pluginů NESPOUŠTÍ (ověřeno 2026-11-09, engine 2.1.317) – agent by se
# o nové zprávě dozvěděl až při příštím startu session. Proto mu hook řekne, ať si hlídač pustí sám nástrojem
# Monitor (ten trvá nejvýš 30 min, pak ho agent spustí znovu). V terminálovém `claude` běží monitor pluginu sám.
# Pojistka od 1.0.6: když se tenhle pokyn k agentovi nedostane (obnovená session) nebo hlídač po vypršení nespustí
# znovu, připomene mu to prompt-check.sh (UserPromptSubmit) podle známky života hlídače.
if [ "$CLAUDE_CODE_ENTRYPOINT" = "claude-desktop" ]; then
  cmd="bash \"$root/scripts/monitor.sh\" \"$proj\" 1790 \"$session\""
  printf '%s\n' "ProjectCreator $PC_PROJECT – hlídač zpráv: Claude Desktop monitory pluginů nespouští, zapni si ho sám hned při první odpovědi uživateli (jen čte, bez ptaní). Nástroj Monitor (je odložený → nejdřív ToolSearch \"select:Monitor\") s parametry: command = $cmd ; description = \"ProjectCreator $PC_PROJECT: zprávy AI agentů\" ; timeout_ms = 1800000. Když monitor skončí nebo vyprší, spusť ho znovu stejně (dokud session běží) – KROMĚ případu, kdy skončil řádkem „hlídání zpráv převzala jiná session“: pak ho už nespouštěj a uživateli to jednou řekni. Každý jeho řádek je upozornění → postupuj podle skillu projectcreator:komunikace-agentu. Uživateli zapnutí jednou krátce zmiň, opakované spuštění už neohlašuj."
fi
[ -n "$session" ] && printf '%s\n' "(ProjectCreator $PC_PROJECT: hlídání zpráv teď drží tahle session; když pak uživatel otevře jinou session v tomto projektu, převezme ho ona. Na pokyn „hlídej zprávy tady“ ho převezmi zpět nástrojem Monitor s command = $takeover , description a timeout_ms jako výše.)"
exit 0
