#!/usr/bin/env python3
from pathlib import Path
import plistlib,sys,subprocess,tempfile,xml.etree.ElementTree as ET
package=Path(sys.argv[1]).resolve()
assert package.is_file() and package.stat().st_size > 1_000_000
with tempfile.TemporaryDirectory() as tmp:
    expanded=Path(tmp)/'product'
    subprocess.run(['pkgutil','--expand',str(package),str(expanded)],check=True)
    root=ET.parse(expanded/'Distribution').getroot()
    refs={p.attrib.get('id') for p in root.findall('pkg-ref')}
    assert 'io.github.leooochen.kindledock.app' in refs
    assert 'io.macfuse.installer.components.core' in refs
    script=''.join(root.find('script').itertext())
    assert 'needsMacFUSE' in script and '5.5.0' in script
    assert (expanded/'KindleDock-App.pkg').exists()
    assert (expanded/'macFUSE-Core.pkg').exists()
with open(sys.argv[2],'rb') as f: choices=plistlib.load(f)
def flatten(items):
    for item in items:
        yield item
        yield from flatten(item.get('childItems', []))
choices=list(flatten(choices))
app=[c for c in choices if c.get('choiceIdentifier')=='kindledock']
assert app and app[0].get('choiceIsSelected') in [True,1]
print('PASS: installer product components, app selection, dependency policy')
