"""Minimal, dependency-free reader for the first sheet of an .xlsx file."""
import re
import zipfile
import xml.etree.ElementTree as ET

NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}


def _col(ref):
    letters = re.match(r'[A-Z]+', ref).group(0)
    n = 0
    for ch in letters:
        n = n * 26 + ord(ch) - 64
    return n - 1


def read_rows(path, sheet='xl/worksheets/sheet1.xml'):
    """Yields each row as a list of strings (empty string for blanks)."""
    z = zipfile.ZipFile(path)
    shared = []
    if 'xl/sharedStrings.xml' in z.namelist():
        root = ET.fromstring(z.read('xl/sharedStrings.xml'))
        for si in root.findall('m:si', NS):
            shared.append(''.join(t.text or '' for t in si.iter('{%s}t' % NS['m'])))
    root = ET.fromstring(z.read(sheet))
    for row in root.iter('{%s}row' % NS['m']):
        cells = {}
        for c in row.findall('m:c', NS):
            v = c.find('m:v', NS)
            if c.get('t') == 'inlineStr':
                text = ''.join(t.text or '' for t in c.iter('{%s}t' % NS['m']))
            elif v is None:
                text = ''
            elif c.get('t') == 's':
                text = shared[int(v.text)]
            else:
                text = v.text or ''
            cells[_col(c.get('r'))] = text
        if cells:
            width = max(cells) + 1
            yield [cells.get(i, '') for i in range(width)]
