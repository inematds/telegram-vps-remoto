# Telegram VPS remoto — ready-to-use kit

[![Telegram VPS remoto](guia/assets/banner-en.jpg)](https://inematds.github.io/telegram-vps-remoto/guia/en/)

**🇧🇷 [Português](README.md) · 🇺🇸 [English](README.en.md) · 🇪🇸 [Español](README.es.md)**

## What it is

This is a ready-to-use kit for managing your VPS from your phone: a Telegram bot that passes your requests to Claude Code through the subscription you already pay for. It’s for anyone with a server who wants to ask “How much free space is there?”, “How much memory is left?” or organize files in the bot’s folder without opening a laptop or giving AI the keys to the house. Only you can talk to the bot, the AI only reads, and any change waits for your “sim” (yes). You need a Linux VPS (tested on Ubuntu 24.04, the most widely used Linux distribution for servers) with Python 3.10+, Claude Code logged in, and a Telegram account; an installer takes care of the rest.

## 📖 User guide

Guide (what it is, how it works, and how to get started): **https://inematds.github.io/telegram-vps-remoto/guia/en/**

- Want to understand the idea first? **Concept** (remote control and Jarvis): https://inematds.github.io/telegram-claude-jarvis/guia/en/
- Want to build the same bot step by step and learn about each safeguard? **Step by step**: https://inematds.github.io/telegram-vps-passo-a-passo/guia/en/
- Want an assistant with memory and a swappable brain? **Jarvis in practice**: https://inematds.github.io/jarvis-na-pratica/guia/en/

## Safeguards (in the code, not in the request)

| Safeguard | What it does |
|---|---|
| Owners | Only IDs in `DONOS` can talk to the bot. An empty list means nobody; the bot only logs anyone who tries. |
| The AI only reads | The first `claude -p` call is restricted to reading content in the `area/` folder (`Read(./**)`, including through symbolic links); outside it, only `df`, `ls`, `free`, and `uptime` are allowed. Keys, SSH, logins, and `.env` are denied. |
| No machine settings inherited | The server’s `settings.json` permissions don’t apply to the bot, thanks to `--setting-sources "" --strict-mcp-config`. |
| Proposal + “sim” (yes) | A request that changes something becomes a proposal with the exact commands and “Confirma? (sim/não)” (Confirm? (yes/no)). After “sim” (yes), **the bot runs them**, without a shell, using only `rm`, `rmdir`, `mv`, `cp`, `mkdir`, `touch`, `gzip`, `gunzip`, and `tar`, only inside `area/`, and only with options from the allowlist. Wildcards (`*`) are rejected. |
| Refusal cancels | “sim” (yes), “sí” (yes), and “yes” confirm; “sim, não apaga” (yes, don’t delete), “sí, pero antes” (yes, but first), and “pode listar antes?” (can you list first?) do not. A pending request is valid for 10 minutes. |
| In the owner’s language | The AI replies in the language you write in; only the fixed phrases (“Confirma? (sim/não)” (Confirm? (yes/no)), “Este bot é privado.” (This bot is private.)) stay in Portuguese. |
| Auditing | Requests, proposals, confirmations, refusals, cancellations, expirations, and results are recorded in `auditoria.jsonl` (only the bot owner can read it). |

## Technical installation

On the VPS, **as a regular user** (not root):

```bash
git clone https://github.com/inematds/telegram-vps-remoto.git
cd telegram-vps-remoto
bash instalar.sh                      # asks for the token without displaying it, runs 52 tests (2–5 min), starts the service
# on Telegram: send /start to your bot; it says "Este bot é privado."
journalctl --user -u telegram-vps-remoto -n 20 --no-pager | grep recusado   # → recusado: from.id=123456789
bash instalar.sh --dono 123456789     # adds you to DONOS and restarts
bash instalar.sh --status             # is it running? shows the latest log lines
```

Requirements: Python 3.10+ (no extra packages, standard library only), Claude Code logged in (`curl -fsSL https://claude.ai/install.sh | bash`, then `claude` → `/login`), and a bot created with @BotFather. Tested on Ubuntu 24.04.

Only have root? As root: `adduser <nome>`, copy your key (`mkdir -p /home/<nome>/.ssh && cp ~/.ssh/authorized_keys /home/<nome>/.ssh/ && chown -R <nome>: /home/<nome>/.ssh`), and run `loginctl enable-linger <nome>` (keeps the bot running when you disconnect from SSH). Then log in directly: `ssh <nome>@IP` (`su -` won’t work for the user service).

**The working folder.** The bot only reads and changes files inside `area/` (next to `bot.py`), which starts empty: put the files you want it to read or organize there. To use a different folder, set `AREA=/caminho` in `.env` and run `bash instalar.sh --status` after restarting—only point it to a folder you’re comfortable letting it read and change after your “sim” (yes). System logs (`/var/log`) are outside the folder by design.

**Terms.** *root*: the server administrator (the bot doesn’t run as root). *linger*: keeps your user’s services running after you disconnect from SSH. *bot log*: the lines written by the service while it runs (`journalctl --user -u telegram-vps-remoto`). *API key*: a pay-per-use password—the kit doesn’t use any.

Files:

| File | Purpose |
|---|---|
| `bot.py` | The bot (standard library only, long polling, no open ports). |
| `instalar.sh` | Installs or updates to `~/kits/telegram-vps-remoto`, creates `.env` (600), runs tests, and starts the service; supports `--dono` and `--status`. Idempotent. |
| `testes/testar_travas.py` | 52 safeguard tests (8 short Claude Code calls through the subscription), with temporary working and audit folders, plus secret decoys inside and outside the working folder. |
| `systemd/telegram-vps-remoto.service` | User service (`MemoryMax=2G`, restarts automatically). |
| `ferramentas/telegram_falso.py` | Fake Telegram for testing without a real bot (`TELEGRAM_API=http://127.0.0.1:8081`). |
| `.env.example` | Variables: `TELEGRAM_BOT_TOKEN`, `DONOS`, `MODELO`, `AREA`, `PRAZO_OK_S`, `TELEGRAM_API`. |
| `FALHAS.md` | Each issue found and the smallest fix. |

To test without a real bot: run `python3 ferramentas/telegram_falso.py servidor` in one terminal, `TELEGRAM_API=http://127.0.0.1:8081 DONOS=111 TELEGRAM_BOT_TOKEN=1:x python3 bot.py` in another, and `python3 ferramentas/telegram_falso.py fala --de 111 "quanto espaço livre tem no disco?"` in a third.

## The process, from start to finish

Who does what: 🧠 you · ⚙️ script/service · 🤖 Claude Code (`claude -p`, called by the bot)

| # | Step | Command | Who |
|---|---|---|---|
| 1 | Create the bot with @BotFather and copy the token | (on Telegram) `/newbot` | 🧠 |
| 2 | Log in to the VPS as a regular user and download the kit | `git clone … && cd telegram-vps-remoto` | 🧠 |
| 3 | Check Python and that Claude Code is logged in | `bash instalar.sh` (step 1/6) | ⚙️ |
| 4 | Copy the bot and create `.env` with permissions 600 and the token | `bash instalar.sh` (steps 2–3) | ⚙️ |
| 5 | Run the 52 safeguard tests | `bash instalar.sh` (step 4) | ⚙️🤖 |
| 6 | Start the user service | `bash instalar.sh` (step 5) | ⚙️ |
| 7 | Send `/start` and find your ID in the log | `journalctl --user -u telegram-vps-remoto … \| grep recusado` | 🧠 |
| 8 | Add your ID as an owner | `bash instalar.sh --dono <id>` | 🧠⚙️ |
| 9 | Send a request through Telegram; the AI investigates and proposes a solution | (on Telegram) | 🧠🤖 |
| 10 | Say “sim” (yes) or “não” (no); the bot runs the change and logs it | (on Telegram) | 🧠⚙️ |

## The proof

- `testar_travas.py` on the test VPS (Ubuntu 24.04): **52 PASSOU, TUDO OK** — an empty owner list rejects requests; reading works; `.env` and the decoy outside the working folder aren’t exposed (not even through `du --files0-from` or a symbolic link); the AI won’t delete files even when directly instructed; 18 dangerous commands/options are rejected; 20 confirmations are checked (including “sí”); request → proposal → “sim” (yes) → deleted.
- `instalar.sh` tested end to end in a new folder on the VPS with the fake Telegram: the test suite from that run (45) passed, the service stayed up, `/start` from an unauthorized user was rejected and logged, `--dono` was saved, a question was answered (“There are 131 GB free out of 193 GB”), and reinstalling kept `.env`.
- Issues found and fixed by independent reviewers are documented in [FALHAS.md](FALHAS.md).

---

Made by [INEMA.CLUB](https://inema.club) — free and open on the internet.
