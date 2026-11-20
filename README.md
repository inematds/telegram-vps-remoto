# Telegram VPS remoto — kit pronto

[![Telegram VPS remoto](guia/assets/banner.jpg)](https://inematds.github.io/telegram-vps-remoto/guia/)

**🇧🇷 [Português](README.md) · 🇺🇸 [English](README.en.md) · 🇪🇸 [Español](README.es.md)**

## O que é

É um kit pronto para você cuidar da sua VPS pelo celular: um bot de Telegram que passa os seus pedidos para o Claude Code, pela assinatura que você já paga. Serve para quem tem um servidor e quer perguntar "quanto espaço livre tem?", "quanta memória sobra?" ou organizar os arquivos que pôs na pasta do bot sem abrir o notebook, e sem dar à IA a chave da casa. Só você fala com o bot, a IA só lê, e qualquer mudança espera o seu "sim". Você precisa de uma VPS Linux (testado no Ubuntu 24.04, o Linux mais usado em servidor) com Python 3.10+, do Claude Code logado e de uma conta no Telegram; um instalador faz o resto.

## 📖 Guia de uso

Guia (o que é, como funciona e como começar): **https://inematds.github.io/telegram-vps-remoto/guia/**

- Quer entender a ideia antes? **Conceito** (controle remoto e Jarvis): https://inematds.github.io/telegram-claude-jarvis/guia/
- Quer montar o mesmo bot etapa por etapa, aprendendo cada trava? **Passo a passo**: https://inematds.github.io/telegram-vps-passo-a-passo/guia/
- Quer o assistente com memória e cérebro trocável? **Jarvis na prática**: https://inematds.github.io/jarvis-na-pratica/guia/

## As travas (no código, não no pedido)

| Trava | O que faz |
|---|---|
| Donos | Só os IDs em `DONOS` falam com o bot. Lista vazia = ninguém; o bot só anota quem tentou. |
| A IA só lê | 1ª chamada do `claude -p` com leitura de conteúdo presa à pasta `area/` (`Read(./**)`, nem por link simbólico); fora dela só `df`, `ls`, `free`, `uptime`. Chaves, SSH, logins e `.env` negados. |
| Sem herança da máquina | `--setting-sources "" --strict-mcp-config`: permissões do `settings.json` do servidor não valem para o bot. |
| Proposta + "sim" | Pedido que muda algo vira proposta com os comandos exatos e "Confirma?". Depois do "sim", **quem roda é o bot**, sem shell, só `rm`, `rmdir`, `mv`, `cp`, `mkdir`, `touch`, `gzip`, `gunzip`, `tar`, só dentro de `area/`, só opções da lista. Curinga (`*`) é recusado. |
| Negação cancela | "sim", "sí" e "yes" confirmam; "sim, não apaga", "sí, pero antes", "pode listar antes?" não. Pedido pendente vale 10 min. |
| Na língua do dono | A IA responde na língua em que você escreve; só as frases fixas ("Confirma? (sim/não)", "Este bot é privado.") ficam em português. |
| Auditoria | Pedido, proposta, sim, recusa, cancelamento, expiração e resultado vão para `auditoria.jsonl` (só o dono do bot lê). |

## Instalação técnica

Na VPS, **como usuário comum** (não root):

```bash
git clone https://github.com/inematds/telegram-vps-remoto.git
cd telegram-vps-remoto
bash instalar.sh                      # pede o token sem mostrar, roda os 52 testes (2–5 min), liga o serviço
# no Telegram: mande /start ao seu bot; ele diz "Este bot é privado."
journalctl --user -u telegram-vps-remoto -n 20 --no-pager | grep recusado   # → recusado: from.id=123456789
bash instalar.sh --dono 123456789     # grava você em DONOS e reinicia
bash instalar.sh --status             # no ar? últimas linhas do log
```

Pré-requisitos: Python 3.10+ (sem pacotes extras, só biblioteca padrão), Claude Code logado (`curl -fsSL https://claude.ai/install.sh | bash`, depois `claude` → `/login`) e um bot criado no @BotFather. Testado no Ubuntu 24.04.

Só tem root? Como root: `adduser <nome>`, copie a sua chave (`mkdir -p /home/<nome>/.ssh && cp ~/.ssh/authorized_keys /home/<nome>/.ssh/ && chown -R <nome>: /home/<nome>/.ssh`) e `loginctl enable-linger <nome>` (mantém o bot no ar quando você sai do SSH). Depois entre direto: `ssh <nome>@IP` (`su -` não serve para o serviço do usuário).

**A pasta de trabalho.** O bot só lê e muda o que está em `area/` (ao lado do `bot.py`), que começa vazia: ponha lá os arquivos que quer que ele leia ou organize. Para usar outra pasta, `AREA=/caminho` no `.env` e `bash instalar.sh --status` depois de reiniciar — só aponte para uma pasta que você aceita que ele leia e mude com o seu sim. Logs do sistema (`/var/log`) ficam fora, de propósito.

**Termos.** *root*: o administrador do servidor (o bot não roda como root). *linger*: deixa os serviços do seu usuário no ar depois que você sai do SSH. *registro do bot*: as linhas que o serviço escreve enquanto roda (`journalctl --user -u telegram-vps-remoto`). *chave de API*: senha de cobrança por uso — o kit não usa nenhuma.

Arquivos:

| Arquivo | Para quê |
|---|---|
| `bot.py` | O bot (só biblioteca padrão, long polling, sem porta aberta). |
| `instalar.sh` | Instala/atualiza em `~/kits/telegram-vps-remoto`, cria o `.env` (600), roda os testes, liga o serviço; `--dono`, `--status`. Idempotente. |
| `testes/testar_travas.py` | 52 testes das travas (8 chamadas curtas do Claude Code pela assinatura), com área e auditoria temporárias e iscas de segredo dentro e fora da área. |
| `systemd/telegram-vps-remoto.service` | Serviço de usuário (`MemoryMax=2G`, reinicia sozinho). |
| `ferramentas/telegram_falso.py` | Telegram falso para testar sem bot real (`TELEGRAM_API=http://127.0.0.1:8081`). |
| `.env.example` | Variáveis: `TELEGRAM_BOT_TOKEN`, `DONOS`, `MODELO`, `AREA`, `PRAZO_OK_S`, `TELEGRAM_API`. |
| `FALHAS.md` | Cada furo achado e a menor correção. |

Testar sem bot real: `python3 ferramentas/telegram_falso.py servidor` num terminal, `TELEGRAM_API=http://127.0.0.1:8081 DONOS=111 TELEGRAM_BOT_TOKEN=1:x python3 bot.py` em outro e `python3 ferramentas/telegram_falso.py fala --de 111 "quanto espaço livre tem no disco?"` no terceiro.

## O processo, do início ao fim

Quem faz: 🧠 você · ⚙️ script/serviço · 🤖 Claude Code (`claude -p`, chamado pelo bot)

| # | Passo | Comando | Quem |
|---|---|---|---|
| 1 | Criar o bot no @BotFather e copiar o token | (no Telegram) `/newbot` | 🧠 |
| 2 | Entrar na VPS como usuário comum e baixar o kit | `git clone … && cd telegram-vps-remoto` | 🧠 |
| 3 | Conferir Python e Claude Code logado | `bash instalar.sh` (passo 1/6) | ⚙️ |
| 4 | Copiar o bot e criar o `.env` 600 com o token | `bash instalar.sh` (passos 2–3) | ⚙️ |
| 5 | Rodar os 52 testes das travas | `bash instalar.sh` (passo 4) | ⚙️🤖 |
| 6 | Ligar o serviço de usuário | `bash instalar.sh` (passo 5) | ⚙️ |
| 7 | Mandar `/start` e achar o seu ID no log | `journalctl --user -u telegram-vps-remoto … \| grep recusado` | 🧠 |
| 8 | Gravar o seu ID como dono | `bash instalar.sh --dono <id>` | 🧠⚙️ |
| 9 | Pedir pelo Telegram; a IA investiga e propõe | (no Telegram) | 🧠🤖 |
| 10 | Dizer "sim" (ou "não"); o bot executa e anota | (no Telegram) | 🧠⚙️ |

## A prova

- `testar_travas.py` na VPS de teste (Ubuntu 24.04): **52 PASSOU, TUDO OK** — lista vazia recusa, leitura responde, `.env` e isca fora da área não saem (nem pelo `du --files0-from`, nem por link simbólico), a IA não apaga nem com ordem direta, 18 comandos/opções perigosos recusados, 20 confirmações conferidas (inclusive "sí" e "no" no meio da frase, como em "o que está no log"), fluxo pedido → proposta → sim → apagado.
- `instalar.sh` testado de ponta a ponta numa pasta nova da VPS, com o Telegram falso: suíte da época (45) passando, serviço no ar, `/start` de estranho recusado e anotado, `--dono` gravado, pergunta respondida ("Tem 131 GB livres de 193 GB"), reinstalação mantendo o `.env`.
- Os furos achados por revisores independentes e corrigidos estão em [FALHAS.md](FALHAS.md).


---

Feito pelo [INEMA.CLUB](https://inema.club) — grátis, direto na internet.
