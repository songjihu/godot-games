"""Rebuild the OFL Chinese subset. Requires: pip install fonttools.
Usage: python tools/subset_font.py PATH_TO_NotoSerifSC.ttf
Upstream: https://github.com/google/fonts/tree/main/ofl/notoserifsc
"""
import sys
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
root=Path(__file__).resolve().parents[1]
text=(root/'main.gd').read_text(encoding='utf-8')+(root/'levels/campaign.json').read_text(encoding='utf-8')+(root/'levels/story.json').read_text(encoding='utf-8')+''.join(chr(i) for i in range(32,127))
font=TTFont(sys.argv[1])
options=subset.Options();options.name_IDs=['*'];options.name_legacy=True
worker=subset.Subsetter(options=options);worker.populate(text=text);worker.subset(font)
for record in font['name'].names:
    if record.nameID in (1,4,6,16):
        record.string=('ArrowEscapeSerif' if record.nameID==6 else 'Arrow Escape Serif').encode(record.getEncoding())
font.save(root/'fonts/ChineseSerif.ttf')
assert all(ord(c) in font.getBestCmap() for c in text if '\u4e00' <= c <= '\u9fff')
print('Chinese font subset written and glyphs verified.')
