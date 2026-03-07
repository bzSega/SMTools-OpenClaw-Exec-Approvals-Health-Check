# OpenClaw Exec-Approvals Health Check

[![Language: Bash](https://img.shields.io/badge/language-bash-green)]()

> **[README in English / README на английском](README.md)**

Bash-скрипт для безопасной проверки и настройки `exec-approvals.json` на вашей VM с OpenClaw.

Если вы только что установили OpenClaw и не знаете, как правильно настроить execution approvals — запустите этот скрипт. Он проверит текущий конфиг, выставит безопасные defaults и добавит стандартные системные утилиты в allowlist.

## Зачем это нужно?

OpenClaw использует файл `~/.openclaw/exec-approvals.json` для контроля того, какие бинарники агент может запускать на хосте. Без правильной настройки:

- Агент может быть заблокирован на безобидных командах (`cat`, `ls`, `grep`)
- Или наоборот — иметь слишком широкие права (`security: "full"`)
- Per-agent переопределения (например `ask: "always"`) могут конфликтовать с defaults

Этот скрипт выставляет **рекомендованный baseline**: режим `allowlist` + набор стандартных утилит Linux + чистое наследование настроек агентов.

## Что делает скрипт

| Шаг | Действие | Безопасность |
|-----|----------|--------------|
| 1 | Создает бэкап конфига с таймстампом | Можно откатить в любой момент |
| 2 | Проверяет что конфиг существует и валидный JSON | Не трогает битые файлы |
| 3 | Нормализует `defaults` (security, ask, askFallback, autoAllowSkills) | Выставляет безопасные значения |
| 4 | Удаляет per-agent переопределения (security, ask, askFallback) | Агенты наследуют от defaults |
| 5 | Добавляет отсутствующие системные утилиты в allowlist **каждого агента** | Не дублирует, не удаляет существующие |
| 6 | Перезапускает gateway | Применяет изменения |
| 7 | При ошибке предлагает восстановить бэкап | Интерактивный откат |

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

### Какие утилиты добавляются в allowlist

Скрипт проверяет наличие 42 записей в allowlist каждого агента:

**Shell и интерпретаторы:**
`/usr/bin/env`, `/bin/sh`, `/usr/bin/bash`, `/usr/bin/python3`, `/usr/bin/node`

**Сеть:** `/usr/bin/curl`

**Текст и данные:**
`grep`, `cat`, `sed`, `awk`, `sort`, `uniq`, `head`, `tail`, `cut`, `tr`, `wc`, `printf`

**Файлы и директории:**
`find`, `xargs`, `ls`, `pwd`, `mkdir`, `rm`, `cp`, `mv`

**Инспекция:**
`test`, `which`, `stat`, `file`, `date`

**Пути:**
`dirname`, `basename`, `realpath`, `readlink`

**Пакетные менеджеры и инструменты:**
`pip`, `pip3`, `ffmpeg`, `ffprobe`, `openclaw`

**Скиллы:**
`~/.local/bin/tg-reader*` (чтение Telegram-каналов)

**Виртуальные окружения:**
`~/.venv/*/bin/python3` (python3 из любого venv)

> Allowlist'ы в OpenClaw — per-agent (без наследования). Скрипт добавляет недостающие записи в allowlist **каждого** агента. Существующие записи с `id`, `lastUsedAt` и другими метаданными сохраняются.

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

# Запустить
./openclaw-exec-approvals-health-check.sh
```

### Пример вывода

```
Found config: /home/user/.openclaw/exec-approvals.json
Backup created: /home/user/.openclaw/exec-approvals.backup.20260307_153042.json
Defaults normalized
  Agent "main": removed security=full (inherits from defaults)
  Agent "main": removed ask=always (inherits from defaults)
  Agent "main": removed askFallback=full (inherits from defaults)
Agent overrides cleaned
  + /usr/bin/curl
  + /usr/bin/tr
Allowlist: added 2, already present 34
Restarting gateway...
Done. Backup: /home/user/.openclaw/exec-approvals.backup.20260307_153042.json
To rollback: cp '...' '~/.openclaw/exec-approvals.json' && openclaw gateway restart
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

В проекте есть 13 автоматических тестов, которые проверяют все сценарии работы скрипта:

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
- Allowlist агента `main` не затрагивается
- Новые записи идут в `agents["*"]`, а не в `agents["main"]`
- Per-agent переопределения security/ask/askFallback удаляются
- Gateway restart вызывается

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
