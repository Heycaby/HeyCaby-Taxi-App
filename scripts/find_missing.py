#!/usr/bin/env python3
"""Find all static const String and static String func entries NOT in our translation dicts."""
import re, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from translations_part1 import T1
from translations_part2 import T2
from translations_part3 import T3
from translations_part4 import T4
T = {}
T.update(T1); T.update(T2); T.update(T3); T.update(T4)

path = sys.argv[1] if len(sys.argv) > 1 else 'apps/driver/lib/l10n/driver_strings.dart'
with open(path, 'r') as f:
    content = f.read()

# Const entries
pat = re.compile(r'^(\s*)static const String (\w+) =\s*(.+?);', re.MULTILINE | re.DOTALL)
seen = set()
for m in pat.findall(content):
    if m[1] in T or m[1] in seen: continue
    seen.add(m[1])
    val = ''.join(re.findall(r"'([^']*)'", m[2]))
    print(f"C|{m[1]}|{val}")

# Func entries
pat2 = re.compile(r'^(\s*)static String (\w+)\(([^)]*)\) =>\s*(.+?);', re.MULTILINE | re.DOTALL)
seen2 = set()
for m in pat2.findall(content):
    if m[1] in T or m[1] in seen2: continue
    seen2.add(m[1])
    val = ''.join(re.findall(r"'([^']*)'", m[3]))
    print(f"F|{m[1]}|{m[2]}|{val}")
