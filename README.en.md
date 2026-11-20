# Telegram VPS remoto — ready-to-use kit

[![Telegram VPS remoto](guia/assets/banner-en.jpg)](https://inematds.github.io/telegram-vps-remoto/guia/en/)

**🇧🇷 [Português](README.md) · 🇺🇸 [English](README.en.md) · 🇪🇸 [Español](README.es.md)**

## What it is

A ready-to-use kit for managing your VPS from your phone: a Telegram bot that passes your requests to Claude Code through the subscription you already pay for. It’s for anyone with a server who wants to ask “How much free space is there?” or “Delete the old logs” without opening a laptop and without giving AI the keys to the house. Only you can talk to the bot, the AI can only read, and every change waits for your “sim” (yes). You need a Linux VPS with Python 3.10+, Claude Code logged in, and a Telegram account; an installer takes care of the rest.

## 📖 User guide

Guide (what it is, how it works, and how to get started): **https://inematds.github.io/telegram-vps-remoto/guia/en/**

- Want to understand the idea first? **Concept** (remote control and Jarvis): https://inematds.github.io/telegram-claude-jarvis/guia/en/
- Want to build the same bot step by step while learning each safeguard? **Step by step**: https://inematds.github.io/telegram-vps-passo-a-passo/guia/en/
- Want the assistant with memory and a swappable brain? **Jarvis in practice**: https://inematds.github.io/jarvis-na-pratica/guia/en/

## Safeguards (in the code, not in the request)

| Safeguard | What it does |
|---|---|
| Owners | Only IDs in `DONOS` can talk to the bot. An empty list means nobody; the bot only logs who tried. |
| The AI can only read | The first `claude -p` call has content reading confined to the `area/` folder (`Read(./**)`); outside it, only `df`, `ls`, `free`, and `uptime`. Keys, SSH, logins, and `.env` are denied. |
| No machine-level permission inheritance | `--setting-sources "" --strict-mcp-config`: permissions in the server’s `settings.json` do not apply to the bot. |
| Proposal + “sim” (yes) | A request that changes something becomes a proposal with the exact commands and “Confirma?” (Confirm?). After “sim” (yes), **the bot runs them**, without a shell, using only `rm`, `rmdir`, `mv`, `cp`, `mkdir`, `touch`, `gzip`, `gunzip`, and `tar`, only inside `area/`, and only with options from the list. Wildcards (`*`) are rejected. |
| Denial cancels | “sim, não apaga” (yes, don’t delete), “sim, mas antes…” (yes, but first…), and “pode listar antes?” (can you list them first?) do not confirm. A pending request is valid for 10 minutes. |
| Audit log | Requests, proposals, confirmations, refusals, cancellations, expirations, and results go to `auditoria.jsonl` (only the bot owner can read it). |

## Technical installation

On the VPS, **as a regular user** (not root):

```bash
git clone https://github.com/inematds/telegram-vps-remoto.git
cd telegram-vps-remoto
bash instalar.sh                      # asks for the token without displaying it, runs the 45 tests, starts the service
# on Telegram: send /start to your bot; it says "Este bot é privado."
journalctl --user -u telegram-vps-remoto -n 20 --no-pager | grep recusado   # → recusado: from.id=123456789
bash instalar.sh --dono 123456789     # saves you in DONOS and restarts
bash instalar.sh --status             # is it running? latest log lines
```

Prerequisites: Python 3.10+ (no extra packages, standard library only), Claude Code logged in (`curl -fsSL https://claude.ai/install.sh | bash`, then `claude` → `/login`), and a bot created with @BotFather. Tested on Ubuntu 24.04.

Only have root access? As root: `adduser <nome>`, copy your key (`mkdir -p /home/<nome>/.ssh && cp ~/.ssh/authorized_keys /home/<nome>/.ssh/ && chown -R <nome>: /home/<nome>/.ssh`) and run `loginctl enable-linger <nome>` (keeps the bot running after you leave SSH). Then log in directly: `ssh <nome>@IP` (`su -` does not work for the user service).

Files:

| File | Purpose |
|---|---|
| `bot.py` | The bot (standard library only, long polling, no open port). |
| `instalar.sh` | Installs/updates in `~/kits/telegram-vps-remoto`, creates `.env` (600), runs the tests, and starts the service; `--dono`, `--status`. Idempotent. |
| `testes/testar_travas.py` | 45 safeguard tests (7 short Claude Code calls through the subscription), with temporary work areas and audit logs, plus secret decoys inside and outside the area. |
| `systemd/telegram-vps-remoto.service` | User service (`MemoryMax=2G`, restarts automatically). |
| `ferramentas/telegram_falso.py` | Fake Telegram for testing without a real bot (`TELEGRAM_API=http://127.0.0.1:8081`). |
| `.env.example` | Variables: `TELEGRAM_BOT_TOKEN`, `DONOS`, `MODELO`, `AREA`, `PRAZO_OK_S`, `TELEGRAM_API`. |
| `FALHAS.md` | Every issue found and its smallest fix. |

To test without a real bot: run `python3 ferramentas/telegram_falso.py servidor` in one terminal, `TELEGRAM_API=http://127.0.0.1:8081 DONOS=111 TELEGRAM_BOT_TOKEN=1:x python3 bot.py` in another, and `python3 ferramentas/telegram_falso.py fala --de 111 "quanto espaço livre tem no disco?"` in a third.

## The process, from start to finish

Who does what: 🧠 you · ⚙️ script/service · 🤖 Claude Code (`claude -p`, called by the bot)

| # | Step | Command | Who |
|---|---|---|---|
| 1 | Create the bot with @BotFather and copy the token | (on Telegram) `/newbot` | 🧠 |
| 2 | Log in to the VPS as a regular user and download the kit | `git clone … && cd telegram-vps-remoto` | 🧠 |
| 3 | Check Python and confirm Claude Code is logged in | `bash instalar.sh` (step 1/6) | ⚙️ |
| 4 | Copy the bot and create `.env` with permissions 600 and the token | `bash instalar.sh` (steps 2–3) | ⚙️ |
| 5 | Run the 45 safeguard tests | `bash instalar.sh` (step 4) | ⚙️🤖 |
| 6 | Start the user service | `bash instalar.sh` (step 5) | ⚙️ |
| 7 | Send `/start` and find your ID in the log | `journalctl --user -u telegram-vps-remoto … \| grep recusado` | 🧠 |
| 8 | Save your ID as an owner | `bash instalar.sh --dono <id>` | 🧠⚙️ |
| 9 | Make a request through Telegram; the AI investigates and proposes a solution | (on Telegram) | 🧠🤖 |
| 10 | Say “sim” (yes) or “não” (no); the bot executes and logs it | (on Telegram) | 🧠⚙️ |

## Evidence

- `testar_travas.py` on the test VPS (Ubuntu 24.04): **45 PASSED, ALL OK** — an empty list rejects everyone; read requests get answers; `.env` and the decoy outside the area are not exposed (not even through `du --files0-from`); the AI does not delete anything, even when directly instructed; 18 dangerous commands/options are rejected; 14 confirmations are checked; request → proposal → confirmation → deleted flow works.
- `instalar.sh` tested end to end in a new folder on the VPS using the fake Telegram: 45 tests, service running, an unauthorized `/start` rejected and logged, `--dono` saved, question answered (“There are 131 GB free out of 193 GB”), and reinstall completed while preserving `.env`.
- Issues found by independent reviewers and fixed are listed in [FALHAS.md](FALHAS.md).


---

Made by [INEMA.CLUB](https://inema.club) — free and open on the internet.
