#!/usr/bin/env python3
"""Build the batch plates. For every batch in stages.py this writes build/plates/<stage>/<batch>.3mf: an
OrcaSlicer project with the batch's parts arranged on the bed and the print settings saved in it, ready for
File > Open Project, Slice, Print. Each project is then sliced to check that it fits one plate and that the
settings took, and its real print time and filament go into build/weights.json for make_print_pack.py.

The profile is the machine the case is printed on: Bambu Lab X1 Carbon 0.4, Bambu PETG Basic, 0.20 mm,
textured PEI plate. Takes a minute or two; run it after render.sh whenever the model changes.
usage: make_plates.py [--batches-only]     (ORCA=/path/to/orca-slicer to use another install)"""
import sys
sys.dont_write_bytecode = True        # no __pycache__ beside the scripts
import glob, json, os, re, shutil, subprocess, tempfile, zipfile
from paths import STL, PLATES, WEIGHTS
from stages import STAGES

ORCA = os.environ.get('ORCA', '/opt/orca-slicer/AppRun')
PROFILES = os.path.join(os.path.dirname(os.path.realpath(ORCA)), 'resources', 'profiles', 'BBL')
MACHINE, PROCESS, FILAMENT = 'Bambu Lab X1 Carbon 0.4 nozzle', '0.20mm Standard @BBL X1C', 'Bambu PETG Basic @BBL X1C'
PLATE = 'Textured PEI Plate'          # Bambu's PETG profile refuses the smooth Cool Plate, and so does the slicer

# On top of Bambu's stock profile, for every batch. The tests get exactly the same, so that their fits carry over.
SETTINGS = {
    'wall_loops': '3',                # one more than stock: stiffer edges on 3 mm plates, solid pegs and slots
    'sparse_infill_density': '15%',   # stock; with 3 walls the whole case comes to about 910 g, one spool
    'reduce_crossing_wall': '1',      # PETG strings: travel moves stay inside the part, not across the vents
    'brim_type': 'no_brim',           # jigsaw edges and wall edges must come off the plate clean
}
POSTS = {'brim_type': 'outer_only', 'brim_width': '5'}   # 15 mm square, 180 mm tall: a brim keeps them standing
FRONT_STRIP = 14                  # the X1 Carbon's start sequence prints its purge and flow-calibration lines at X 18 to 240, Y 1 to 12

def flat(kind, name):
    """A system profile with its whole "inherits" chain merged in. The command line does not resolve the chain,
    and silently falls back to a 200 mm bed, 100 mm of height and generic filament values."""
    chain = []
    while name:
        chain.append(json.load(open(os.path.join(PROFILES, kind, name + '.json'))))
        name = chain[-1].get('inherits')
    out = {}
    for layer in reversed(chain):                       # parents first, so children override
        out.update(layer)
    out.pop('inherits', None)
    out['name'] = chain[0]['name']
    return out

def minutes(text):
    return round(sum(int(v) * {'d': 1440, 'h': 60, 'm': 1, 's': 1 / 60}[u] for v, u in re.findall(r'(\d+)([dhms])', text)))

def orca(args, cwd):
    run = subprocess.run([ORCA, '--debug', '1'] + args, capture_output=True, text=True, cwd=cwd)
    result = os.path.join(cwd, 'result.json')
    error = json.load(open(result)).get('error_string', '') if os.path.exists(result) else ''
    return run.returncode, error

def sliced(out):
    """[(minutes, grams, gcode text)] for every plate the slicer wrote into out."""
    plates = []
    for gcode in sorted(glob.glob(os.path.join(out, 'plate_*.gcode'))):
        text = open(gcode).read()
        cm3 = float(re.search(r'; filament used \[cm3\] = ([\d.]+)', text).group(1))
        plates.append((minutes(re.search(r'total estimated time: ([^\n]+)', text).group(1)), round(cm3 * density, 1), text))
    return plates

