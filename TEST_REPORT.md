# Проверка Tasks 0–1 — 15 октября 2026

Выполнены только задачи 0 и 1. Движок: **Godot 4.5.2 standard**, GDScript,
Compatibility / WebGL 2.0, однопоточный Web export. Задача 2 не начата.

## Результат

- Точка входа — `scenes/MainMenu.tscn`: три карточки в горизонтальном ряду,
  иллюстрация сверху, название и описание ниже, без общего заголовка.
  Только «Забить гол» принимает выбор мышью; две другие карточки disabled.
- `scenes/GoalLevel.tscn`: статичное перспективное поле, отдельные примитивы
  ворот, вратаря, одного защитника и большого мяча внизу по центру.
  Исходный PNG изучен как референс композиции и не используется как фон.
- Инструкция — вложенный `ui/GameInfoPopup.tscn`, поверх уже показанного поля.
  Ровно три слота инфографики в одной строке, цель и «Начать».
- «Начать» заменяет содержимое общего попапа честным сообщением о будущем
  подключении микрофона. Мир остаётся статичным, счёт 0/3, попытки 0/6,
  индикатор голоса пустой. Голос, физика, коллизии и результаты не реализованы.
- Глобальный «Сброс» находится в CanvasLayer 100 и работает из меню, intro,
  диагностического состояния и во время переходов. Отложенный вход в уровень
  отменяется сбросом; освобождение сцены отменяет её Tween без stale callback.
- Все видимые строки читаются из `ui.ru.json`, UI-размещение — из
  `ui_layout.json`, анимации — программные Godot Tween с именованными
  профилями `ui_animations.json`. При durationMs=0 конечное состояние мгновенное.
  Ранний hover не оставляет карточку полупрозрачной.

## Исходные ограничения и исправления

Коммит main `8bc07f7e8328cf5bab40470bb92efd3137ee65fe` **не содержал**
`.github/workflows/web-pages.yml` и вообще каталога `.github`, несмотря на
ссылки в документации. Первая проверка `validate_handoff.py` завершилась
`Missing .github/workflows/web-pages.yml`. Поэтому отсутствующий workflow
восстановлен по GITHUB_SETUP/TECH: `barichello/godot-ci:4.5.2`, проверка на PR,
сборка main, `upload-pages-artifact@v3`, `deploy-pages@v4`, публикация только main.
Существующий файл не был заменён: его не было ни в checkout, ни в истории.

Системный Godot — 4.6.3, он не использован для проверки проекта. Отдельно
установлен официальный 4.5.2 с проверкой обоих архивов по официальному
SHA512-SUMS.txt. Установщик исправлен для установки только однопоточных Web
шаблонов и поддержки GODOT_INSTALL_DIR / XDG_DATA_HOME. Проверены установка
с нуля и повторный запуск. XDG_CONFIG_HOME направлен в writable-каталог.

Утверждённые GDD, UI-сценарий, TECH, AGENTS, gameplay.json, профили анимаций,
export_presets.cfg и исходный референс сохранены. В ui.ru.json добавлена только
строка `common.microphone.notImplemented`. В ui_layout.json добавлены параметры
меню/попапа/HUD и настроен размер стартового мяча по референсу.

## Выполненные проверки

| Проверка | Результат |
|---|---|
| `python3 tools/validate_handoff.py` | PASS: 5 JSON, 3 карточки, 3 инструкции, правила 3/6/1, 21 профиль, Web/Pages |
| Godot `--headless --path . --editor --import` | PASS, без ошибок |
| `--script res://tests/config_smoke_test.gd` | PASS: прочитаны все 5 JSON, 3/6/1 |
| `--script res://tests/task_1_smoke_test.gd` | **48/48 PASS**, без пропусков и утечек |
| `--export-release Web build/web/index.html` | PASS, получены непустые HTML/JS/WASM/PCK |
| `bash -n` для обоих shell-скриптов, разбор workflow YAML, `git diff --check` | PASS |
| Chromium + Python Playwright, WebGL 2.0 | PASS: реальные клики по карточкам/«Начать»/«Сброс», повторный вход, отсутствие запроса mic |
| Chromium 1280×720 и 1024×768 | PASS: снимки, на 4:3 композиция 16:9 с полями, без обрезания |

Главная повторяемая проверка из корня репозитория:

```bash
bash tools/check_tasks_0_1.sh
```

Перед ней в этой облачной среде:

```bash
export GODOT_INSTALL_DIR=/workspace/.tools/godot-4.5.2/bin
export XDG_DATA_HOME=/workspace/.tools/godot-4.5.2/data
export XDG_CONFIG_HOME=/workspace/.tools/godot-4.5.2/config
export XDG_CACHE_HOME=/workspace/.cache
export PATH="$GODOT_INSTALL_DIR:$PATH"
```

Логи текущей проверки: `build/checks/{import,config,task-1,web}.log`.
Web-артефакты: `build/web/`; WASM около 38 MB. Они игнорируются Git.
Дополнительный browser-тест: `python3 tests/web_smoke_test.py` при локально
запущенном HTTP-сервере каталога `build/web` на порту 8765. Требуются Python
Playwright и Chromium (в текущей среде установлены).

Реальные снимки браузера и browser-log.json сохранены вне исходников:
`/workspace/artifacts/matryoshka-task-1/` (`menu.png`, `intro.png`,
`after-start.png`, `menu-4x3.png`). Снимки также доступны прямо в GitHub: 
[меню](docs/review/task-1/menu.png), [инструкция](docs/review/task-1/intro.png), 
[поле после «Начать»](docs/review/task-1/after-start.png). Каталог `docs/review` 
содержит `.gdignore`, поэтому эти изображения не попадают в игровую сборку. 
В журнале браузера есть только необязательный
404 для favicon.ico и предупреждения SwiftShader о ReadPixels при снимках;
ошибок Godot/GDScript/WebGL-приложения нет. Физический микрофон и вывод на
динамики не тестировались: в этой задаче нет реализации микрофона/звуков.

## Перед публикацией

Выполненные локальные проверки не означают, что GitHub Actions или Pages уже
сработали. После отправки ветки создать PR в main и дождаться build. Включить
**Settings → Pages → Source: GitHub Actions**. После проверки PR и merge в main
дождаться успешных build и deploy в **Actions → Build Godot Web and publish Pages**.
Точный URL появится в job deploy и Settings → Pages. Ожидаемый адрес:
`https://messagetomedium.github.io/CODEX/` — текущая публикация не подтверждена.
Не переходить к задаче 2 без подтверждения пользователя.

## Изменённые файлы

- `project.godot`; `scenes/MainMenu.tscn`, `scenes/GoalLevel.tscn`, `ui/GameInfoPopup.tscn`.
- `scripts/app/{app_controller,config_service,text_catalog}.gd`.
- `scripts/ui/{main_menu,ui_factory,illustration,game_info_popup,overlay_manager,ui_animation_controller}.gd`.
- `scripts/goal/{goal_level,goal_world,world_entity,blockout_shapes}.gd`.
- `data/config/ui.ru.json`, `data/config/ui_layout.json`.
- `tests/task_1_smoke_test.gd`, `tests/web_smoke_test.py`.
- `tools/setup_codex_env.sh`, `tools/check_tasks_0_1.sh`.
- `.github/workflows/web-pages.yml` (отсутствовал, восстановлен), `.gitignore`, `TEST_REPORT.md`.
- `docs/review/task-1/*.png`, `docs/review/.gdignore` — доступные через GitHub снимки.
- Godot `.gd.uid` и `.png.import` — метаданные импорта; исходный PNG не изменён.
