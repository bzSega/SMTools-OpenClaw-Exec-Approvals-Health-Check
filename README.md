# OpenClaw Exec-Approvals Health Check

Bash-скрипт для безопасной проверки и настройки `exec-approvals.json` на вашей VM с OpenClaw.

Если вы только что установили OpenClaw и не знаете, как правильно настроить execution approvals — запустите этот скрипт. Он проверит текущий конфиг, выставит безопасные defaults и добавит стандартные системные утилиты в allowlist.

## Зачем это нужно?

OpenClaw использует файл `~/.openclaw/exec-approvals.json` для контроля того, какие бинарники агент может запускать на хосте. Без правильной настройки:

- Агент может быть заблокирован на безобидных командах (`cat`, `ls`, `grep`)
- Или наоборот — иметь слишком широкие права (`security: "full"`)

Этот скрипт выставляет **рекомендованный baseline**: режим `allowlist` + набор стандартных утилит Linux.

## Что делает скрипт

| Шаг | Действие | Безопасность |
|-----|----------|--------------|
| 1 | Создает бэкап конфига с таймстампом | Можно откатить в любой момент |
| 2 | Проверяет что конфиг существует и валидный JSON | Не трогает битые файлы |
| 3 | Нормализует `defaults` (security, ask, askFallback, autoAllowSkills) | Выставляет безопасные значения |
| 4 | Добавляет отсутствующие системные утилиты в `agents["*"].allowlist` | Не дублирует, не удаляет существующие |
| 5 | Перезапускает gateway | Применяет изменения |
| 6 | При ошибке предлагает восстановить бэкап | Интерактивный откат |

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

### Какие утилиты добавляются в allowlist

Скрипт проверяет наличие 35 стандартных утилит Linux:

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

> Скрипт добавляет записи только в `agents["*"].allowlist`. Записи других агентов (например, `main`) не затрагиваются. Существующие записи с `id`, `lastUsedAt` и другими метаданными сохраняются.

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
  + /usr/bin/curl
  + /usr/bin/tr
  + /usr/bin/xargs
  + /usr/bin/stat
  + /usr/bin/file
Allowlist: added 5, already present 30
Restarting gateway...
Done. Backup: /home/user/.openclaw/exec-approvals.backup.20260307_153042.json
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

В проекте есть 12 автоматических тестов, которые проверяют все сценарии работы скрипта:

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
- Агент `main` не затрагивается
- Gateway restart вызывается

### Pre-push hook

Тесты автоматически прогоняются перед `git push`:

```bash
# Установка хука (одноразово после клонирования)
cp .git/hooks/pre-push.sample .git/hooks/pre-push 2>/dev/null || true
cat > .git/hooks/pre-push << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "Running tests before push..."
bash "$(git rev-parse --show-toplevel)/tests/run-tests.sh"
echo "Tests passed, pushing..."
EOF
chmod +x .git/hooks/pre-push
```

## Документация OpenClaw

- [Exec Approvals](https://docs.openclaw.ai/tools/exec-approvals) — формат конфига, allowlist, паттерны
- [Exec Tool](https://docs.openclaw.ai/tools/exec) — как работает выполнение команд
- [Skills](https://docs.openclaw.ai/cli/skills) — скиллы и autoAllowSkills
- [Tools Overview](https://docs.openclaw.ai/tools) — все инструменты OpenClaw

## Лицензия

MIT
