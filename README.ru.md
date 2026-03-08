# OpenClaw Exec-Approvals Health Check

[![Language: Bash](https://img.shields.io/badge/language-bash-green)]()
[![Version: 2.0](https://img.shields.io/badge/version-2.0-blue)]()

> **[README in English / README на английском](README.md)**

Интерактивный bash-скрипт для безопасной проверки и настройки `exec-approvals.json` на вашей VM с OpenClaw.

Если вы только что установили OpenClaw и не знаете, как правильно настроить execution approvals — запустите этот скрипт. Он проверит текущий конфиг, выставит безопасные defaults и позволит выбрать, какие группы разрешений включить.

## Зачем это нужно?

OpenClaw использует файл `~/.openclaw/exec-approvals.json` для контроля того, какие бинарники агент может запускать на хосте. Без правильной настройки:

- Агент может быть заблокирован на безобидных командах (`cat`, `ls`, `grep`)
- Или наоборот — иметь слишком широкие права (`security: "full"`)
- Per-agent переопределения (например `ask: "always"`) могут конфликтовать с defaults
- Чейнинг команд (`&&`, `||`, `;`) и редиректы (`2>/dev/null`) блокируются в режиме allowlist

Этот скрипт выставляет **рекомендованный baseline**: режим `allowlist` + выбранные группы разрешений + правила AGENTS.md + чистое наследование настроек агентов.

## Режимы запуска

| Режим | Команда | Описание |
|-------|---------|----------|
| Интерактивный | `./openclaw-exec-approvals-health-check.sh` | TUI-меню для выбора групп разрешений |
| Все группы | `./openclaw-exec-approvals-health-check.sh --all` | Добавить все 45 бинарников без меню |
| Без AGENTS.md | `./openclaw-exec-approvals-health-check.sh --no-agents-md` | Пропустить модификацию AGENTS.md |
| Комбинированный | `./openclaw-exec-approvals-health-check.sh --all --no-agents-md` | Без интерактива, без AGENTS.md |
| Справка | `./openclaw-exec-approvals-health-check.sh --help` | Показать использование |
| Версия | `./openclaw-exec-approvals-health-check.sh --version` | Показать версию |

При не-терминальном stdin (например, pipe) автоматически включается режим `--all`.

## Что делает скрипт

| Шаг | Действие | Безопасность |
|-----|----------|--------------|
| 1 | Создает бэкап конфига с таймстампом | Можно откатить в любой момент |
| 2 | Проверяет что конфиг существует и валидный JSON | Не трогает битые файлы |
| 3 | Нормализует `defaults` (security, ask, askFallback, autoAllowSkills) | Выставляет безопасные значения |
| 4 | Удаляет per-agent переопределения (security, ask, askFallback) | Агенты наследуют от defaults |
| 5 | Показывает интерактивное меню выбора групп разрешений | Пользователь контролирует что разрешить |
| 6 | Добавляет выбранные бинарники в allowlist **каждого агента** | Не дублирует, не удаляет существующие |
| 7 | Обновляет AGENTS.md с правилами Shell Command Rules | Предотвращает проблемы с чейнингом/редиректами |
| 8 | Перезапускает gateway | Применяет изменения |
| 9 | При ошибке предлагает восстановить бэкап | Интерактивный откат |

### Защитные механизмы

- **safe_mv** — перед перезаписью конфига проверяет что новый файл не пустой и содержит валидный JSON. Предотвращает потерю данных при сбое `jq`.
- **ERR trap** — при любой ошибке скрипт предлагает восстановить бэкап.
- **Идемпотентность** — безопасно запускать повторно. Добавляет только отсутствующее, не дублирует.

### Какие defaults устанавливаются

```json
{
  "defaults": {
    "security": "allowlist",
    "ask": "off",
    "askFallback": "deny",
    "autoAllowSkills": true
  }
}
```

- `security: "allowlist"` — разрешены только бинарники из списка
- `ask: "off"` — не спрашивать подтверждение (если бинарник в allowlist)
- `askFallback: "deny"` — если UI недоступен, блокировать
- `autoAllowSkills: true` — автоматически разрешать бинарники из установленных скиллов

### Per-agent переопределения

Скрипт удаляет `security`, `ask` и `askFallback` у отдельных агентов, чтобы они наследовали от `defaults`. По [документации OpenClaw](https://docs.openclaw.ai/tools/exec-approvals) это рекомендованный подход — переопределять только когда агенту нужна более строгая или более свободная политика. Allowlist'ы сохраняются.

## Группы разрешений

Скрипт организует 45 бинарников в 12 групп разрешений. В интерактивном режиме вы выбираете, какие группы включить:

| # | Группа | Описание | Бинарники | По умолчанию |
|---|--------|----------|-----------|--------------|
| 1 | Shell interpreters | Запуск shell-скриптов и команд | env, sh, bash | ВКЛ |
| 2 | Script interpreters | Запуск Python и Node.js | python3, node | ВКЛ |
| 3 | Text processing | Поиск и обработка текста | grep, cat, sed, awk, sort, uniq, head, tail, cut, tr, wc, printf | ВКЛ |
| 4 | File management | Управление файлами и директориями | ls, pwd, mkdir, rm, cp, mv, chmod, touch | ВКЛ |
| 5 | File discovery | Поиск файлов и путей | find, xargs, which, dirname, basename, realpath, readlink | ВКЛ |
| 6 | File inspection | Инспекция типов файлов и метаданных | stat, file, test | ВКЛ |
| 7 | System & time | Дата/время и задачи по расписанию | date, crontab | ВЫКЛ |
| 8 | Network | HTTP/HTTPS запросы | curl | ВЫКЛ |
| 9 | Package managers | Установка Python-пакетов | pip, pip3 | ВЫКЛ |
| 10 | Multimedia | Обработка аудио и видео | ffmpeg, ffprobe | ВЫКЛ |
| 11 | OpenClaw CLI | Операции OpenClaw и запуск скиллов | openclaw | ВЫКЛ |
| 12 | Custom skills | Бинарники скиллов и виртуальные окружения | tg-reader\*, venv python3 | ВЫКЛ |

Группы 1-6 (35 бинарников) выбраны по умолчанию как необходимые. Группы 7-12 — по желанию.

> Allowlist'ы в OpenClaw — per-agent (без наследования). Скрипт добавляет недостающие записи в allowlist **каждого** агента. Существующие записи с `id`, `lastUsedAt` и другими метаданными сохраняются.

### Интерактивное меню

```
  OpenClaw Exec-Approvals Health Check v2.0.0

  Select permission groups to enable:
  (arrow keys = navigate, space = toggle, enter = confirm, a = all, n = none)

> [x] Shell interpreters     — Run shell scripts and commands
  [x] Script interpreters    — Run Python and Node.js scripts
  [x] Text processing        — Search and process text data
  [x] File management        — Manage files and directories
  [x] File discovery         — Find files and resolve paths
  [x] File inspection        — Inspect file types and metadata
  [ ] System & time          — Date/time and scheduled tasks
  [ ] Network                — Make HTTP/HTTPS requests
  [ ] Package managers       — Install Python packages
  [ ] Multimedia             — Process audio and video
  [ ] OpenClaw CLI           — OpenClaw operations and skill execution
  [ ] Custom skills          — Skill binaries and virtual environments
```

### AGENTS.md — правила для shell-команд

Даже при полном allowlist агент может вызывать промпты, потому что генерирует команды с чейнингом (`cd dir && command`, `cmd1 || cmd2`) и редиректами (`2>/dev/null`, `2>&1`). В режиме allowlist они **блокируются** ([документация](https://docs.openclaw.ai/tools/exec)).

Скрипт автоматически управляет файлом `~/.openclaw/workspace/AGENTS.md`:

- **Создает** файл если он не существует (с Shell Command Rules)
- **Дополняет** правилами если файл существует, но не содержит их
- **Пропускает** если правила уже есть
- **Создает бэкап** перед любой модификацией

Shell Command Rules инструктируют агента:

- Использовать абсолютные пути вместо `cd dir && command`
- Не использовать редиректы (`2>/dev/null`, `2>&1`) — exec tool уже захватывает и stdout и stderr
- Не использовать чейнинг (`&&`, `||`, `;`) — выполнять команды по отдельности

## Требования

- **OS:** Ubuntu / Debian (или другой Linux с `bash`)
- **jq:** `sudo apt install jq`
- **OpenClaw:** установлен и инициализирован (`~/.openclaw/exec-approvals.json` существует)

## Установка и запуск

```bash
# Клонировать
git clone https://github.com/bzSega/SMTools-OpenClaw-Exec-Approvals-Health-Check.git
cd SMTools-OpenClaw-Exec-Approvals-Health-Check

# Сделать исполняемым
chmod +x openclaw-exec-approvals-health-check.sh

# Запустить (интерактивный режим)
./openclaw-exec-approvals-health-check.sh

# Или добавить все группы сразу
./openclaw-exec-approvals-health-check.sh --all
```

### Пример вывода (режим --all)

```
Found config: /home/user/.openclaw/exec-approvals.json
Backup created: /home/user/.openclaw/exec-approvals.backup.20260308_153042.json
Defaults normalized
  Agent "main": removed security=full (inherits from defaults)
Agent overrides cleaned
Mode: --all (all permission groups enabled)
Selected groups: Shell interpreters Script interpreters Text processing ...
Binaries to ensure: 45
  [main] + /usr/bin/curl
  [main] + /usr/bin/tr
  Agent "main": added 2, already present 43
Allowlist populated
Restarting gateway...

--- AGENTS.md Shell Command Rules ---
  AGENTS.md created: /home/user/.openclaw/workspace/AGENTS.md

============================================================
  Done!
============================================================
```

### Проверка после запуска

```bash
openclaw approvals get
```

## Откат изменений

Если что-то пошло не так:

```bash
# Скрипт при ошибке предложит восстановить автоматически.
# Или вручную:
cp ~/.openclaw/exec-approvals.backup.YYYYMMDD_HHMMSS.json ~/.openclaw/exec-approvals.json
openclaw gateway restart
```

## Тесты

В проекте есть 21 автоматический тест, которые проверяют все сценарии работы скрипта:

```bash
bash tests/run-tests.sh
```

Тесты запускаются в изолированных временных директориях, не трогают ваш реальный конфиг.

### Что проверяют тесты

- Бэкап создается и совпадает с оригиналом
- Неправильные defaults исправляются
- Пустой allowlist заполняется полностью
- Существующие записи (id, lastUsedAt) не теряются
- Дубликаты не добавляются
- Ошибки при отсутствии конфига или битом JSON
- Version и socket поля сохраняются
- Per-agent переопределения security/ask/askFallback удаляются
- Gateway restart вызывается
- Флаги `--help` и `--version` работают корректно
- `--all` добавляет все 45 бинарников
- AGENTS.md: создание, дополнение, пропуск если уже есть
- `--no-agents-md` пропускает обновление AGENTS.md
- Бэкап AGENTS.md создается перед модификацией

### Pre-push hook

Тесты автоматически прогоняются перед `git push`:

```bash
# Установка хука (одноразово после клонирования)
cat > .git/hooks/pre-push << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Running tests before push..."
bash "$(git rev-parse --show-toplevel)/tests/run-tests.sh"
echo "Tests passed, pushing..."
EOF
chmod +x .git/hooks/pre-push
```

## Известные проблемы

### Sandbox перекрывает exec-approvals (`ask: off` всё равно спрашивает)

Даже при правильном конфиге exec-approvals (`ask: off`, `security: allowlist`) запросы на подтверждение могут продолжать появляться. Причина — `agents.defaults.sandbox.mode` по умолчанию стоит в `"non-main"`, что тихо перекрывает настройки exec-approvals ([Issue #31036](https://github.com/openclaw/openclaw/issues/31036)).

**Обходное решение:**

```bash
openclaw config set agents.defaults.sandbox.mode off
systemctl --user restart openclaw-gateway.service
```

### Связанные issues OpenClaw

- [#31036](https://github.com/openclaw/openclaw/issues/31036) — sandbox.mode тихо конфликтует с exec-approvals
- [#20141](https://github.com/openclaw/openclaw/issues/20141) — «Always Allow + Never Ask» всё равно спрашивает (фикс в процессе)
- [#26496](https://github.com/openclaw/openclaw/issues/26496) — exec-approvals.sock не создается на headless Linux

## Документация OpenClaw

- [Exec Approvals](https://docs.openclaw.ai/tools/exec-approvals) — формат конфига, allowlist, паттерны
- [Exec Tool](https://docs.openclaw.ai/tools/exec) — как работает выполнение команд
- [Approvals CLI](https://docs.openclaw.ai/cli/approvals) — `openclaw approvals get/set/allowlist`
- [Skills](https://docs.openclaw.ai/cli/skills) — скиллы и autoAllowSkills
- [Tools Overview](https://docs.openclaw.ai/tools) — все инструменты OpenClaw

## Лицензия

MIT
