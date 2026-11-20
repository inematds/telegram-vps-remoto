#!/usr/bin/env bash
# Telegram VPS remoto — instalador do kit pronto.
#
# Uso (na VPS, como usuário comum, NUNCA como root):
#   bash instalar.sh                 instala ou atualiza (pede o token sem mostrar na tela)
#   bash instalar.sh --dono <id>     grava o seu ID do Telegram em DONOS e reinicia o bot
#   bash instalar.sh --status        mostra se o bot está no ar e as últimas linhas do log
#
# Variáveis opcionais (para teste ou instalação diferente):
#   DESTINO=~/kits/telegram-vps-remoto   pasta onde o bot fica
#   UNIDADE=telegram-vps-remoto          nome do serviço systemd do usuário
#   TELEGRAM_BOT_TOKEN=...               token (sem perguntar; útil em teste)
#   TELEGRAM_API=http://127.0.0.1:8081   Telegram falso (só teste)
#   PULAR_TESTES=1  SEM_SERVICO=1        pula a suíte das travas / não liga o serviço
#
# Idempotente: rodar de novo atualiza o código e mantém o seu .env.
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESTINO="${DESTINO:-$HOME/kits/telegram-vps-remoto}"
UNIDADE="${UNIDADE:-telegram-vps-remoto}"
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
aviso(){ printf '  \033[33m!\033[0m %s\n' "$*"; }
erro() { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }
passo(){ printf '\n\033[1m%s\033[0m\n' "$*"; }

if [ "$(id -u)" = "0" ]; then
  erro "Não rode como root. Crie um usuário comum (adduser), entre por SSH com ele e rode de novo."
fi

servico() { systemctl --user "$@"; }

# ---------- --status ----------
if [ "${1:-}" = "--status" ]; then
  echo "serviço $UNIDADE: $(servico is-active "$UNIDADE" 2>/dev/null || true)"
  journalctl --user -u "$UNIDADE" -n 15 --no-pager 2>/dev/null | cut -c1-200 || true
  exit 0
fi

# ---------- --dono <id> ----------
if [ "${1:-}" = "--dono" ]; then
  ID="${2:-}"
  [[ "$ID" =~ ^[0-9]+$ ]] || erro "Use: bash instalar.sh --dono <número>  (o número que aparece em 'recusado: from.id=')"
  [ -f "$DESTINO/.env" ] || erro "Não achei $DESTINO/.env. Rode primeiro: bash instalar.sh"
  ATUAL="$(grep -E '^DONOS=' "$DESTINO/.env" | cut -d= -f2- || true)"
  if [[ ",$ATUAL," == *",$ID,"* ]]; then ok "O ID $ID já está em DONOS."; else
    NOVO="${ATUAL:+$ATUAL,}$ID"
    sed -i -E "s/^DONOS=.*/DONOS=$NOVO/" "$DESTINO/.env"
    ok "DONOS agora: $(echo "$NOVO" | tr ',' '\n' | wc -l) pessoa(s)"
  fi
  if [ "${SEM_SERVICO:-0}" != "1" ]; then servico restart "$UNIDADE" && sleep 2 && ok "Bot reiniciado: $(servico is-active "$UNIDADE")"; fi
  echo "  Mande uma mensagem ao bot no Telegram, por exemplo: quanto espaço livre tem no disco?"
  exit 0
fi

passo "1/6 Conferindo o que precisa"
command -v python3 >/dev/null || erro "Falta o Python 3. No Ubuntu: (como root) apt install -y python3"
python3 - <<'EOF' || erro "Precisa do Python 3.10 ou mais novo."
import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)
EOF
ok "Python $(python3 -c 'import platform;print(platform.python_version())')"
command -v claude >/dev/null || erro "Falta o Claude Code. Instale (curl -fsSL https://claude.ai/install.sh | bash), rode 'claude', faça /login e rode este instalador de novo."
RESP="$(timeout 120 claude -p "responda só: ok" --model haiku --no-session-persistence --setting-sources "" < /dev/null 2>&1 || true)"
if echo "$RESP" | grep -qi "ok"; then ok "Claude Code logado ($(command -v claude))"
else erro "O Claude Code não respondeu. Rode 'claude', faça /login com a conta da assinatura e tente de novo. Resposta: ${RESP:0:160}"; fi