def footprint(project):
    """(min x, min y, max x, max y) of everything on the plate, from the project's meshes and their transforms."""
    def apply(t, p):
        m = [float(v) for v in t.split()]
        return (p[0] * m[0] + p[1] * m[3] + p[2] * m[6] + m[9], p[0] * m[1] + p[1] * m[4] + p[2] * m[7] + m[10], p[0] * m[2] + p[1] * m[5] + p[2] * m[8] + m[11])
    with zipfile.ZipFile(project) as z:
        model = z.read('3D/3dmodel.model').decode()
        parts = {oid: re.findall(r'<component p:path="([^"]+)" objectid="\d+"[^>]*?transform="([^"]+)"', body)
                 for oid, body in re.findall(r'<object id="(\d+)"[^>]*>(.*?)</object>', model, re.S)}
        xs, ys = [], []
        for oid, placed in re.findall(r'<item objectid="(\d+)"[^>]*?transform="([^"]+)"', model):
            for path, inner in parts[oid]:
                for v in re.findall(r'<vertex x="([^"]+)" y="([^"]+)" z="([^"]+)"', z.read(path.lstrip('/')).decode()):
                    x, y, _ = apply(placed, apply(inner, tuple(float(c) for c in v)))
                    xs.append(x); ys.append(y)
    return min(xs), min(ys), max(xs), max(ys)

def turned(stl, folder):
    """A copy of an STL turned a quarter about Z. The command line's own --rotate option crashes."""
    turn = lambda m: f'{m.group(1)} {-float(m.group(3)):.6f} {float(m.group(2)):.6f} {m.group(4)}'
    text = re.sub(r'(vertex|facet normal)\s+(\S+)\s+(\S+)\s+(\S+)', turn, open(stl).read())
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, os.path.basename(stl))
    open(path, 'w').write(text)
    return path

def setting(text, key):
    found = re.search(rf'^; {key} = (.*)$', text, re.M)
    return found.group(1).strip().strip('"') if found else None

tmp = tempfile.mkdtemp()
machine, stock, filament = flat('machine', MACHINE), flat('process', PROCESS), flat('filament', FILAMENT)
density = float(filament['filament_density'][0])
json.dump(machine, open(os.path.join(tmp, 'machine.json'), 'w'))
json.dump(filament, open(os.path.join(tmp, 'filament.json'), 'w'))

def process_file(tag, overrides):
    cfg = dict(stock, curr_bed_type=PLATE, **overrides)
    path = os.path.join(tmp, f'process-{tag}.json')
    json.dump(cfg, open(path, 'w'))
    return path

def load_args(process):
    return ['--load-settings', f"{os.path.join(tmp, 'machine.json')};{process}", '--load-filaments', os.path.join(tmp, 'filament.json')]

failed, parts, batches = [], {}, {}
if '--batches-only' in sys.argv and os.path.exists(WEIGHTS):   # keep the per-part weights, redo only the plates
    parts = json.load(open(WEIGHTS))['parts']

# ---- every part on its own: what each piece weighs
plain = process_file('plain', SETTINGS)
for stl in [] if parts else sorted(glob.glob(os.path.join(STL, '*.stl'))):
    name = os.path.basename(stl)[:-4]
    if name.startswith('_'):                            # whole-assembly meshes for viewers
        continue
    out = os.path.join(tmp, 'part-' + name)
    os.makedirs(out)
    code, error = orca(load_args(plain) + ['--arrange', '1', '--slice', '0', '--outputdir', out, '--export-3mf', 'x.gcode.3mf', stl], out)
    result = sliced(out)
    if code != 0 or len(result) != 1:
        failed.append((name, error or f'exit {code}'))
        continue
    parts[name] = {'g': result[0][1], 'min': result[0][0]}
    print(f"{name:20} {result[0][1]:6.1f} g", flush=True)

