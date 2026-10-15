# «Второй комментатор»: три полных уровня

Godot **4.5.2.stable.official.6ce3de25a**, standard/GDScript, Compatibility,
однопоточный Web. Адрес: https://messagetomedium.github.io/CODEX/.

Реализация соответствует приложенному [ТЗ](docs/COMMENTATOR_TZ_v1.0.md).
Второй приложенный файл содержит то же ТЗ с вводным поручением; прочитан
через полное сравнение. Изменения подготовлены в `codex/commentator-three-levels`.

## Что готово

- Третья карточка активна, открывает CommentatorLevel в том же проекте.
  До Start — только фон уровня под существующей инструкцией; Reset доступен.
- Все три уровня по 60 секунд: по шесть пар ведущий/игрок, разные фразы,
  36/48/60 слов, собственные абсолютные таймкоды и возрастающий темп.
- Ведущий в демонстрации отвечает текстом. Игрок получает предупреждение
  2 / 1,5 / 1 секунды, затем читает компактную караоке-строку/блок.
- Обычные слова используют Regular, акценты — настоящий Bold. Над каждым
  акцентом свои 1–2 стрелки ↑ с мягким Tween. Подсветка движется по часам,
  даже при тишине, и не означает распознанное правильное слово.
- Каждое слово оценивается независимо: тайминг 40%, активность 30%,
  относительная громкость 30%. Пауза между словами не обязательна; ритмические
  подъёмы дают хорошие оценки, гул/тишина/один мощный пик не заменяют реплику.
- Одна плавная шкала интереса. Успех — только средняя оценка ≥50/60/65.
  Промежуточные результаты, Retry/Next и финал с общей статистикой и результатами каждого уровня —
  общий GameInfoPopup. Микрофон единственный, Next не просит новый доступ.
- Ошибка микрофона приостанавливает время, оценку и медиа. Reset в середине
  реплики и при ожидании доступа освобождает ресурсы, включая позднее разрешение.
- Нет записи речи, распознавания текста, pitch tracking, микрофонного
  мониторинга, дополнительной постоянной шкалы голоса или баллов возле слов.

## Новые файлы и общие расширения

- `scenes/CommentatorLevel.tscn` и `scripts/commentator/commentator_level.gd`:
  общий цикл INTRO/MIC_REQUEST/TRANSITION/ACTIVE/MIC_ERROR/RESULT.
- `logic/commentator_timeline.gd`, `commentator_word_scorer.gd`,
  `commentator_session.gd`: независимая модель времени/слов/оценки/интереса.
- `ui/commentator_karaoke.gd`, `commentator_hud.gd`: минимальный HUD и пословный UI.
- `commentator_world.gd`, `booth_layer.gd`, `commentator_media.gd`: блочная будка,
  декоративный матч, сменные слои и локальные optional media.
- `data/config/commentator_levels.json`, `commentator_gameplay.json`,
  `commentator_layout.json`; строки/анимации расширяют общие JSON.
- `assets/commentator/fonts/`: DejaVu Sans Regular/Bold и полная лицензия.
  Web artifact включает `LICENSE-DejaVu.txt`.
- Общие App/Menu/ConfigService получили маршрут и загрузку трёх конфигов.
  GameInfoPopup получил необязательный размер заголовков инструкции и
  высоту статистики по числу строк. Существующие значения по умолчанию сохранены.
- Добавлены модельные/сценовые/браузерные тесты и расширен существующий checker.
  Прежние тесты меню учитывают, что все три карточки теперь активны.
- Обновлены GDD, сценарий UI, архитектура, WEB_PREVIEW, CHANGELOG и
  [COMMENTATOR_GAMEPLAY.md](COMMENTATOR_GAMEPLAY.md).

Код/балансы/тексты/ассеты Goal и Stands, их микрофон, `project.godot`,
`export_presets.cfg` и `.github/workflows/web-pages.yml` сохранены.

## Проверки

