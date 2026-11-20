# CLAUDE.md — telegram-vps-remoto (kit pronto)

Bot de Telegram → `claude -p` pela assinatura numa VPS, com travas no código. Repo `inematds/telegram-vps-remoto`, autor de commit `inematds <inematds@gmail.com>`.

## Regras do projeto

- `bot.py` é a fonte da verdade das travas. O repo `telegram-vps-passo-a-passo` copia daqui com `ferramentas/sincronizar_etapas.py`: mudou o bot, rode a sincronização lá (etapa 9 = diff vazio).
- Toda mudança em trava: caso novo em `testes/testar_travas.py` + linha no `FALHAS.md` + rodar a suíte numa VPS (`TUDO OK`).
- Nunca rodar a suíte ou um 2º `bot.py` com o token de um bot que já está no ar (dois `getUpdates` derrubam o outro); teste com `TELEGRAM_API` do Telegram falso.
- Token só no `.env` (600), nunca em repo, log ou print.
- Guia `guia/` PT/EN/ES sem comandos (orientação); comandos ficam no README.

## Self-learning

Quando o Nei corrigir ou você achar um erro seu: antes de continuar, escreva a lição em uma linha no TOPO de `## Lessons` abaixo.

## Lessons

- O `claude -p` soma as regras "allow" do `settings.json` da máquina ao `--allowedTools`: bot com trava usa sempre `--setting-sources "" --strict-mcp-config` (20/11/2026).
- `Read`/`Glob`/`Grep` sem caminho liberam o disco inteiro; prender com `Read(./**)` relativo ao cwd e testar com isca FORA da área (20/11/2026).
- `du --files0-from=<arquivo>` mostra o conteúdo no erro: nada de `du` na leitura (20/11/2026).
- Confirmação só pela 1ª palavra deixa passar "sim, não apaga": frase com negação nunca confirma (20/11/2026).
