"""Rebuild every derived character image:   python tools/character_art/build_all.py
Needs: Pillow, numpy, scipy, opencv-python-headless. Reads assets/references/original_pvz, writes assets/characters."""
import os
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
for script in ['zombie_parts.py', 'garg_parts.py', 'plant_parts.py', 'imp_parts.py', 'mower_parts.py', 'imp_icons.py']:
    print('==', script)
    subprocess.check_call([sys.executable, os.path.join(here, script)], cwd=here)