# ---- every batch: arrange, save as a project with its settings, then slice that project as a check
shutil.rmtree(PLATES, ignore_errors=True)                 # no stale plate from an earlier plan
for stage, _, stage_batches in STAGES:
    os.makedirs(os.path.join(PLATES, stage), exist_ok=True)
    for batch, _, brim, rows in stage_batches:
        overrides = dict(SETTINGS, **(POSTS if brim else {}))
        out = os.path.join(tmp, 'batch-' + batch)
        os.makedirs(out)
        arrange = load_args(process_file(batch, overrides)) + ['--clone-objects', ','.join(str(c) for _, c in rows),
                   '--avoid-extrusion-cali-region', '--arrange', '1', '--outputdir', out, '--export-3mf', 'raw.3mf']
        stls = [os.path.join(STL, n + '.stl') for n, _ in rows]
        # the arranger may lay a long part front to back, across the front strip: if so, turn the parts a quarter and forbid it to turn them back
        for attempt in (['--allow-rotations'] + stls, [turned(stl, os.path.join(out, 'turned')) for stl in stls]):
            code, error = orca(arrange + attempt, out)
            box = footprint(os.path.join(out, 'raw.3mf')) if code == 0 else None
            if box and box[1] >= FRONT_STRIP:
                break
        if code != 0 or box[1] < FRONT_STRIP:
            failed.append((batch, (error or f'exit {code}') if code else f'it reaches y = {box[1]:.1f}, into the strip where the printer draws its start lines'))
            continue
        # The project names Bambu's stock presets. The slicer's window only applies the values listed as different from them.
        project = os.path.join(PLATES, stage, batch + '.3mf')
        different = ';'.join(sorted(k for k, v in overrides.items() if str(stock.get(k)) != v))
        with zipfile.ZipFile(os.path.join(out, 'raw.3mf')) as zin, zipfile.ZipFile(project, 'w', zipfile.ZIP_DEFLATED) as zout:
            for item in sorted(zin.infolist(), key=lambda i: i.filename):     # Orca's own order varies between runs
                data = zin.read(item.filename)
                if item.filename == 'Metadata/project_settings.config':
                    cfg = json.loads(data)
                    cfg['different_settings_to_system'] = [different] + [''] * (len(cfg['different_settings_to_system']) - 1)
                    data = json.dumps(cfg, indent=4).encode()
                elif item.filename == 'Metadata/model_settings.config':
                    data = data.replace(b'<metadata key="plater_name" value=""/>', f'<metadata key="plater_name" value="{batch}"/>'.encode())
                info = zipfile.ZipInfo(item.filename, (1980, 1, 1, 0, 0, 0))      # fixed date: an unchanged batch rebuilds byte for byte
                info.external_attr = 0o644 << 16
                zout.writestr(info, data, zipfile.ZIP_DEFLATED)
        check = os.path.join(tmp, 'check-' + batch)
        os.makedirs(check)
        code, error = orca(['--slice', '0', '--outputdir', check, '--export-3mf', 'x.gcode.3mf', project], check)
        result = sliced(check)
        if code != 0 or len(result) != 1:
            failed.append((batch, (error or f'exit {code}') if code else f'{len(result)} plates: it does not fit on one'))
            continue
        mins, grams, text = result[0]
        want = dict(overrides, curr_bed_type=PLATE, printer_model=machine['printer_model'], filament_settings_id=FILAMENT)
        wrong = {k: setting(text, k) for k, v in want.items() if setting(text, k) != v}
        if wrong:
            failed.append((batch, f'settings did not take: {wrong}'))
            continue
        batches[batch] = {'g': grams, 'min': mins}
        print(f"{batch:20} {grams:6.1f} g  {mins // 60} h {mins % 60:02d}   x {box[0]:5.1f}..{box[2]:5.1f}  y {box[1]:5.1f}..{box[3]:5.1f}   "
              f"{' + '.join(n if c == 1 else f'{c} x {n}' for n, c in rows)}", flush=True)

version = re.search(r'OrcaSlicer-([\d.]+)', subprocess.run([ORCA, '--help'], capture_output=True, text=True, cwd=tmp).stdout)
shutil.rmtree(tmp)
if failed:
    sys.exit('failed, so weights.json is left alone:\n' + '\n'.join(f'  {n}: {why}' for n, why in failed))
json.dump({'slicer': 'OrcaSlicer ' + (version.group(1) if version else '?'), 'printer': MACHINE, 'filament': FILAMENT, 'process': PROCESS,
           'walls': int(SETTINGS['wall_loops']), 'infill': SETTINGS['sparse_infill_density'], 'plate': PLATE, 'parts': parts, 'batches': batches},
          open(WEIGHTS, 'w'), indent=1)
total = sum(b['min'] for b in batches.values())
print(f"weights.json: {len(parts)} parts, {len(batches)} batches, {sum(b['g'] for b in batches.values()):.0f} g, {total // 60} h {total % 60:02d} of printing")
