#!/usr/bin/env python3
"""Checks the MVP handoff package is internally consistent before Codex opens it."""
from pathlib import Path
import json, re, sys

R = Path(__file__).resolve().parents[1]
errors=[]
required=[
    'AGENTS.md','CODEX_FIRST_PROMPT.txt','CODEX_TASKS_v1.0.md','GDD_Matryoshka_v1.0.md',
    'README_START_HERE.md','SCREEN_SCRIPT_UI_v1.0.md','TECH_ARCHITECTURE_v1.0.md',
    'references/goal_scene_original.png','tools/sync_ui_docs.py',
    'data/config/ui.ru.json','data/config/gameplay.json',
    'data/config/ui_layout.json','data/config/ui_animations.json',
    'data/config/asset_manifest.json',
    'project.godot','export_presets.cfg','GITHUB_SETUP.md',
    '.github/workflows/web-pages.yml','scenes/Bootstrap.tscn',
    'scripts/bootstrap.gd','tests/config_smoke_test.gd',
    'tools/setup_codex_env.sh'
]
for name in required:
    if not (R/name).is_file():errors.append(f'Missing {name}')
if errors:
    print('\n'.join(errors),file=sys.stderr);sys.exit(1)

def load(name):return json.loads((R/'data/config'/name).read_text(encoding='utf8'))
ui=load('ui.ru.json')
anim=load('ui_animations.json')
layout=load('ui_layout.json')
game=load('gameplay.json')
assets=load('asset_manifest.json')
stands=load('stands_gameplay.json')
teams=load('stands_teams.json')
load('stands_assets.json')
load('stands_layout.json')
if len(teams['teams']) != 4 or len({t['id'] for t in teams['teams']}) != 4:
    errors.append('Stands requires four distinct fictional teams')
levels=stands['levels']
if stands['round_duration_seconds'] != 30 or any(not levels[f'level_{i}']['enabled'] or levels[f'level_{i}']['duration_seconds'] != 30 for i in range(1,4)):
    errors.append('All three Stands levels must be enabled and last thirty seconds')
if [levels[f'level_{i}']['target_peaks'] for i in range(1,4)] != [2,3,4]:
    errors.append('Stands peak targets must increase from two to four')
if levels['level_1']['turn_mode'] != 'fixed' or levels['level_1']['turn_seconds'] != 5 or stands['timing']['turn_count'] != 6:
    errors.append('Stands level one requires six fixed five-second turns')
if any(levels[f'level_{i}']['turn_mode'] != 'random' or levels[f'level_{i}']['turn_seconds_min'] != 3 or levels[f'level_{i}']['turn_seconds_max'] != 6 for i in [2,3]):
    errors.append('Higher Stands levels require three-to-six-second turns')
if not sum([stands['score']['loudness_weight'],stands['score']['distinct_peak_weight']]) == 1:
    errors.append('Stands score weights must sum to one')
if not 0 <= stands['score']['loudness_weight'] < stands['score']['distinct_peak_weight'] <= 1:
    errors.append('Stands support must be driven primarily by distinct peaks')
if not 0 <= game['microphone']['impulseReleaseThresholdNormalized'] < stands['input']['peak_threshold_normalized'] <= 1:
    errors.append('Stands peak threshold must exceed release and stay within normalized volume')
if not (levels['level_1']['opponent_loss_per_full_turn'] < levels['level_2']['opponent_loss_per_full_turn'] < levels['level_3']['opponent_loss_per_full_turn']):
    errors.append('Stands opponent must become stronger each level')
if not (R/stands['audio']['path'].removeprefix('res://')).is_file() or stands['timing']['speaker_fade_ms'] > 120:
    errors.append('Stands needs its original local crowd WAV and a short audio transition')

cards=ui['menu']['cards']
if [x['id'] for x in cards]!=['goal','stands','commentator']:
    errors.append('Menu must list goal, stands, commentator in that order')
if [x['enabled'] for x in cards]!=[True,True,True]:
    errors.append('All three mini-games must be enabled')
if 'title' in ui['menu']:errors.append('Do not add a global menu title')
if len(ui['goal']['intro']['instructions'])!=3:errors.append('Intro must have 3 infographic items')
for item in ui['goal']['intro']['instructions']:
    if item['visual']['mode'] not in ['icon','codeAnimation']:errors.append(f'Invalid visual mode: {item["id"]}')
