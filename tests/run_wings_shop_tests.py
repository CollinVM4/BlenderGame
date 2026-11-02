"""Exercise the actual WingsShopAdapter resolver against source and prepared exports."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--luau', default='luau')
args = parser.parse_args()
paths = {
    'WingsShopAdapter': 'src/client/Controllers/WingsShopAdapter.luau',
    'UIRegistry': 'src/client/UI/UIRegistry.luau',
    'WingsConfig': 'src/shared/Constants/WingsConfig.luau',
}
for export in ('newestExport.rbxmx', 'Framewisp_Hotbar.prepared.rbxmx'):
    nodes = []
    def visit(item, parent):
        index = len(nodes) + 1
        nodes.append([index, parent, item.attrib['class'], item.findtext("Properties/string[@name='Name']")])
        for child in item.findall('Item'):
            visit(child, index)
    for item in ET.parse(ROOT / export).getroot().findall('Item'):
        visit(item, 0)
    bundle = 'local sources = {\n' + '\n'.join(
        f'[{json.dumps(name)}] = {json.dumps((ROOT / path).read_text(encoding="utf-8"))},'
        for name, path in paths.items()) + '\n}\n'
    bundle += (ROOT / 'tests/fixtures/roblox.luau').read_text(encoding='utf-8')
    bundle += '\nlocal exportNodes = {\n' + '\n'.join(
        '{' + ','.join(json.dumps(value) for value in node) + '},' for node in nodes) + '\n}\n'
    bundle += (ROOT / 'tests/wings_shop.spec.luau').read_text(encoding='utf-8')
    with tempfile.TemporaryDirectory(prefix='wings-shop-') as directory:
        target = Path(directory) / 'shop.luau'
        target.write_text(bundle, encoding='utf-8')
        print(export, flush=True)
        subprocess.run([args.luau, str(target)], cwd=ROOT, check=True)
