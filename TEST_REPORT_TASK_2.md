# Task 2 — микрофон и отладочный источник

Выполнена только задача 2 на Godot 4.5.2 standard / GDScript. Движение мяча,
физика, столкновения и счёт не добавлены; подтверждение для Task 3 ещё требуется.

## Что готово

- Запрос getUserMedia только по «Начать»/«Повторить подключение»; AudioContext
  возобновляется из обработчика кнопки. MediaStreamAudioSource подключён только
  к AnalyserNode, его выход отключён. Запись, мониторинг и отправка голоса отсутствуют.
- Асинхронные pending/active/denied/not-found/busy/error; сообщения и Retry
  поверх того же поля, без новых экранов. При Retry инструкция не повторяется.
- RMS/peak с окном из gameplay.json; нормализация, автоматический шумовой порог,
  длительный тихий ввод и одно событие резкого импульса с release/cooldown.
  Нормализованный VoiceFrame готов для будущей механики.
- HUD-шкала следует измеренному сигналу через Godot Tween и профиль
  hud.voiceMeter. Статус подключённого микрофона сообщает границы текущего этапа.
- Сброс, потеря устройства и dispose освобождают поток/контекст. Поздний ответ
  на отменённый запрос немедленно останавливает полученный поток. Ошибка во время
  закрытия попапа отменяет устаревший переход в ACTIVE.
- Только явный `?debug=1` или локальный `--voice-debug` включает DebugVoiceInput.
  W — тихий ввод, Space — импульс, 1/2/3 — сила. Обычный отказ микрофона не включает клавиатуру.

## Проверки

| Проверка | Результат |
|---|---|
| validate_handoff.py | PASS: 5 JSON, 3/6/1, 3 карточки/инструкции, 22 профиля |
| Godot 4.5.2 headless import | PASS, без ошибок |
| config_smoke_test.gd | PASS: все 5 конфигов |
| task_1_smoke_test.gd | 48/48 PASS: регрессия меню/поля/сброса; native Start честно сообщает Web-only |
| voice_detector_test.gd, обычный запуск | 21/21 PASS |
| voice_detector_test.gd, явный --voice-debug | 21/21 PASS |
| task_2_smoke_test.gd | 22/22 PASS: состояния, данные HUD, Retry, гонки переходов и cleanup |
| Node microphone_bridge_test.cjs | 11/11 PASS, без пропусков |
| Web export | PASS: HTML/JS/WASM/PCK |
| Chromium/WebGL 2.0 + искусственный MediaStream | PASS: RMS → HUD, denial/missing/busy → Retry, reset до/после разрешения, закрытие tracks, no monitoring/upload, debug opt-in, меню и 4:3 |

Общая команда: `GODOT_BIN=/workspace/.tools/godot-4.5.2/godot bash tools/check_tasks_0_1.sh`.
Историческое имя скрипта сохранено; он теперь проверяет и задачу 2.
Логи — `build/checks/`, сборка — `build/web/`, оба каталога игнорируются Git.
`build/.gdignore` создаётся перед импортом, чтобы результаты сборок/тестов
не импортировались и не попадали обратно в PCK. Pages workflow сохранён по структуре и версии Godot; в установку зависимостей
добавлен Node.js для новых JS-тестов. Он запускает расширенный скрипт проверок.

Браузерная проверка: `python3 tests/web_smoke_test.py` после запуска локального
HTTP-сервера каталога build/web на порту 8765. Она использует Chromium fake
capture, синтетический сигнал и имитацию отказов. Физический микрофон не использован.
Постоянный тестовый тон шумоподавитель Chromium подавлял как фон; проверка
использует меняющийся синтетический сигнал при сохранённом noiseSuppression=true.

Снимки реального запущенного Web-приложения:
[активный микрофон](docs/review/task-2/microphone-active.png),
[отказ](docs/review/task-2/microphone-denied.png),
[явный debug](docs/review/task-2/debug-input.png).
Вход на этих снимках искусственный. Полный browser-log.json и генерируемый WAV
лежат вне проекта в /workspace/artifacts/matryoshka-task-2/.

## Что проверяет владелец

На https://messagetomedium.github.io/CODEX/ открыть «Забить гол» → «Начать»,
разрешить микрофон и проверить шкалу на своём устройстве. Проверить запрет
доступа/Retry, отсутствие собственного голоса в динамиках, остановку доступа
после «Сброс». Разрешения Chrome/Firefox/Safari и реальная акустика требуют
этой ручной проверки. Пороговые значения — начальные параметры балансировки;
по её результатам возможна настройка. Автоматические проверки не заменяют её.

Публикация выполняется прежним workflow после отправки проверенного коммита
в main; он отдельно проверяет публичный URL и точный SHA сборки. Успешный
деплой этого этапа сообщается в ответе после завершения Actions.

## Изменённые файлы

- web/microphone_bridge.js; web/README.md.
- scripts/voice/{voice_input,voice_frame,browser_voice_input,debug_voice_input,voice_input_factory,voice_detector}.gd и UID.
- scripts/goal/goal_level.gd; scripts/ui/{game_info_popup,overlay_manager,ui_animation_controller}.gd.
- data/config/{gameplay,ui.ru,ui_layout,ui_animations}.json — новые параметры микрофона, строки, размещение и профиль статуса.
- tests/{voice_detector_test,task_2_smoke_test}.gd и UID; tests/microphone_bridge_test.cjs.
- tests/task_1_smoke_test.gd; tests/web_smoke_test.py — регрессия и Web-микрофон.
- .github/workflows/web-pages.yml — зависимость Node.js для JS-тестов.
- tools/check_tasks_0_1.sh; tools/validate_handoff.py — расширение проверок и точный счёт профилей.
- WEB_PREVIEW.md; TEST_REPORT_TASK_2.md; docs/review/task-2/*.png.

Утверждённые документы, референс и renderer/export preset не изменены. В workflow
изменена только установка Node.js: без неё новый JS-тест в контейнере завершался
кодом 127. Порядок build/deploy и публикация только main сохранены.
