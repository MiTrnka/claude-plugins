#!/usr/bin/env bash
# Monitor pluginu (hlídač): long-poll /api/agent/events/wait pro projekt navázaný na repo.
# Každý řádek na stdout = jedna událost = notifikace, která agenta v otevřené session probudí.
#   - bez navázaného repa nebo bez tokenu skončí hned a potichu;
#   - 401 (neplatný token) / 403 / 404 (projekt neexistuje nebo k němu agent nemá přístup) → jeden vysvětlující řádek a konec;
#   - 429 → počká 60 s; chyba sítě / 5xx → backoff 5 → 10 → 20 → 40 → 60 s; úspěch backoff vynuluje.
#   - skončí potichu, když zmizí proces Clauda, který ho spustil (CLAUDE_PID) – jinak by po zavření terminálu
#     zůstal běžet jako sirotek a „spolykal" upozornění, která patří nové session (ověřeno 2026-11-09 na Windows);
#   - volitelný 2. argument = nejdelší doba běhu v sekundách: hlídač pak skončí ČISTĚ mezi dvěma dotazy (pro nástroj
#     Monitor v Claude Desktopu, který monitor po 30 min zabíjí – zabití uprostřed dotazu by mohlo ztratit upozornění).
# Argument: adresář projektu (výchozí CLAUDE_PROJECT_DIR, jinak aktuální adresář – monitor běží v adresáři session).
. "$(dirname "$0")/pc-common.sh"

dir="$1"
case "$dir" in
  ''|'${'*) dir="" ;;   # nedosazená proměnná z konfigurace monitoru
esac
max_s="$2"
case "$max_s" in
  ''|*[!0-9]*) max_s=0 ;;
esac
pc_find_link "$dir" || exit 0
pc_read_token || exit 0

# Žije ještě proces Clauda? Bez CLAUDE_PID se nekontroluje. Na Windows (Git Bash) je CLAUDE_PID windowsové PID,
# které `kill -0` nezná → tasklist.
claude_alive() {
  [ -n "$CLAUDE_PID" ] || return 0
  case "$CLAUDE_PID" in *[!0-9]*) return 0 ;; esac
  if [ -n "$WINDIR" ] && command -v tasklist >/dev/null 2>&1; then
    tasklist //NH //FI "PID eq $CLAUDE_PID" 2>/dev/null | grep -q " $CLAUDE_PID "
  else
    kill -0 "$CLAUDE_PID" 2>/dev/null
  fi
}

wait_s="${PROJECTCREATOR_WAIT:-25}"
backoff=5
while :; do
  claude_alive || exit 0
  if [ "$max_s" -gt 0 ] && [ $((SECONDS + wait_s + 10)) -ge "$max_s" ]; then
    exit 0
  fi
  started=$SECONDS
  pc_get "/api/agent/events/wait?project=$PC_PROJECT&timeout=$wait_s" $((wait_s + 35))
  case "$PC_CODE" in
    200)
      backoff=5
      # Prázdná odpověď hned (vypínání serveru, proxy) → nezahlcovat server smyčkou.
      if [ -z "$PC_BODY" ] && [ $((SECONDS - started)) -lt 2 ]; then sleep 5; fi
      printf '%s\n' "$PC_BODY" | while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        [ -n "$line" ] && printf '%s\n' "$line"
      done
      ;;
    401)
      echo "ProjectCreator: server odmítl token AI (401) – hlídač zpráv končí. Ověř token přes /projectcreator:setup."
      exit 0
      ;;
    403|404)
      msg=$(printf '%s' "$PC_BODY" | head -n 1)
      echo "ProjectCreator: hlídač zpráv projektu $PC_PROJECT končí ($PC_CODE): ${msg:-bez popisu}"
      exit 0
      ;;
    429)
      sleep 60
      ;;
    *)
      sleep "$backoff"
      backoff=$((backoff * 2))
      [ "$backoff" -gt 60 ] && backoff=60
      ;;
  esac
done
