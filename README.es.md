# Telegram VPS remoto — kit listo

[![Telegram VPS remoto](guia/assets/banner-es.jpg)](https://inematds.github.io/telegram-vps-remoto/guia/es/)

**🇧🇷 [Português](README.md) · 🇺🇸 [English](README.en.md) · 🇪🇸 [Español](README.es.md)**

## Qué es

Es un kit listo para que puedas administrar tu VPS desde el celular: un bot de Telegram que envía tus solicitudes a Claude Code, usando la suscripción que ya pagas. Sirve para quien tiene un servidor y quiere preguntar «¿cuánto espacio libre queda?» o «borra los registros antiguos» sin abrir la laptop y sin darle a la IA la llave de la casa. Solo tú puedes hablar con el bot, la IA solo lee y cualquier cambio espera tu «sim» (sí). Necesitas una VPS con Linux y Python 3.10+, Claude Code con la sesión iniciada y una cuenta de Telegram; un instalador hace el resto.

## 📖 Guía de uso

Guía (qué es, cómo funciona y cómo empezar): **https://inematds.github.io/telegram-vps-remoto/guia/es/**

- ¿Quieres entender la idea primero? **Concepto** (control remoto y Jarvis): https://inematds.github.io/telegram-claude-jarvis/guia/es/
- ¿Quieres armar el mismo bot paso a paso, aprendiendo cada protección? **Paso a paso**: https://inematds.github.io/telegram-vps-passo-a-passo/guia/es/
- ¿Quieres el asistente con memoria y un cerebro intercambiable? **Jarvis en la práctica**: https://inematds.github.io/jarvis-na-pratica/guia/es/

## Las protecciones (en el código, no en la solicitud)

| Protección | Qué hace |
|---|---|
| Propietarios | Solo los ID incluidos en `DONOS` pueden hablar con el bot. Lista vacía = nadie; el bot solo registra quién lo intentó. |
| La IA solo lee | La primera llamada a `claude -p` tiene la lectura de contenido restringida a la carpeta `area/` (`Read(./**)`); fuera de ella solo puede usar `df`, `ls`, `free`, `uptime`. Se bloquean claves, SSH, inicios de sesión y `.env`. |
| Sin heredar permisos de la máquina | `--setting-sources "" --strict-mcp-config`: los permisos del `settings.json` del servidor no se aplican al bot. |
| Propuesta + «sim» (sí) | Una solicitud que cambia algo se convierte en una propuesta con los comandos exactos y «Confirma?» (¿Confirmas?). Después de «sim» (sí), **el bot es quien ejecuta**, sin shell; solo `rm`, `rmdir`, `mv`, `cp`, `mkdir`, `touch`, `gzip`, `gunzip`, `tar`, solo dentro de `area/` y solo con las opciones de la lista. Se rechazan los comodines (`*`). |
| La negativa cancela | «sim, não apaga» (sí, no lo borres), «sim, mas antes…» (sí, pero antes…) y «pode listar antes?» (¿puedes listar primero?) no confirman. La solicitud pendiente vence en 10 minutos. |
| Auditoría | La solicitud, la propuesta, la confirmación, el rechazo, la cancelación, el vencimiento y el resultado se guardan en `auditoria.jsonl` (solo el propietario del bot puede leerlo). |

## Instalación técnica

En la VPS, **como usuario común** (no como root):

```bash
git clone https://github.com/inematds/telegram-vps-remoto.git
cd telegram-vps-remoto
bash instalar.sh                      # solicita el token sin mostrarlo, ejecuta las 45 pruebas e inicia el servicio
# en Telegram: envía /start a tu bot; responde "Este bot es privado."
journalctl --user -u telegram-vps-remoto -n 20 --no-pager | grep recusado   # → recusado: from.id=123456789
bash instalar.sh --dono 123456789     # te agrega a DONOS y reinicia
bash instalar.sh --status             # ¿está activo? últimas líneas del registro
```

Requisitos previos: Python 3.10+ (sin paquetes adicionales, solo la biblioteca estándar), Claude Code con la sesión iniciada (`curl -fsSL https://claude.ai/install.sh | bash`, luego `claude` → `/login`) y un bot creado con @BotFather. Probado en Ubuntu 24.04.

¿Solo tienes root? Como root: `adduser <nome>`, copia tu clave (`mkdir -p /home/<nome>/.ssh && cp ~/.ssh/authorized_keys /home/<nome>/.ssh/ && chown -R <nome>: /home/<nome>/.ssh`) y ejecuta `loginctl enable-linger <nome>` (mantiene el bot activo cuando sales de SSH). Después, inicia sesión directamente: `ssh <nome>@IP` (`su -` no sirve para el servicio del usuario).

Archivos:

| Archivo | Para qué sirve |
|---|---|
| `bot.py` | El bot (solo biblioteca estándar, long polling, sin puertos abiertos). |
| `instalar.sh` | Instala o actualiza en `~/kits/telegram-vps-remoto`, crea `.env` (600), ejecuta las pruebas e inicia el servicio; `--dono`, `--status`. Es idempotente. |
| `testes/testar_travas.py` | 45 pruebas de las protecciones (7 llamadas cortas a Claude Code con la suscripción), con un área temporal, auditoría temporal y señuelos de secretos dentro y fuera del área. |
| `systemd/telegram-vps-remoto.service` | Servicio de usuario (`MemoryMax=2G`, se reinicia automáticamente). |
| `ferramentas/telegram_falso.py` | Telegram falso para probar sin un bot real (`TELEGRAM_API=http://127.0.0.1:8081`). |
| `.env.example` | Variables: `TELEGRAM_BOT_TOKEN`, `DONOS`, `MODELO`, `AREA`, `PRAZO_OK_S`, `TELEGRAM_API`. |
| `FALHAS.md` | Cada vulnerabilidad encontrada y su corrección mínima. |

Para probar sin un bot real: ejecuta `python3 ferramentas/telegram_falso.py servidor` en una terminal, `TELEGRAM_API=http://127.0.0.1:8081 DONOS=111 TELEGRAM_BOT_TOKEN=1:x python3 bot.py` en otra y `python3 ferramentas/telegram_falso.py fala --de 111 "quanto espaço livre tem no disco?"` en una tercera.

## El proceso, de principio a fin

Quién participa: 🧠 tú · ⚙️ script/servicio · 🤖 Claude Code (`claude -p`, llamado por el bot)

| # | Paso | Comando | Quién |
|---|---|---|---|
| 1 | Crear el bot con @BotFather y copiar el token | (en Telegram) `/newbot` | 🧠 |
| 2 | Iniciar sesión en la VPS como usuario común y descargar el kit | `git clone … && cd telegram-vps-remoto` | 🧠 |
| 3 | Verificar Python y que Claude Code tenga la sesión iniciada | `bash instalar.sh` (paso 1/6) | ⚙️ |
| 4 | Copiar el bot y crear `.env` con permisos 600 y el token | `bash instalar.sh` (pasos 2–3) | ⚙️ |
| 5 | Ejecutar las 45 pruebas de las protecciones | `bash instalar.sh` (paso 4) | ⚙️🤖 |
| 6 | Iniciar el servicio de usuario | `bash instalar.sh` (paso 5) | ⚙️ |
| 7 | Enviar `/start` y encontrar tu ID en el registro | `journalctl --user -u telegram-vps-remoto … \| grep recusado` | 🧠 |
| 8 | Guardar tu ID como propietario | `bash instalar.sh --dono <id>` | 🧠⚙️ |
| 9 | Enviar una solicitud por Telegram; la IA investiga y propone | (en Telegram) | 🧠🤖 |
| 10 | Decir «sim» (sí) o «não» (no); el bot ejecuta y registra | (en Telegram) | 🧠⚙️ |

## La prueba

- `testar_travas.py` en la VPS de prueba (Ubuntu 24.04): **45 PASARON, TODO OK** — la lista vacía rechaza; la lectura responde; `.env` y el señuelo fuera del área no salen (ni mediante `du --files0-from`); la IA no borra ni con una orden directa; se rechazan 18 comandos u opciones peligrosos; se verifican 14 confirmaciones; flujo solicitud → propuesta → sí → borrado.
- `instalar.sh` se probó de principio a fin en una carpeta nueva de la VPS, con el Telegram falso: 45 pruebas, servicio activo, se rechazó y registró un `/start` de un desconocido, se guardó `--dono`, se respondió una pregunta («Hay 131 GB libres de 193 GB») y se reinstaló conservando `.env`.
- Las vulnerabilidades encontradas por revisores independientes y corregidas están en [FALHAS.md](FALHAS.md).


---

Creado por [INEMA.CLUB](https://inema.club) — gratis, directamente en internet.
