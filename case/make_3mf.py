#!/usr/bin/env python3
"""Pack the in-place part STLs into one 3MF with a named, coloured object per part.
usage: make_3mf.py <dir with <part>.stl> <out.3mf>"""
import sys, os, glob, zipfile
from xml.sax.saxutils import escape

COLOURS = {   # name prefix -> RGBA
    "floor": "4A6FA5FF", "lid": "7FA3D1FF", "post": "2F4F7FFF", "panel": "9DBBE0FF",
    "cradle": "2E4A7AFF", "bracket_holder": "2E4A7AFF",
    "board": "2E8B57FF", "card": "8A8A8AFF", "psu": "303030FF", "zones": "FFA50080",
    "screws": "D8402CFF", "inserts": "D9A520FF",
}
def colour(name):
    for k, v in COLOURS.items():
        if name.startswith(k): return k, v
    return "other", "888888FF"

def read_stl(path):
    verts, index, tris, cur = [], {}, [], []
    with open(path) as f:
        for line in f:
            t = line.split()
            if t and t[0] == "vertex":
                v = (float(t[1]), float(t[2]), float(t[3]))
                i = index.get(v)
                if i is None:
                    i = len(verts); index[v] = i; verts.append(v)
                cur.append(i)
                if len(cur) == 3:
                    tris.append(tuple(cur)); cur = []
    return verts, tris

src, out = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(src, "*.stl")))
mats = list(COLOURS.items()) + [("other", "888888FF")]
mat_index = {k: i for i, (k, _) in enumerate(mats)}
xml = ['<?xml version="1.0" encoding="UTF-8"?>',
       '<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">',
       ' <resources>', '  <basematerials id="1">']
xml += [f'   <base name="{k}" displaycolor="#{v}"/>' for k, v in mats]
xml.append('  </basematerials>')
items = []
oid = 2
for f in files:
    name = os.path.basename(f)[:-4]
    verts, tris = read_stl(f)
    if not tris: print("skip empty", name); continue
    k, _ = colour(name)
    xml.append(f'  <object id="{oid}" name="{escape(name)}" type="model" pid="1" pindex="{mat_index[k]}">')
    xml.append('   <mesh>')
    xml.append('    <vertices>')
    xml += [f'     <vertex x="{x:.4f}" y="{y:.4f}" z="{z:.4f}"/>' for x, y, z in verts]
    xml.append('    </vertices>')
    xml.append('    <triangles>')
    xml += [f'     <triangle v1="{a}" v2="{b}" v3="{c}"/>' for a, b, c in tris]
    xml.append('    </triangles>')
    xml.append('   </mesh>')
    xml.append('  </object>')
    items.append(f'  <item objectid="{oid}"/>')
    print(f"{name}: {len(verts)} vertices, {len(tris)} triangles")
    oid += 1
xml += [' </resources>', ' <build>'] + items + [' </build>', '</model>']
def put(z, name, data):           # fixed timestamp: an unchanged model rebuilds byte for byte, so git only sees real changes
    zi = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0)); zi.external_attr = 0o644 << 16
    z.writestr(zi, data, zipfile.ZIP_DEFLATED)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    put(z, "[Content_Types].xml", '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\n'
        ' <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\n'
        ' <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>\n</Types>\n')
    put(z, "_rels/.rels", '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\n'
        ' <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>\n</Relationships>\n')
    put(z, "3D/3dmodel.model", "\n".join(xml) + "\n")
print(f"wrote {out}: {len(items)} objects, {os.path.getsize(out)//1024} KB")
