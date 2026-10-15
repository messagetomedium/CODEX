# GitHub + облачный Codex + GitHub Actions + Pages: инструкция

## Где хранить комплект

**Хранить и загружать в GitHub, не в диалог Codex.** Codex Cloud читает выбранный подключённый GitHub-репозиторий. ZIP нужен только для передачи с компьютера в GitHub.

1. Создай репозиторий GitHub (например, `matryoshka-game`), основная ветка `main`, или используй тот, который уже подключён к Codex.
2. Распакуй архив `Matryoshka_Godot_CloudCodex_v1.0.zip`. **Загружай содержимое распакованной папки, а не ZIP-файл как один объект**, с сохранением вложенных папок и скрытой папки `.github`.
3. Проверь, что `project.godot`, `AGENTS.md`, `export_presets.cfg` и `.github/workflows/web-pages.yml` находятся **в корне репозитория**, а не внутри `matryoshka_godot_codex_v1_0/`.
4. Сделай initial commit в `main`. Если в GitHub Actions увидишь первую неудачу деплоя Pages, настрой Pages по следующему разделу и перезапусти workflow; это не обязательно ошибка Godot.
5. Открой **GitHub → Settings → Pages → Build and deployment → Source: GitHub Actions**. После включения увидишь адрес сайта в Pages или в успешном job `deploy`.
6. В Codex Cloud открой задачи, выбери GitHub-репозиторий и ветку `main`. Вставь `CODEX_FIRST_PROMPT.txt`. Codex создаёт рабочую ветку/PR, а ты принимаешь результат после просмотра. Публикация новой версии происходит, когда изменения попадут в `main` и Actions закончит `deploy`.

**Очень важный момент:** если загрузить только один ZIP в GitHub, workflow не будет обнаружен, а Codex не увидит распакованные GDD и конфигурации как отдельные файлы. Не дублировать их отдельно в чат Codex.

## Что GitHub делает автоматически

Файл `.github/workflows/web-pages.yml` срабатывает при коммите/merge в `main`, при PR и при ручном запуске.

```text
GitHub: исходники проекта + документы + JSON + ассеты
      |
      +--- Codex Cloud: меняет GDScript/.tscn, создаёт PR
      |
      +--- GitHub Actions build (временный Ubuntu runner)
               |
               +--- godot-ci:4.5.2 (Godot + export templates)
               +--- import ресурсов и headless export Web
               +--- build/web/index.html + .wasm + .pck
               |
               +--- upload-pages-artifact
                        |
                        +--- GitHub Pages deploy (только main)
                                 |
                                 +--- HTTPS-сайт с игрой
```

Твой компьютер и установленный на нём Godot **не используются** при удалённой сборке. GitHub выдаёт временную виртуальную машину Linux на время каждой задачи. Она запускает контейнер с готовым Godot и шаблонами экспорта, создаёт HTML/WASM/PCK, отдаёт файлы GitHub Pages и освобождается. **Это не постоянно работающий удалённый игровой сервер.** Игра запускается уже в браузере посетителя.

**После PR:** Actions проверяет сборку, но не публикует её на Pages. **После merge в main:** повторная сборка и публикация. Первоначальный ZIP включает миниатюрную стартовую сцену Godot, поэтому первый запуск CI должен собрать тестовую заглушку; настоящую игру создаёт Codex на первой задаче.

## Что нужно сделать один раз

- Включить Pages и выбрать `Source: GitHub Actions`.
- Убедиться, что основная ветка называется `main`. Если называется иначе, изменить `branches: [main]` и условие deploy в workflow или переименовать ветку.
- Убедиться, что на Actions нет организационного запрета workflow и GitHub Pages.
- Для приватного репозитория проверить, поддерживает ли тариф GitHub публикацию Pages. На GitHub Free Pages доступны для публичных репозиториев; платные тарифы также могут поддерживать Pages из приватного репозитория. **Приватность исходного репозитория не означает автоматически приватный сайт Pages.** Не публиковать секреты, лицензированные записи или конфиденциальные медиа в публикуемый Web-export.

Дополнительный сервер, VPS, домен, доступ по SSH, регистрация на Godot-сервере или установка Godot на Mac **не требуются для такого тестового проекта**.

## Ссылка на игру

Обычно адрес выглядит так:

`https://<github-user>.github.io/<repository-name>/`

Точный URL смотри в **GitHub → Settings → Pages** или **Actions → Build Godot Web and publish Pages → deploy**. URL появится только после успешной публикации.

В `https://...` браузер может запросить доступ к микрофону. Это будет реально работать только после **Task 2**, где Codex напишет JS-мост; первая сборка со стартовой заглушкой и первая игровая blockout-версия без микрофона по дизайну не обязаны принимать голос.

## Если что-то не сработало

- **Actions красный в Build / export templates:** открыть лог `build` и передать его сюда; проверяем `project.godot`, `export_presets.cfg`, совместимость Godot 4.5.2 и установленный шаблон экспорта.
- **Build зелёный, Deploy красный:** проверить `Settings → Pages → Source: GitHub Actions`, политику организации и разрешения workflows.
- **Сайт есть, но чёрный/пустой экран:** открыть консоль браузера (F12) и передать ошибку; проверить WebGL 2, пути ресурсов `res://`, PCK и сообщения Godot.
- **Микрофон не запрашивает разрешение:** убедиться в HTTPS, разрешениях браузера и реализации `web/microphone_bridge.js`. CI тест не заменяет ручную проверку.
- **Поменяли `ui.ru.json`, но сайт прежний:** изменение должно попасть в `main`, успешно пройти сборку и deployment; затем обновить вкладку без старого кеша.
- **Кодекс пишет, что Godot отсутствует:** можно запустить `bash tools/setup_codex_env.sh` в облачной среде (нужен доступ к GitHub releases). Если установка не доступна, можно использовать GitHub Actions для подтверждения сборки.

## Используемые технические документы

- Godot Web export: https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html
- Godot CLI export: https://docs.godotengine.org/en/4.5/tutorials/editor/command_line_tutorial.html
- Godot JavaScriptBridge: https://docs.godotengine.org/en/4.5/tutorials/platform/web/javascript_bridge.html
- GitHub Pages: https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages
- GitHub-hosted runner: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- Godot CI docker image: https://hub.docker.com/r/barichello/godot-ci/tags
