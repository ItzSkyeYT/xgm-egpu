#!/usr/bin/env python3
"""Slice every part of one version with OrcaSlicer, on a real printer's profile, and record what each one weighs and how long it
prints. A part that does not fit the printer's usable bed (which is smaller than the nominal one) fails here, so this is also the
proof that a version fits its bed.

  350 -> Bambu Lab H2D (the fablab's printer), inside the strip both of its nozzles reach
  256 -> Bambu Lab P1S, the usual 256 x 256 mm printer, with the corner it keeps for itself

Writes build/<bed>/sliced.json.     usage: tools/slice.py 350|256        (ORCA=/path/to/orca-slicer to use another install)"""
import sys
sys.dont_write_bytecode = True
import glob, json, os, re, subprocess, tempfile
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
V2 = os.path.dirname(HERE)
bed = sys.argv[1] if len(sys.argv) > 1 else '350'
STL = os.path.join(V2, 'build', bed, 'stl')
ORCA = os.environ.get('ORCA', '/opt/orca-slicer/AppRun')
PROFILES = os.path.join(os.path.dirname(os.path.realpath(ORCA)), 'resources', 'profiles', 'BBL')
MACHINE, PROCESS, FILAMENT = {
    '350': ('Bambu Lab H2D 0.4 nozzle', '0.20mm Standard @BBL H2D', 'Bambu PETG Basic @BBL H2D 0.4 nozzle'),
    '256': ('Bambu Lab P1S 0.4 nozzle', '0.20mm Standard @BBL X1C', 'Bambu PETG Basic @BBL X1C'),
}[bed]
PLATE = 'Textured PEI Plate'
# On top of the stock profile. One wall and 5 points of infill more than v1: this version is about stiffness.
SETTINGS = {'wall_loops': '4', 'sparse_infill_density': '20%', 'reduce_crossing_wall': '1', 'brim_type': 'no_brim'}
POSTS = {'brim_type': 'outer_only', 'brim_width': '5'}       # 18 mm square, 178 mm tall: a brim keeps them standing
QTY = {'post_corner': 4, 'post_mid': 2, 'foot_corner': 4, 'foot_mid': 2, 'bracket_washer': 2}

def flat(kind, name):
    """A system profile with its whole "inherits" chain merged in: the command line does not resolve the chain itself."""
    chain = []
    while name:
        chain.append(json.load(open(os.path.join(PROFILES, kind, name + '.json'))))
        name = chain[-1].get('inherits')
    out = {}
    for layer in reversed(chain):
        out.update(layer)
    out.pop('inherits', None)
    out['name'] = chain[0]['name']
    return out

def minutes(text):
    return round(sum(int(v) * {'d': 1440, 'h': 60, 'm': 1, 's': 1 / 60}[u] for v, u in re.findall(r'(\d+)([dhms])', text)))

tmp = tempfile.mkdtemp()
machine, stock, filament = flat('machine', MACHINE), flat('process', PROCESS), flat('filament', FILAMENT)
density = float(filament['filament_density'][0])
json.dump(machine, open(os.path.join(tmp, 'machine.json'), 'w'))
json.dump(filament, open(os.path.join(tmp, 'filament.json'), 'w'))
def process_file(tag, overrides):
    path = os.path.join(tmp, f'process-{tag}.json')
    json.dump(dict(stock, curr_bed_type=PLATE, **overrides), open(path, 'w'))
    return path
plain, posts = process_file('plain', SETTINGS), process_file('posts', dict(SETTINGS, **POSTS))

def one(stl):
    name = os.path.basename(stl)[:-4]
    out = os.path.join(tmp, 'part-' + name)
    os.makedirs(out)
    process = posts if name.startswith('post_') else plain
    args = [ORCA, '--debug', '1', '--load-settings', f"{os.path.join(tmp, 'machine.json')};{process}", '--load-filaments', os.path.join(tmp, 'filament.json'),
            '--arrange', '1', '--slice', '0', '--outputdir', out, '--export-3mf', 'x.gcode.3mf', stl]
    run = subprocess.run(args, capture_output=True, text=True, cwd=out)
    result = os.path.join(out, 'result.json')
    error = json.load(open(result)).get('error_string', '') if os.path.exists(result) else ''
    gcodes = sorted(glob.glob(os.path.join(out, 'plate_*.gcode')))
    if run.returncode != 0 or len(gcodes) != 1:
        return name, None, error or f'exit {run.returncode}, {len(gcodes)} plates'
    text = open(gcodes[0]).read()
    cm3 = float(re.search(r'; filament used \[cm3\] = ([\d.]+)', text).group(1))
    return name, {'g': round(cm3 * density, 1), 'min': minutes(re.search(r'total estimated time: ([^\n]+)', text).group(1))}, ''

parts, failed = {}, []
with ThreadPoolExecutor(4) as pool:
    for name, got, error in pool.map(one, sorted(glob.glob(os.path.join(STL, '*.stl')))):
        if got: parts[name] = dict(got, qty=QTY.get(name, 1))
        else: failed.append((name, error))
for name, p in parts.items():
    print(f"  {name:16} x{p['qty']}  {p['g']:7.1f} g  {p['min'] // 60:2d} h {p['min'] % 60:02d}")
for name, error in failed:
    print(f'  {name}: DOES NOT SLICE on {MACHINE}: {error}')
case = {n: p for n, p in parts.items() if n != 'coupon'}
total_g = sum(p['g'] * p['qty'] for p in case.values());  total_min = sum(p['min'] * p['qty'] for p in case.values())
print(f'  the case: {total_g:.0f} g of PETG, {total_min // 60} h {total_min % 60:02d} of printing, each part on its own plate ({MACHINE}, 4 walls, 20 % infill)')
json.dump({'printer': MACHINE, 'filament': FILAMENT, 'process': PROCESS, 'walls': 4, 'infill': '20%', 'plate': PLATE, 'parts': parts,
           'total_g': round(total_g), 'total_min': total_min, 'failed': [n for n, _ in failed]}, open(os.path.join(V2, 'build', bed, 'sliced.json'), 'w'), indent=1)
sys.exit(1 if failed else 0)
