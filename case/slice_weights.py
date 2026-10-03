#!/usr/bin/env python3
"""Slice every part in stl/ with OrcaSlicer's command line and record the real filament use and print
time in weights.json, which make_print_pack.py reads. A volume estimate runs about a quarter high on
these 3 mm plates, enough to turn one spool into two.

The profile is the machine the case is printed on: Bambu Lab X1 Carbon 0.4, Bambu PETG Basic, 0.20 mm,
textured PEI plate. Change WALLS and INFILL here, re-run, then rebuild the print pack.
usage: slice_weights.py            (ORCA=/path/to/orca-slicer to use another install)"""
import glob, json, os, re, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ORCA = os.environ.get('ORCA', '/opt/orca-slicer/AppRun')
PROFILES = os.path.join(os.path.dirname(os.path.realpath(ORCA)), 'resources', 'profiles', 'BBL')
MACHINE, PROCESS, FILAMENT = 'Bambu Lab X1 Carbon 0.4 nozzle', '0.20mm Standard @BBL X1C', 'Bambu PETG Basic @BBL X1C'
WALLS, INFILL = 3, '15%'
PLATE = 'Textured PEI Plate'          # Bambu's PETG profile refuses the smooth Cool Plate, and so does the slicer

def flat(kind, name):
    """A system profile with its whole "inherits" chain merged in: the command line does not resolve it,
    and silently falls back to a 200 mm bed and generic filament values."""
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

tmp = tempfile.mkdtemp()
machine, process, filament = flat('machine', MACHINE), flat('process', PROCESS), flat('filament', FILAMENT)
process.update(wall_loops=str(WALLS), sparse_infill_density=INFILL, curr_bed_type=PLATE)
paths = {}
for kind, cfg in (('machine', machine), ('process', process), ('filament', filament)):
    paths[kind] = os.path.join(tmp, kind + '.json')
    json.dump(cfg, open(paths[kind], 'w'))
density = float(filament['filament_density'][0])

parts, failed = {}, []
for stl in sorted(glob.glob(os.path.join(HERE, 'stl', '*.stl'))):
    name = os.path.basename(stl)[:-4]
    if name.startswith('_'):                            # whole-assembly meshes for viewers
        continue
    out = os.path.join(tmp, name)
    os.makedirs(out)
    run = subprocess.run([ORCA, '--debug', '1', '--load-settings', f"{paths['machine']};{paths['process']}", '--load-filaments', paths['filament'],
                          '--arrange', '1', '--slice', '0', '--outputdir', out, '--export-3mf', 'x.gcode.3mf', stl], capture_output=True, text=True, cwd=tmp)
    gcode = os.path.join(out, 'plate_1.gcode')
    if run.returncode != 0 or not os.path.exists(gcode):
        result = os.path.join(out, 'result.json')
        failed.append((name, json.load(open(result)).get('error_string', '') if os.path.exists(result) else f'exit {run.returncode}'))
        continue
    text = open(gcode).read()
    cm3 = float(re.search(r'; filament used \[cm3\] = ([\d.]+)', text).group(1))
    parts[name] = {'g': round(cm3 * density, 1), 'min': minutes(re.search(r'total estimated time: ([^\n]+)', text).group(1))}
    print(f"{name:16} {parts[name]['g']:6.1f} g  {parts[name]['min']:4d} min", flush=True)
if failed:
    shutil.rmtree(tmp)
    sys.exit('not sliced, so weights.json is left alone:\n' + '\n'.join(f'  {n}: {why}' for n, why in failed))

version = re.search(r'OrcaSlicer-([\d.]+)', subprocess.run([ORCA, '--help'], capture_output=True, text=True, cwd=tmp).stdout)
shutil.rmtree(tmp)
json.dump({'slicer': 'OrcaSlicer ' + (version.group(1) if version else '?'), 'printer': MACHINE, 'filament': FILAMENT, 'process': PROCESS,
           'walls': WALLS, 'infill': INFILL, 'plate': PLATE, 'parts': parts},
          open(os.path.join(HERE, 'weights.json'), 'w'), indent=1)
print(f"weights.json: {len(parts)} parts, each sliced on its own")