```bash
GODOT_BIN=/workspace/.tools/godot-4.5.2/godot bash tools/check_tasks_0_1.sh
python3 tests/commentator_visual_review.py
python3 tests/commentator_web_test.py
python3 tests/web_smoke_test.py --output /workspace/artifacts/matryoshka-commentator/goal
python3 tests/stands_visual_review.py --modes game-win --output /workspace/artifacts/matryoshka-commentator/stands
python3 tests/stands_web_test.py --output /workspace/artifacts/matryoshka-commentator/stands
```

- Handoff: **12 JSON**, три активные карточки, полные непрерывные расписания,
  непересекающиеся слова, корректные веса и 52 именованных профиля.
- Импорт и Web export: успешно, сформированы HTML/JS/WASM/PCK, лицензия шрифтов.
- Общая suite: **626 проверок Godot, 0 ошибок**; **11 тестов bridge, 0 ошибок,
  0 пропусков**. Checker обнаруживает SCRIPT ERROR даже при exit code 0.
- Новая чистая модель: 42 проверки. Тишина, идеальный ритм, повторяемость,
  ранний/поздний вход, слабый/сильный акцент, разные личные базисы, гул,
  один пик, длинный кадр, отсутствие зачёта host, однократная финализация.
- Сцена/контроллер: 33 проверки. Реальный VoiceDetector с виртуальным RMS
  проходит все три уровня (средние оценки примерно 95). Проверены скрытый HUD,
  инструкция, стрелки, предупреждение, ошибка/пауза/Retry, Next без новой сессии,
  финал всех уровней, повтор, неуспех, Reset посреди реплики, честный native error.
  Optional host WAV воспроизводится, останавливается на player/паузе и возобновляется.
- Chromium, обычный exported launcher и настоящий синтетический MediaStream:
  **все три 60-секундных уровня пройдены последовательно**. Ввод проходит
  неизменённый Web Audio bridge и VoiceDetector; проверены denied/Retry,
  единственный микрофон на Next, общий финал, Reset и позднее разрешение.
  Нет соединения микрофона с колонками, запросов записи/POST и ошибок JS/GDScript.
- Восемь управляемых состояний реальной сцены: инструкция, ведущий, игрок,
  уровни 2/3, успех, неудача, общий финал. После настройки шрифта и редакторской
  правки фраз повторно проверены инструкция/игрок/уровень 3/финал. 16:9 и 4:3.
- Регрессия Goal в Chromium: полный раунд, результат/Next либо Retry,
  движение/остановка/полёт, RMS, ошибки микрофона, Reset, 4:3. Пройдена.
- Регрессия Stands в Chromium: три настоящих 30-секундных раунда, переходы,
  фактическая петля звука соперника, тишина на player/result, Retry/Reset.
  Пройдена с первой попытки на каждом уровне.
- После уточнения optional media повторно выполнена сценовая suite (33/33).
  Пустые пути и отсутствующий файл не ломают демо.

Логи находятся в `/workspace/artifacts/matryoshka-commentator/`:
`godot-checks.log`, `commentator-browser-log.json`, `commentator-visual-log.json`,
`final-review/commentator-visual-log.json`, `goal/browser-log.json`,
`stands/stands-browser-log.json` и отдельный лог media-check.
Локальные fixtures выбираются только явным `--script` через тестовую HTML-подмену;
обычная страница Pages не включает их и не имеет новых debug-кнопок.

Снимки настоящего браузера:
[инструкция](docs/review/commentator/intro.png),
[караоке](docs/review/commentator/player.png),
[уровень 3, 4:3](docs/review/commentator/level-3-4x3.png),
[общий финал](docs/review/commentator/final.png).

## Ограничения демонстрации

Архивное видео, исторический голос и портреты не предоставлены. Сюжет
вымышленный, ведущий отвечает текстом, фон/матч — авторские примитивы.
Локальные пути для замены готовы, но совместимость реального архивного
видео, seek/кодек и autoplay с конкретным файлом пока не проверены.
Физический микрофон не проверялся: ритм и удобство громкости нужно оценить
своим голосом после публикации. Распознавания правильности слов игра не обещает.

Публикация идёт прежним workflow. Его deploy проверяет точный SHA `version.json`
и доступность HTML/JS/WASM/PCK на Pages. Статус публикации подтверждается после
завершения Actions; отчёт не подменяет проверку живой версии.