passo "2/6 Copiando o bot para $DESTINO"
mkdir -p "$DESTINO/testes" "$DESTINO/systemd" "$DESTINO/ferramentas"
if [ "$(cd "$DESTINO" && pwd)" != "$AQUI" ]; then
  cp "$AQUI/bot.py" "$DESTINO/"
  cp "$AQUI/testes/testar_travas.py" "$DESTINO/testes/"
  cp "$AQUI/systemd/telegram-vps-remoto.service" "$DESTINO/systemd/"
  cp "$AQUI/ferramentas/telegram_falso.py" "$DESTINO/ferramentas/" 2>/dev/null || true
fi
ok "bot.py, testes e serviço copiados"

passo "3/6 Arquivo .env (token e donos)"
umask 077
if [ -f "$DESTINO/.env" ]; then
  ok "Já existe um .env: mantido como está"
else
  TOKEN="${TELEGRAM_BOT_TOKEN:-}"
  if [ -z "$TOKEN" ]; then
    echo "  Cole o token que o @BotFather te deu (ele não aparece na tela) e aperte Enter:"
    read -r -s TOKEN; echo
  fi
  [[ "$TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]] || erro "Isso não parece um token do BotFather (formato 123456789:ABC…). Rode de novo."
  {
    echo "# Telegram VPS remoto — não compartilhe este arquivo"
    echo "TELEGRAM_BOT_TOKEN=$TOKEN"
    echo "# IDs do Telegram que podem falar com o bot (vazio = ninguém). Use: bash instalar.sh --dono <id>"
    echo "DONOS="
    echo "MODELO=sonnet"
    [ -n "${TELEGRAM_API:-}" ] && echo "TELEGRAM_API=$TELEGRAM_API"
  } > "$DESTINO/.env"
  unset TOKEN
  ok "Criei $DESTINO/.env só com leitura para você (600), DONOS vazio"
fi
chmod 600 "$DESTINO/.env"

passo "4/6 Testes das travas"
if [ "${PULAR_TESTES:-0}" = "1" ]; then aviso "Pulados (PULAR_TESTES=1)"; else
  echo "  Rodando a suíte (usa umas 7 chamadas curtas do Claude Code; leva 2 a 5 minutos)…"
  if (cd "$DESTINO" && timeout 900 python3 testes/testar_travas.py > testes/ultimo-resultado.txt 2>&1); then
    ok "$(grep -c '^PASSOU' "$DESTINO/testes/ultimo-resultado.txt") testes PASSOU — TUDO OK"
  else
    grep -E '^FALHOU' "$DESTINO/testes/ultimo-resultado.txt" | head -5 >&2 || true
    erro "Alguma trava falhou. Veja $DESTINO/testes/ultimo-resultado.txt e não ligue o bot antes de resolver."
  fi
fi

passo "5/6 Serviço que mantém o bot no ar"
if [ "${SEM_SERVICO:-0}" = "1" ]; then aviso "Pulado (SEM_SERVICO=1)"; else
  mkdir -p "$HOME/.config/systemd/user"
  sed -e "s#%h/kits/telegram-vps-remoto#$DESTINO#g" "$DESTINO/systemd/telegram-vps-remoto.service" \
    > "$HOME/.config/systemd/user/$UNIDADE.service"
  servico daemon-reload
  servico enable "$UNIDADE" >/dev/null 2>&1 || true
  servico restart "$UNIDADE"
  sleep 3
  [ "$(servico is-active "$UNIDADE")" = "active" ] && ok "Serviço $UNIDADE no ar" || erro "O serviço não subiu: journalctl --user -u $UNIDADE -n 30"
  if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null || echo no)" != "yes" ]; then
    aviso "Para o bot continuar no ar quando você sair do SSH, entre como root e rode uma vez:  loginctl enable-linger $USER"
  else ok "Linger ligado: o bot fica no ar depois que você sai do SSH"; fi
fi

passo "6/6 Falta só dizer que você é o dono"
cat <<EOF
  1. No Telegram, abra o seu bot e mande /start. Ele responde "Este bot é privado." (é o esperado).
  2. Aqui na VPS, veja o seu número:
       journalctl --user -u $UNIDADE -n 20 --no-pager | grep recusado
     Aparece: recusado: from.id=123456789  ← esse é o seu ID.
  3. Grave e reinicie:
       bash $AQUI/instalar.sh --dono 123456789
  Pronto. Peça pelo Telegram; antes de mudar qualquer coisa o bot pergunta "Confirma?".
EOF
