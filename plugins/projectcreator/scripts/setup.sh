#!/usr/bin/env bash
# Nastavení pluginu ProjectCreator (volá ho skill /projectcreator:setup, jde spustit i ručně v terminálu).
#
#   setup.sh token            uloží token AI agenta (ze stdin; v terminálu se zeptá se skrytým vstupem) a ověří ho
#   setup.sh whoami           ověří uložený token (GET /api/agent/whoami) – jméno AI, majitel, projekty
#   setup.sh link KLÍČ [DIR]  naváže repo (kořen git repa z DIR / CLAUDE_PROJECT_DIR / cwd) na projekt KLÍČ
#   setup.sh unlink [DIR]     zruší navázání repa
#   setup.sh status [DIR]     shrnutí: kde je token (ne jeho hodnota), server, navázání, ověření
#
# Token se nikdy nevypisuje. Soubor s tokenem má práva jen pro uživatele (chmod 600, adresář 700).
. "$(dirname "$0")/pc-common.sh"

die() { echo "Chyba: $*" >&2; exit 1; }

explain_code() {
  case "$PC_CODE" in
    401) echo "server token odmítl (401) – je neplatný, zrušený nebo patří deaktivovanému AI agentovi" ;;
    429) echo "příliš mnoho požadavků (429) – zkus to za minutu" ;;
    000) echo "server $PC_URL neodpovídá (síť, DNS, TLS nebo špatná adresa)" ;;
    *)   echo "server vrátil HTTP $PC_CODE: $(printf '%s' "$PC_BODY" | head -n 1)" ;;
  esac
}

cmd_whoami() {
  pc_read_token || die "v $PC_TOKEN_FILE není platný token – spusť nejdřív: setup.sh token"
  pc_get "/api/agent/whoami" 15
  [ "$PC_CODE" = "200" ] || die "$(explain_code)"
  printf '%s\n' "$PC_BODY"
}

cmd_token() {
  local tok=""
  if [ -t 0 ]; then
    printf 'Vlož token AI agenta (pca_…, nezobrazuje se): ' >&2
    IFS= read -rs tok
    echo >&2
  else
    IFS= read -r tok || [ -n "$tok" ]
  fi
  tok="${tok%$'\r'}"
  # odstranění mezer okolo (kopírování z webu)
  tok="${tok#"${tok%%[![:space:]]*}"}"
  tok="${tok%"${tok##*[![:space:]]}"}"
  pc_valid_token "$tok" || die "tohle není token AI agenta (čekám pca_ + písmena a číslice). Token vytvoříš v Profilu na $PC_URL u svého AI agenta."

  # Ověřit dřív, než se přepíše případný starý funkční token.
  PC_TOKEN="$tok"
  pc_get "/api/agent/whoami" 15
  [ "$PC_CODE" = "200" ] || die "token se neuložil – $(explain_code)"

  ( umask 077 && mkdir -p "$PC_HOME" ) || die "nejde vytvořit adresář $PC_HOME"
  chmod 700 "$PC_HOME" 2>/dev/null
  local tmp="$PC_TOKEN_FILE.tmp.$$"
  ( umask 077 && printf '%s\n' "$tok" > "$tmp" ) || die "nejde zapsat $tmp"
  chmod 600 "$tmp" 2>/dev/null
  mv -f "$tmp" "$PC_TOKEN_FILE" || die "nejde uložit $PC_TOKEN_FILE"
  echo "Token uložen do $PC_TOKEN_FILE (práva jen pro tebe)."
  printf 'Ověřeno: %s\n' "$PC_BODY"
}

cmd_link() {
  local key="$1"
  [ -n "$key" ] || die "chybí klíč projektu: setup.sh link KLÍČ"
  case "$key" in
    *[!A-Za-z0-9_-]*) die "klíč projektu smí obsahovat jen písmena, číslice, - a _" ;;
  esac
  pc_read_token || die "nejdřív ulož token: setup.sh token"
  pc_get "/api/agent/status?project=$key" 15
  case "$PC_CODE" in
    200) ;;
    404) die "$(printf '%s' "$PC_BODY" | head -n 1)" ;;
    *) die "$(explain_code)" ;;
  esac
  pc_repo_root "$2" || die "adresář neexistuje"
  # klíč v té podobě, jak ho zná server (velikost písmen)
  local canon="$key" up k
  up=$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')
  pc_get "/api/agent/whoami" 15
  if [ "$PC_CODE" = "200" ]; then
    for k in $(printf '%s' "${PC_BODY##*projekty: }" | tr ',' ' '); do
      [ "$(printf '%s' "$k" | tr '[:lower:]' '[:upper:]')" = "$up" ] && canon="$k"
    done
  fi
  mkdir -p "$PC_REPO_ROOT/.claude" || die "nejde vytvořit $PC_REPO_ROOT/.claude"
  printf '{"project": "%s"}\n' "$canon" > "$PC_REPO_ROOT/$PC_LINK_REL" || die "nejde zapsat $PC_REPO_ROOT/$PC_LINK_REL"
  echo "Repo $PC_REPO_ROOT navázáno na projekt $canon ($PC_LINK_REL – bez tajemství, patří do gitu)."
}

cmd_unlink() {
  pc_find_link "$1" || { echo "Repo není navázané na žádný projekt."; return 0; }
  mv -f "$PC_LINK_FILE" "$PC_LINK_FILE.removed" && echo "Navázání zrušeno (soubor přejmenován na $PC_LINK_FILE.removed – smaž ho)."
}

cmd_status() {
  echo "Server: $PC_URL"
  if pc_read_token; then
    echo "Token: uložen v $PC_TOKEN_FILE"
    pc_get "/api/agent/whoami" 15
    if [ "$PC_CODE" = "200" ]; then printf 'Agent: %s\n' "$PC_BODY"; else echo "Ověření: $(explain_code)"; fi
  elif [ -f "$PC_TOKEN_FILE" ]; then
    echo "Token: soubor $PC_TOKEN_FILE existuje, ale nemá tvar pca_… – ulož token znovu"
  else
    echo "Token: chybí ($PC_TOKEN_FILE)"
  fi
  if pc_find_link "$1"; then
    echo "Repo: navázáno na projekt $PC_PROJECT ($PC_LINK_FILE)"
  else
    echo "Repo: nenavázané (hook i hlídač zpráv tu mlčí)"
  fi
}

case "$1" in
  token)  cmd_token ;;
  whoami) cmd_whoami ;;
  link)   cmd_link "$2" "$3" ;;
  unlink) cmd_unlink "$2" ;;
  status) cmd_status "$2" ;;
  *) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