if game['round']['goalTarget']!=3 or game['round']['maxAttempts']!=6 or game['round']['number']!=1:
    errors.append('Expected 3 goals / 6 attempts / round 1')
if game['defender']['maxSimultaneous']!=1:errors.append('Round one must have one defender')
depth_half_width = game['ball'].get('collisionHalfDepthProgress', 0) + game['defender'].get('collisionHalfDepthProgress', 0)
if not (0 < game['ball'].get('collisionHalfDepthProgress', 0) < 0.05 and 0 < game['defender'].get('collisionHalfDepthProgress', 0) < 0.05):
    errors.append('Ball and defender need small positive collision depths, in progress units')
rounds=game.get('rounds', [])
if [r.get('number') for r in rounds] != [1,2,3]:errors.append('Expected three ordered rounds')
if [r['defender']['maxSimultaneous'] for r in rounds] != [1,2,3]:errors.append('Expected one/two/three defenders')
if len(rounds)==3:
    speeds=[r['defender']['crossScreenSeconds'] for r in rounds]
    if not (speeds[0]>speeds[1]>speeds[2] and speeds[2]==2.6):errors.append('Defender speeds must increase to the former 2.6-second crossing in round three')
    keeper_times=[r['goalkeeper']['crossScreenSeconds'] for r in rounds]
    if not keeper_times[0]>keeper_times[1]>keeper_times[2]>2.9:errors.append('Keeper speeds must increase moderately')
    min_lane=layout['refComposition']['goal']['y']+game['defender']['minDepthAheadOfGoal']
    for r in rounds:
        lanes=r['defender']['lanes']
        if len(lanes)<r['defender']['maxSimultaneous'] or any(y<min_lane for y in lanes):errors.append('Defenders need distinct lanes strictly in front of the goal')
        if any(abs(a-b)<game['defender']['minimumLaneSeparation'] for i,a in enumerate(lanes) for b in lanes[i+1:]):errors.append('Defender lanes overlap')
        start_y=layout['refComposition']['ballAtStart']['y']*layout['baseResolution']['height']
        start_y+=layout['baseResolution']['width']*layout['refComposition']['ballAtStart']['diameterFractionOfWidth']/2*game['ball']['shadowContactRadiusFraction']
        goal_y=layout['refComposition']['goal']['y']*layout['baseResolution']['height']
        depths=[(start_y-y*layout['baseResolution']['height'])/(start_y-goal_y) for y in lanes]
        if any(abs(a-b)<=2*depth_half_width for i,a in enumerate(depths) for b in depths[i+1:]):errors.append('Defender collision depth bands must remain distinct')
        pattern=r['goalkeeper']['pattern']
        if r['number']>1 and (not pattern or pattern[-1]['to']!=0.5 or any(not 0<=leg['to']<=1 or leg['holdMs']<0 for leg in pattern)):errors.append('Keeper patterns must be bounded and loop back to center')
if not (game['round']['autoIdleReset']==False and game['options']['soundsEnabled']==False and game['options']['micPlaybackEnabled']==False):
    errors.append('No auto idle reset and no audio playback')
if game['options']['introBeforeEveryRound'] != False:errors.append('Instructions only before minigame')
if set(ui['goal']['results']['tiers']) != set('0123'):errors.append('Results tiers must be 0,1,2,3')
for k,v in ui['goal']['results']['tiers'].items():
    if len(v.get('phrases',[]))!=3:errors.append(f'Need 3 result phrases for tier {k}')
    if v['state']!= ('win' if k=='3' else 'loss'):errors.append(f'Wrong outcome tier {k}')
tips=ui['goal']['tips']
if len(tips)<8 or len(set(t['id'] for t in tips)) != len(tips):errors.append('Tips missing or IDs duplicated')
required_profiles=[
'menu.card.enabled','menu.card.disabled','intro.panel','intro.instructionItem',
'intro.visual.icon','intro.visual.codeAnimation','goalEvent.panel','goalEvent.title',
'goalEvent.tip','failEvent.callout','final.panel','final.headline','final.stats',
'final.actions','microphoneError.panel','hud.goals','hud.attempts','hud.voiceMeter',
'global.reset','world.goalNet','world.goalCelebrationUI'
]
for profile in required_profiles:
    if profile not in anim['profiles']:errors.append(f'Missing animation profile: {profile}')
