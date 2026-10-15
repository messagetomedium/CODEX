#!/usr/bin/env python3
"""Regenerate catalog of UI text from data/config/ui.ru.json, preserving editorial scenario prose."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
js = json.loads((ROOT/'data/config/ui.ru.json').read_text(encoding='utf8'))
md_path = ROOT/'SCREEN_SCRIPT_UI_v1.0.md'
original = md_path.read_text(encoding='utf8')
start='<!-- UI_CATALOG_BEGIN -->'
end='<!-- UI_CATALOG_END -->'
if original.count(start)!=1 or original.count(end)!=1:
    raise SystemExit('Missing/duplicate catalog delimiters')
rows = []
def row(key, value, context):
    txt = str(value).replace('|',r'\|').replace('\n',' ')
    rows.append(f'| `{key}` | {txt} | {context} |')

menu=js['menu']
for card in menu['cards']:
    row(f'menu.cards.{card["id"]}.title',card['title'],'Карточка, название под иллюстрацией')
    row(f'menu.cards.{card["id"]}.description',card['description'],'Карточка, мелкое описание под названием')
row('menu.disabledLabel',menu['disabledLabel'],'Неактивная карточка')
row('common.reset',js['common']['reset'],'Глобальная кнопка')
for k,v in js['common']['actions'].items(): row(f'common.actions.{k}',v,'Кнопка/действие')
for k,v in js['common']['microphone'].items():row(f'common.microphone.{k}',v,'Подключение/ошибка микрофона')
g=js['goal']
row('goal.intro.title',g['intro']['title'],'Инструкция мини-игры')
row('goal.intro.objective',g['intro']['objective'],'Цель перед стартом')
for item in g['intro']['instructions']:
    row(f'goal.intro.instructions.{item["id"]}.title',item['title'],'Инфографика, подпись')
    row(f'goal.intro.instructions.{item["id"]}.text',item['text'],'Инфографика, пояснение')
for k,v in g['hud'].items():row(f'goal.hud.{k}',v,'Постоянный HUD')
for event,d in g['event'].items():
    for k,v in d.items():row(f'goal.event.{event}.{k}',v,'Короткое игровое событие')
for tip in g['tips']:row(f'goal.tips.{tip["id"]}',tip['text'],'Случайная подсказка после гола')
for k,v in g['results'].items():
    if isinstance(v,str):row(f'goal.results.{k}',v,'Итог раунда / завершение игры')
for tier,d in g['results']['tiers'].items():
    for i,phrase in enumerate(d['phrases'],1):row(f'goal.results.tiers.{tier}.{i:02d}',phrase,f'Финал: {tier} гол(а/ов), {d["state"]}')
for k,v in g['intermediateResult'].items():row(f'goal.intermediateResult.{k}',v,'Зарезервировано на будущие раунды')

def stands_rows(value, path='stands'):
    if isinstance(value, dict):
        for key, child in value.items():
            if key not in ('visual','id'): stands_rows(child, path+'.'+key)
    elif isinstance(value, list):
        for index, child in enumerate(value): stands_rows(child, path+'.'+str(index))
    elif isinstance(value, str):
        row(path,value,'Трибуны: инструкция / команды / HUD / результаты')
if 'stands' in js: stands_rows(js['stands'])

catalog = '\n'.join([
    '> **Важно:** этот каталог создан из `data/config/ui.ru.json`. Для редактирования реплик изменяйте JSON, затем запускайте `python tools/sync_ui_docs.py`.',
    '',
    '| Ключ (ID) | Текущий текст | Где используется |',
    '|---|---|---|',
    *rows,
])
new = original.split(start)[0]+start+'\n'+catalog+'\n'+end+original.split(end)[1]
md_path.write_text(new, encoding='utf8')
print(f'Synced {len(rows)} entries to {md_path}')
