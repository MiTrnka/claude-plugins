# Společné funkce skriptů pluginu ProjectCreator (načítá se přes `. pc-common.sh`).
# Jen bash (i 3.2 na macOS) + curl: žádné jq/python/node, žádné `declare -A`, `mapfile`, `${x,,}`.
#
# Konfigurace (vše volitelné, výchozí = produkce):
#   PROJECTCREATOR_HOME  adresář s tokenem (výchozí ~/.claude/projectcreator); soubor `token` = jediný řádek pca_…
#   PROJECTCREATOR_URL   adresa serveru bez lomítka na konci (výchozí https://projectcreator.cz)
# Pozor: headersHelper MCP serveru z pluginu dostává prostředí BEZ proměnných, jejichž jméno vypadá jako credential
# (TOKEN, KEY, SECRET, AUTH, PASSWORD…) – proto se cesta k tokenu nastavuje jen přes PROJECTCREATOR_HOME.

PC_HOME="${PROJECTCREATOR_HOME:-$HOME/.claude/projectcreator}"
PC_TOKEN_FILE="$PC_HOME/token"
PC_URL="${PROJECTCREATOR_URL:-https://projectcreator.cz}"
PC_URL="${PC_URL%/}"
PC_LINK_REL=".claude/projectcreator.json"

# Načte token do PC_TOKEN; návrat 1 = chybí nebo má špatný tvar (token se nikdy nevypisuje).
pc_read_token() {
  PC_TOKEN=""
  [ -f "$PC_TOKEN_FILE" ] || return 1
  IFS= read -r PC_TOKEN < "$PC_TOKEN_FILE" || [ -n "$PC_TOKEN" ] || return 1
  PC_TOKEN="${PC_TOKEN%$'\r'}"
  pc_valid_token "$PC_TOKEN"
}

# Tvar tokenu: pca_ + znaky [A-Za-z0-9_] (chrání i JSON výstup headersHelperu a konfiguraci curlu).
pc_valid_token() {
  case "$1" in
    pca_*) ;;
    *) return 1 ;;
  esac
  case "$1" in
    *[!A-Za-z0-9_]*) return 1 ;;
  esac
  [ "${#1}" -ge 20 ]
}

# Kořen hledání: argument, jinak CLAUDE_PROJECT_DIR, jinak aktuální adresář.
# Prochází nahoru a hledá .claude/projectcreator.json; zastaví se v kořeni git repa (adresář s .git) nebo v /.
# Výsledek: PC_LINK_FILE (cesta k souboru) a PC_PROJECT (klíč); návrat 1 = repo není navázané.
pc_find_link() {
  local dir="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
  PC_LINK_FILE=""
  PC_PROJECT=""
  [ -n "$dir" ] && [ -d "$dir" ] || return 1
  dir=$(cd "$dir" 2>/dev/null && pwd) || return 1
  while :; do
    if [ -f "$dir/$PC_LINK_REL" ]; then
      PC_LINK_FILE="$dir/$PC_LINK_REL"
      PC_PROJECT=$(sed -n 's/.*"project"[[:space:]]*:[[:space:]]*"\([A-Za-z0-9_-]*\)".*/\1/p' "$PC_LINK_FILE" | head -n 1)
      [ -n "$PC_PROJECT" ] && return 0
      return 1
    fi
    [ -e "$dir/.git" ] && return 1
    case "$dir" in
      /|?:/|/?) return 1 ;;
    esac
    local up
    up=$(dirname "$dir")
    [ "$up" = "$dir" ] && return 1
    dir="$up"
  done
}

# Kořen git repa (nebo zadaný adresář, když v repu není) → PC_REPO_ROOT.
pc_repo_root() {
  local dir="${1:-${CLAUDE_PROJECT_DIR:-$PWD}}"
  dir=$(cd "$dir" 2>/dev/null && pwd) || return 1
  local d="$dir"
  while :; do
    if [ -e "$d/.git" ]; then PC_REPO_ROOT="$d"; return 0; fi
    local up
    up=$(dirname "$d")
    [ "$up" = "$d" ] && break
    d="$up"
  done
  PC_REPO_ROOT="$dir"
}

# GET na REST API pluginu. pc_get <cesta s query> <max sekund>
# Výsledek: PC_CODE (HTTP kód, 000 = síť) a PC_BODY (tělo). Token jde curlu přes stdin (konfigurace -K -),
# takže není vidět v seznamu procesů.
pc_get() {
  local out
  out=$(printf 'header = "Authorization: Bearer %s"\n' "$PC_TOKEN" |
        curl -s -K - --max-time "$2" -H 'Accept: text/plain' -w '\n%{http_code}' "$PC_URL$1" 2>/dev/null)
  PC_CODE="${out##*$'\n'}"
  PC_BODY="${out%$'\n'*}"
  [ "$PC_BODY" = "$out" ] && PC_BODY=""
  PC_BODY="${PC_BODY%$'\n'}"
  case "$PC_CODE" in
    [0-9][0-9][0-9]) ;;
    *) PC_CODE="000" ;;
  esac
}

# POST na REST API pluginu (bez těla). pc_post <cesta s query> <max sekund> → PC_CODE, PC_BODY jako pc_get.
pc_post() {
  local out
  out=$(printf 'header = "Authorization: Bearer %s"\n' "$PC_TOKEN" |
        curl -s -K - --max-time "$2" -X POST -H 'Accept: text/plain' -H 'Content-Length: 0' -w '\n%{http_code}' "$PC_URL$1" 2>/dev/null)
  PC_CODE="${out##*$'\n'}"
  PC_BODY="${out%$'\n'*}"
  [ "$PC_BODY" = "$out" ] && PC_BODY=""
  PC_BODY="${PC_BODY%$'\n'}"
  case "$PC_CODE" in
    [0-9][0-9][0-9]) ;;
    *) PC_CODE="000" ;;
  esac
}

# Id session Claude Code jen z bezpečných znaků (do URL a příkazové řádky); prázdné = neznámé.
pc_clean_session() {
  printf '%s' "$1" | tr -cd 'A-Za-z0-9_-' | cut -c1-100
}