if len(layout['eventPlacement']['fail']['candidates']) < 3:errors.append('Not enough safe notification anchors')
if not assets['reference']['goalScene'] == 'references/goal_scene_original.png':errors.append('Wrong visual reference')
allowed_vars={'goals','goalTarget','attemptsUsed','maxAttempts','round','seconds','peaks','targetPeaks','score','playerTeam','opponentTeam','turn','turnCount','levelCount','hitPercent','avgScore','interest'}
# Validate all text templates, avoid assuming keys with placeholders are renamable.
def walk(x, path='ui'):
    if isinstance(x,dict):
        for key,val in x.items():walk(val,path+'.'+str(key))
    elif isinstance(x,list):
        for i,val in enumerate(x):walk(val,path+'.'+str(i))
    elif isinstance(x,str) and not path.endswith('._editingNote'):
        for v in re.findall(r'\{([^{}]*)\}',x):
            if v not in allowed_vars:errors.append(f'Unknown template variable {{{v}}} at {path}')
walk(ui)
commentator=load('commentator_gameplay.json')
commentary=load('commentator_levels.json')
load('commentator_layout.json')
if len(commentary['levels'])!=3 or not commentary['demonstration']:
    errors.append('Commentator requires three honest demonstration scenarios')
for level in commentary['levels']:
    end=0
    player_turns=0
    word_end=0
    profile=commentator['levels'][level['id']]
    if not profile['enabled'] or not 55<=level['duration_sec']<=65:
        errors.append('Commentator levels must be playable and about one minute long')
    for index,turn in enumerate(level['turns']):
        if turn['speaker']!=('host' if index%2==0 else 'player') or turn['start_sec']!=end or turn['end_sec']<=turn['start_sec']:
            errors.append('Commentator turns must alternate and cover the full timeline')
        end=turn['end_sec']
        if turn['speaker']=='player':
            player_turns+=1
            for word in turn['words']:
                if not turn['start_sec']<=word['start_sec']<word['end_sec']<=end or word['start_sec']<word_end:
                    errors.append('Commentator word times overlap or exceed the player turn')
                word_end=word['end_sec']
            if not turn['words'] or not any(w['emphasis'] for w in turn['words']):
                errors.append('Commentator player phrases need words and emphasis')
    if end!=level['duration_sec'] or player_turns<5:
        errors.append('Commentator needs at least five complete host/player pairs')
if sum(commentator['scoring'][k] for k in ['timing_weight','activity_weight','volume_weight'])!=1:
    errors.append('Commentator word weights must sum to one')

script=(R/'SCREEN_SCRIPT_UI_v1.0.md').read_text(encoding='utf8')
if script.count('<!-- UI_CATALOG_BEGIN -->')!=1 or script.count('<!-- UI_CATALOG_END -->')!=1:
    errors.append('UI script catalog markers invalid')
if len(re.findall(r'^\| `',script,flags=re.M)) < 65:
    errors.append('UI script catalog is incomplete; run sync_ui_docs.py')

# Check the Godot/Web handoff rather than the old Phaser/Vite runtime.
preset=(R/'export_presets.cfg').read_text(encoding='utf8')
if 'name="Web"' not in preset or 'variant/thread_support=false' not in preset:
    errors.append('Godot Web must be a non-threaded Web preset')
if 'data/config/*.json' not in preset or 'web/*.js' not in preset:
    errors.append('Web export must include non-resource JSON and microphone JS files')
workflow=(R/'.github/workflows/web-pages.yml').read_text(encoding='utf8')
if 'barichello/godot-ci:4.5.2' not in workflow or 'actions/deploy-pages@v4' not in workflow:
    errors.append('Missing pinned Godot CI + GitHub Pages actions')
if errors:
    print('FAIL:\n'+'\n'.join(' - '+x for x in errors),file=sys.stderr)
    sys.exit(1)
print(f'OK: Godot handoff, 12 JSON configs, all 3 mini-games enabled, 3 Stands levels / 4 teams, {len(anim["profiles"])} animation profiles, Godot Web preset + Pages workflow')
