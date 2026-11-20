# Telegram VPS remoto — kit listo

[![Telegram VPS remoto](guia/assets/banner-es.jpg)](https://inematds.github.io/telegram-vps-remoto/guia/es/)

**🇧🇷 [Português](README.md) · 🇺🇸 [English](README.en.md) · 🇪🇸 [Español](README.es.md)**

## Qué es

Es un kit listo para que administres tu VPS desde el celular: un bot de Telegram que envía tus pedidos a Claude Code, con la suscripción que ya pagas. Sirve para quienes tienen un servidor y quieren preguntar «¿cuánto espacio libre hay?», «¿cuánta memoria queda?» u organizar los archivos que pusieron en la carpeta del bot, sin abrir la laptop y sin darle a la IA la llave de la casa. Solo tú puedes hablar con el bot, la IA solo lee y cualquier cambio espera tu «sim» (sí). Necesitas una VPS Linux (probado en Ubuntu 24.04, el Linux más usado en servidores), Python 3.10+, Claude Code con la sesión iniciada y una cuenta de Telegram; un instalador hace el resto.

## 📖 Guía de uso

Guía (qué es, cómo funciona y cómo empezar): **https://inematds.github.io/telegram-vps-remoto/guia/es/**

- ¿Quieres entender la idea primero? **Concepto** (control remoto y Jarvis): https://inematds.github.io/telegram-claude-jarvis/guia/es/
- ¿Quieres armar el mismo bot paso a paso, aprendiendo cada protección? **Paso a paso**: https://inematds.github.io/telegram-vps-passo-a-passo/guia/es/
- ¿Quieres el asistente con memoria y cerebro intercambiable? **Jarvis en la práctica**: https://inematds.github.io/jarvis-na-pratica/guia/es/

## Las protecciones (en el código, no en el pedido)

| Protección | Qué hace |
|---|---|
| Propietarios | Solo los IDs de `DONOS` pueden hablar con el bot. Lista vacía = nadie; el bot solo registra quién lo intentó. |
| La IA solo lee | 1.ª llamada de `claude -p` con la lectura de contenido restringida a la carpeta `area/` (`Read(./**)`, tampoco mediante enlaces simbólicos); fuera de ella, solo `df`, `ls`, `free`, `uptime`. Claves, SSH, inicios de sesión y `.env` denegados. |
| Sin heredar permisos de la máquina | `--setting-sources "" --strict-mcp-config`: los permisos del `settings.json` del servidor no se aplican al bot. |
| Propuesta + «sim» (sí) | Un pedido que cambia algo se convierte en una propuesta con los comandos exactos y «Confirma? (sim/não)» (¿Confirmas? [sí/no]). Después del «sim» (sí), **quien lo ejecuta es el bot**, sin shell, solo `rm`, `rmdir`, `mv`, `cp`, `mkdir`, `touch`, `gzip`, `gunzip`, `tar`, solo dentro de `area/` y solo con las opciones de la lista. Se rechazan los comodines (`*`). |
| La negativa cancela | «sim» (sí), «sí» y «yes» confirman; «sim, não apaga» (sí, no lo borres), «sí, pero antes», «¿puedes listar antes?» no. El pedido pendiente dura 10 min. |
| En el idioma del propietario | La IA responde en el idioma en que escribes; solo las frases fijas («Confirma? (sim/não)» [¿Confirmas? (sí/no)], «Este bot é privado.» [Este bot es privado.]) quedan en portugués. |
| Auditoría | El pedido, la propuesta, el «sim» (sí), el rechazo, la cancelación, el vencimiento y el resultado se guardan en `auditoria.jsonl` (solo el propietario del bot puede leerlo). |

## Instalación técnica

En la VPS, **como usuario común** (no root):

```bash
git clone https://github.com/inematds/telegram-vps-remoto.git
cd telegram-vps-remoto
bash instalar.sh                      # solicita el token sin mostrarlo, ejecuta las 52 pruebas (2–5 min), activa el servicio
# en Telegram: envía /start a tu bot; dice "Este bot é privado."
journalctl --user -u telegram-vps-remoto -n 20 --no-pager | grep recusado   # → recusado: from.id=123456789
bash instalar.sh --dono 123456789     # te registra en DONOS y reinicia
bash instalar.sh --status             # ¿está activo? últimas líneas del registro
```

Requisitos previos: Python 3.10+ (sin paquetes adicionales, solo la biblioteca estándar), Claude Code con la sesión iniciada (`curl -fsSL https://claude.ai/install.sh | bash`, después `claude` → `/login`) y un bot creado en @BotFather. Probado en Ubuntu 24.04.

¿Solo tienes root? Como root: `adduser <nome>`, copia tu clave (`mkdir -p /home/<nome>/.ssh && cp ~/.ssh/authorized_keys /home/<nome>/.ssh/ && chown -R <nome>: /home/<nome>/.ssh`) y `loginctl enable-linger <nome>` (mantiene el bot activo cuando sales de SSH). Después, inicia sesión directamente: `ssh <nome>@IP` (`su -` no sirve para el servicio del usuario).

**La carpeta de trabajo.** El bot solo lee y cambia lo que está en `area/` (junto a `bot.py`), que empieza vacía: coloca allí los archivos que quieres que lea u organice. Para usar otra carpeta, configura `AREA=/caminho` en `.env` y ejecuta `bash instalar.sh --status` después de reiniciar; apunta solo a una carpeta que aceptes que lea y cambie con tu «sim» (sí). Los registros del sistema (`/var/log`) quedan fuera, a propósito.

**Términos.** *root*: el administrador del servidor (el bot no se ejecuta como root). *linger*: mantiene activos los servicios de tu usuario después de que sales de SSH. *registro del bot*: las líneas que escribe el servicio mientras se ejecuta (`journalctl --user -u telegram-vps-remoto`). *clave de API*: contraseña para cobros por uso; el kit no usa ninguna.

Archivos:

| Archivo | Para qué sirve |
|---|---|
| `bot.py` | El bot (solo biblioteca estándar, long polling, sin puertos abiertos). |
| `instalar.sh` | Instala/actualiza en `~/kits/telegram-vps-remoto`, crea `.env` (600), ejecuta las pruebas y activa el servicio; `--dono`, `--status`. Idempotente. |
| `testes/testar_travas.py` | 52 pruebas de las protecciones (8 llamadas breves de Claude Code con la suscripción), con carpeta y auditoría temporales, y señuelos de secretos dentro y fuera de la carpeta. |
| `systemd/telegram-vps-remoto.service` | Servicio de usuario (`MemoryMax=2G`, se reinicia solo). |
| `ferramentas/telegram_falso.py` | Telegram falso para probar sin un bot real (`TELEGRAM_API=http://127.0.0.1:8081`). |
| `.env.example` | Variables: `TELEGRAM_BOT_TOKEN`, `DONOS`, `MODELO`, `AREA`, `PRAZO_OK_S`, `TELEGRAM_API`. |
| `FALHAS.md` | Cada vulnerabilidad encontrada y la corrección mínima. |

Para probar sin un bot real: ejecuta `python3 ferramentas/telegram_falso.py servidor` en una terminal, `TELEGRAM_API=http://127.0.0.1:8081 DONOS=111 TELEGRAM_BOT_TOKEN=1:x python3 bot.py` en otra y `python3 ferramentas/telegram_falso.py fala --de 111 "quanto espaço livre tem no disco?"` en una tercera.

## El proceso, de principio a fin

Quién hace qué: 🧠 tú · ⚙️ script/servicio · 🤖 Claude Code (`claude -p`, invocado por el bot)

| # | Paso | Comando | Quién |
|---|---|---|---|
| 1 | Crear el bot en @BotFather y copiar el token | (en Telegram) `/newbot` | 🧠 |
| 2 | Entrar a la VPS como usuario común y descargar el kit | `git clone … && cd telegram-vps-remoto` | 🧠 |
| 3 | Verificar Python y que Claude Code tenga la sesión iniciada | `bash instalar.sh` (paso 1/6) | ⚙️ |
| 4 | Copiar el bot y crear `.env` 600 con el token | `bash instalar.sh` (pasos 2–3) | ⚙️ |
| 5 | Ejecutar las 52 pruebas de las protecciones | `bash instalar.sh` (paso 4) | ⚙️🤖 |
| 6 | Activar el servicio de usuario | `bash instalar.sh` (paso 5) | ⚙️ |
| 7 | Enviar `/start` y encontrar tu ID en el registro | `journalctl --user -u telegram-vps-remoto … \| grep recusado` | 🧠 |
| 8 | Registrar tu ID como propietario | `bash instalar.sh --dono <id>` | 🧠⚙️ |
| 9 | Pedir algo por Telegram; la IA investiga y propone | (en Telegram) | 🧠🤖 |
| 10 | Decir «sim» (sí) o «não» (no); el bot ejecuta y registra | (en Telegram) | 🧠⚙️ |

## La prueba

- `testar_travas.py` en la VPS de prueba (Ubuntu 24.04): **52 APROBADAS, TODO OK** — la lista vacía rechaza, la lectura responde, `.env` y el señuelo fuera de la carpeta no salen (ni mediante `du --files0-from` ni por enlace simbólico), la IA no borra ni con una orden directa, se rechazan 18 comandos/opciones peligrosos, se verifican 20 confirmaciones (incluido «sí»), flujo pedido → propuesta → «sim» (sí) → borrado.
- `instalar.sh` probado de principio a fin en una carpeta nueva de la VPS, con el Telegram falso: la suite de esa versión (45) pasó, el servicio quedó activo, se rechazó y registró un `/start` de una persona desconocida, se registró `--dono`, se respondió una pregunta («Hay 131 GB libres de 193 GB») y se reinstaló conservando `.env`.
- Las vulnerabilidades encontradas por revisores independientes y corregidas están en [FALHAS.md](FALHAS.md).


---

Hecho por [INEMA.CLUB](https://inema.club) — gratis y directo en internet.
