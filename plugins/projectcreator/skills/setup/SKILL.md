---
name: setup
description: Nastavení pluginu ProjectCreator – uložení tokenu AI agenta, ověření a navázání aktuálního repa na projekt.
disable-model-invocation: true
argument-hint: "[KLÍČ projektu]"
allowed-tools: Bash(bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" *)
---

# Nastavení pluginu ProjectCreator

Proveď uživatele nastavením. Mluv česky, stručně. Skript: `${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh`
(vždy volej `bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" …`). **Token nikdy nevypisuj, neopakuj ani necituj** –
ani zkrácený, ani „maskovaný“.

## 1. Stav
Spusť `bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" status` a podle výstupu přeskoč hotové kroky
(platný token → rovnou krok 3).

## 2. Token
Když token chybí nebo ho server odmítl, vysvětli uživateli, kde ho vezme:
1. Přihlásí se na https://projectcreator.cz → vpravo nahoře klikne na své jméno (stránka **Profil**, `/profil`).
2. V kartě **Moji AI agenti** – pokud agenta ještě nemá – do pole **Přidat AI agenta** napíše např. `Claude`
   a klikne **Přidat AI** (vznikne `Jméno_Claude`).
3. U agenta klikne **Tokeny** → v části **Nový token** zadá popisek (např. `notebook`) → **Vytvořit token** →
   **Kopírovat** (token se ukáže jen jednou).

Pak nabídni dvě cesty uložení:
- **Doporučeno – token nejde přes chat:** uživatel spustí ve vlastním terminálu (Git Bash na Windows, Terminál na macOS)
  `bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" token`, token vloží (vstup se nezobrazuje) a dá ti vědět.
- **Rychleji – vloží token sem do chatu:** pak ho ulož přes stdin, ne jako argument:
  `printf '%s\n' 'TOKEN' | bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" token`
  a upozorni, že token zůstal v lokálním přepisu této session (kdo k němu má přístup, může token zneužít;
  v případě pochybností ho v Profilu zruší a vytvoří nový).

Skript token nejdřív ověří (`GET /api/agent/whoami`) a uloží ho do `~/.claude/projectcreator/token`
s právy jen pro uživatele. Jiné umístění: proměnná `PROJECTCREATOR_HOME` (adresář), jiný server
`PROJECTCREATOR_URL` (např. `http://localhost:5096` pro lokální test) – obě musí být nastavené už při startu Claude Code.

## 3. Ověření a projekty
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" whoami` → ukaž uživateli jméno agenta, majitele a seznam projektů.

## 4. Navázání repa na projekt
Klíč projektu: argument skillu (`$ARGUMENTS`), jinak se zeptej (nabídni projekty z kroku 3). Pak
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" link KLÍČ`. Vznikne `.claude/projectcreator.json` v kořeni git repa
(`{"project": "KLÍČ"}`) – neobsahuje tajemství, doporuč ho commitnout, ať platí i pro ostatní členy projektu.
Bez navázání hook i hlídač zpráv v repu mlčí; MCP tooly fungují i tak. Zrušení: `… setup.sh unlink`.

## 5. Co dál
Řekni uživateli, že změny se projeví po **novém startu session** (ukončit a spustit znovu, v Desktopu nová session):
MCP server se připojí s tokenem, SessionStart hook ohlásí čekající zprávy a spustí se hlídač zpráv.
Bez restartu: `/mcp` → `plugin:projectcreator:projectcreator` → **Reconnect** (MCP) a `/reload-plugins` (hlídač).
Hlídač (monitor) běží jen v interaktivní session, ne v `claude -p`.
