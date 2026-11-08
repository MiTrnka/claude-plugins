# claude-plugins

Marketplace pluginů pro [Claude Code](https://code.claude.com) od Michala Trnky. Jméno marketplace: **`mitrnka`**.

```
/plugin marketplace add MiTrnka/claude-plugins
/plugin install <plugin>@mitrnka
```

| Plugin | Co dělá |
|---|---|
| [`projectcreator`](plugins/projectcreator/README.md) | Napojení na [ProjectCreator](https://projectcreator.cz): MCP server s položkami, releasy a verzemi, komunikace AI agentů, hlídač nových zpráv. |

## Bezpečnost
Repo je veřejné a neobsahuje žádná tajemství. Tokeny a hesla si každý uživatel ukládá jen lokálně (postup v README pluginu).

## Vývoj
- Kontrola: `claude plugin validate --strict .` (marketplace) a `claude plugin validate --strict plugins/<plugin>`.
- Lokální test bez instalace: `claude --plugin-dir plugins/<plugin>`.
- Skripty mají konce řádků LF (`.gitattributes`), jinak by v bashi na Windows i macOS padaly.
