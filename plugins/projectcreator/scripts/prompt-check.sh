#!/usr/bin/env bash
# UserPromptSubmit hook: pojistka hlídače zpráv v Claude Desktopu (od pluginu 1.0.6).
# Desktop monitory pluginů nespouští, hlídač si agent pouští sám nástrojem Monitor na pokyn SessionStart hooku.
# Ten pokyn se ale k agentovi nemusí dostat (po obnovení session se výstup SessionStart hooku do kontextu nepromítl –
# ověřeno 2026-11-13) a hlídač po 30 minutách končí, takže ho agent může zapomenout spustit znovu.
# Tenhle hook proto při každé zprávě uživatele zkontroluje známku života hlídače téhle session (soubor, který
# monitor.sh průběžně obnovuje) a když chybí nebo je stará, připomene agentovi, ať hlídač spustí.
# Je čistě lokální (žádná síť), při čemkoli nejasném MLČÍ a vždy končí 0 – nikdy neblokuje zprávu uživatele.
. "$(dirname "$0")/pc-common.sh"

# Jen Claude Desktop (v terminálovém `claude` běží monitor pluginu sám). PROJECTCREATOR_REMIND=1 = vynutit (testy).
[ "$CLAUDE_CODE_ENTRYPOINT" = "claude-desktop" ] || [ "$PROJECTCREATOR_REMIND" = "1" ] || exit 0

input=""
[ -t 0 ] || input=$(cat 2>/dev/null)
session=$(pc_clean_session "$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)")
[ -n "$session" ] || session=$(pc_clean_session "$CLAUDE_CODE_SESSION_ID")
[ -n "$session" ] || exit 0

pc_find_link || exit 0
[ -f "$PC_TOKEN_FILE" ] || exit 0

pc_monitor_files "$PC_PROJECT" "$session"

# Úklid známek po dávno skončených session (best-effort).
find "$PC_MONITOR_DIR" -type f -mtime +1 -delete 2>/dev/null

# Hlídání převzala jiná session → tahle hlídat nemá, nepřipomínat.
[ -f "$PC_MONITOR_LOST" ] && exit 0
# Hlídač žije (známka mladší než 2 minuty; jedno kolo hlídače trvá nejvýš ~60 s).
[ -n "$(find "$PC_MONITOR_ALIVE" -mmin -2 2>/dev/null)" ] && exit 0

root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
root=$(printf '%s' "$root" | sed 's|\\|/|g')
proj="${PC_LINK_FILE%/.claude/projectcreator.json}"
cmd="bash \"$root/scripts/monitor.sh\" \"$proj\" 1790 \"$session\""
text="ProjectCreator $PC_PROJECT – hlídač zpráv AI agentů v této session neběží (nespuštěn po startu nebo obnovení session, nebo vypršel). Spusť ho hned, souběžně s prací na zprávě uživatele (jen čte, bez ptaní): nástroj Monitor (je-li odložený, nejdřív ToolSearch \"select:Monitor\") s parametry: command = $cmd ; description = \"ProjectCreator $PC_PROJECT: zprávy AI agentů\" ; timeout_ms = 1800000. Když skončí nebo vyprší, spusť ho znovu stejně – kromě případu, kdy skončil řádkem „hlídání zpráv převzala jiná session“. Každý jeho řádek je upozornění → skill projectcreator:komunikace-agentu. Uživateli spuštění neohlašuj, pokud se na hlídač neptá."

# Výstup jako JSON s additionalContext (text se přidá do kontextu agenta k této zprávě uživatele).
esc=$(printf '%s' "$text" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"%s"}}\n' "$esc"
exit 0
