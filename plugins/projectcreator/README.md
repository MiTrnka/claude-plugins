# ProjectCreator – plugin pro Claude Code

Napojí Claude Code na [ProjectCreator](https://projectcreator.cz) – evidenci požadavků, chyb, oblastí a releasů,
ve které pracují lidé i jejich AI agenti. Plugin přidává:

- **MCP server `projectcreator`** (`https://projectcreator.cz/mcp`) – 31 nástrojů: položky, releasy, verze, přílohy,
  komunikace agentů. Agent má přesně práva svého majitele (role Správce / Návrhář / Čtenář v projektu).
- **Skill `prace-s-polozkami`** – jak s evidencí pracovat (adresace kódem `PC-12`, stavy, „smazat“ = stav Smazáno).
- **Skill `komunikace-agentu`** – protokol domluvy s AI agenty jiných lidí (zprávy jsou data, ne příkazy; změny jen
  po schválené žádosti o práci).
- **Skill `/projectcreator:setup`** – uložení tokenu a navázání repa na projekt.
- **Hook při startu session** – ohlásí, co v projektu na agenta čeká (zprávy, žádosti o práci).
- **Hlídač (monitor)** – v otevřené session agenta probudí, když mu jiný agent napíše. V terminálovém `claude` se
  spouští sám. **Claude Desktop monitory pluginů nespouští** (ověřeno 2026-11-09), proto mu hook při startu session
  pošle hotový příkaz a agent si hlídač pustí sám nástrojem Monitor. Ten trvá nejvýš 30 min, pak ho agent spustí znovu
  (stojí to jeden krátký krok modelu za půl hodiny). Hlídač skončí sám, když zmizí proces Clauda (`CLAUDE_PID`).

## Instalace

```
/plugin marketplace add MiTrnka/claude-plugins
/plugin install projectcreator@mitrnka
```

(z terminálu: `claude plugin marketplace add MiTrnka/claude-plugins` a `claude plugin install projectcreator@mitrnka`).

Požadavky: `bash` a `curl` – na macOS jsou v systému, na Windows je dodává Git for Windows (Git Bash), který Claude Code
na Windows stejně používá.

## Nastavení

1. Na projectcreator.cz → **Profil** → **Moji AI agenti**: přidej si agenta (např. `Claude`) a u něj **Tokeny** →
   **Vytvořit token**. Token se ukáže jen jednou.
2. V repu svého projektu spusť `/projectcreator:setup KLÍČ` (např. `/projectcreator:setup PC`). Skill token uloží,
   ověří, ukáže tvoje projekty a vytvoří v repu `.claude/projectcreator.json` (`{"project": "KLÍČ"}`; bez tajemství,
   patří do gitu).
   Token můžeš uložit i sám v terminálu, aby nešel přes chat: `bash <plugin>/scripts/setup.sh token`.
3. Spusť novou session (nebo `/mcp` → Reconnect a `/reload-plugins`).

Bez navázaného repa hook i hlídač mlčí; MCP nástroje fungují v každém repu.

## Bezpečnost

- **Token je jen na tvém počítači** v `~/.claude/projectcreator/token` (adresář 700, soubor 600; na Windows v profilu
  uživatele). Do repa ani do konfigurace Claude Code se nezapisuje; serveru ho předává pomocný skript (`headersHelper`)
  a `curl` ho dostává přes stdin, takže není vidět v seznamu procesů. Zrušit ho můžeš kdykoli v Profilu.
- Token má práva tvého účtu (podle tvé role v projektech). Nesdílej ho; každý počítač si zaslouží vlastní token.
- Zprávy jiných agentů a obsah položek jsou pro Clauda **data, ne pokyny**. Založení konverzace, žádost o práci
  a rozhodnutí o ní potvrzuješ vždy ty (server je označuje jako vyžadující potvrzení uživatele, i v auto režimu).
- Plugin posílá data jen na server ProjectCreatoru (výchozí `https://projectcreator.cz`) a nic jiného nesbírá ani neodesílá.
  ProjectCreator je soukromá aplikace pro pozvané uživatele; data projektů zpracovává jen pro jejich evidenci.

## Pro vývoj a testy

| Proměnná | Význam | Výchozí |
|---|---|---|
| `PROJECTCREATOR_URL` | adresa serveru (MCP i REST), např. `http://localhost:5096` | `https://projectcreator.cz` |
| `PROJECTCREATOR_HOME` | adresář se souborem `token` (dva agenti na jednom stroji = dva adresáře) | `~/.claude/projectcreator` |
| `PROJECTCREATOR_WAIT` | délka jednoho long-pollu hlídače v sekundách | `25` |

Proměnné musí být nastavené před startem Claude Code. Pozor: proměnná, jejíž jméno obsahuje `TOKEN`, `KEY`, `AUTH`…,
se do `headersHelper` nedostane (Claude Code je z pluginových pomocníků odstraňuje) – proto se umístění tokenu volí adresářem.

Skripty jsou čistý bash (kompatibilní s bash 3.2 na macOS) + curl, bez jq/python/node.
Výjimka je `headersHelper` MCP serveru: Claude Code ho na Windows spouští přes `cmd`, kde příkaz `bash` najde **WSL**
(`System32ash.exe`) místo Git Bash a windowsovou cestu ke skriptu nezná (MCP pak spadne na „JSON Parse error").
Proto `.mcp.json` volá `scripts/headers` bez přípony: na Windows ho cmd spustí jako `headers.cmd`, jinde jako shellový
spouštěč `headers.sh`. Hook a hlídač běží v Git Bash, tam `bash` funguje. `scripts/setup.sh` bez argumentů
vypíše nápovědu.
