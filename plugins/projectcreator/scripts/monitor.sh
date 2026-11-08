#!/usr/bin/env bash
# Monitor pluginu (hlídač): long-poll /api/agent/events/wait pro projekt navázaný na repo.
# Každý řádek na stdout = jedna událost = notifikace, která agenta v otevřené session probudí.
#   - bez navázaného repa nebo bez tokenu skončí hned a potichu;
#   - 401 (neplatný token) / 403 / 404 (projekt neexistuje nebo k němu agent nemá přístup) → jeden vysvětlující řádek a konec;
#   - 429 → počká 60 s; chyba sítě / 5xx → backoff 5 → 10 → 20 → 40 → 60 s; úspěch backoff vynuluje.
# Argument: adresář projektu (výchozí CLAUDE_PROJECT_DIR, jinak aktuální adresář – monitor běží v adresáři session).
. "$(dirname "$0")/pc-common.sh"

dir="$1"
case "$dir" in
  ''|'${'*) dir="" ;;   # nedosazená proměnná z konfigurace monitoru
esac
pc_find_link "$dir" || exit 0
pc_read_token || exit 0

wait_s="${PROJECTCREATOR_WAIT:-25}"
backoff=5
while :; do
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
