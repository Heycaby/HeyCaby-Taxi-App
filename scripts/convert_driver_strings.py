#!/usr/bin/env python3
"""Convert all hardcoded static const String entries in driver_strings.dart to _t() calls.
Uses regex on full file content to handle both single-line and multi-line patterns."""
import re
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from translations_part1 import T1
from translations_part2 import T2
from translations_part3 import T3
from translations_part4 import T4
from translations_part5 import T5
from translations_part6 import T6
from translations_part7 import T7

T = {}
T.update(T1)
T.update(T2)
T.update(T3)
T.update(T4)
T.update(T5)
T.update(T6)
T.update(T7)

def escape_dart_string(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")

def make_t_call(nl, en, es, ar):
    nl_e = escape_dart_string(nl)
    en_e = escape_dart_string(en)
    es_e = escape_dart_string(es)
    ar_e = escape_dart_string(ar)
    return ("_t(\n"
            f"        '{nl_e}',\n"
            f"        en: '{en_e}',\n"
            f"        es: '{es_e}',\n"
            f"        ar: '{ar_e}',\n"
            "      )")

def make_param_t_call(nl, en, es, ar):
    nl_e = escape_dart_string(nl)
    en_e = escape_dart_string(en)
    es_e = escape_dart_string(es)
    ar_e = escape_dart_string(ar)
    return f"_t('{nl_e}', en: '{en_e}', es: '{es_e}', ar: '{ar_e}')"

def extract_string_value(raw):
    raw = raw.strip()
    parts = re.findall(r"'([^']*)'", raw)
    return ''.join(parts)

def main():
    file_path = sys.argv[1] if len(sys.argv) > 1 else 'apps/driver/lib/l10n/driver_strings.dart'
    dry_run = '--dry-run' in sys.argv

    with open(file_path, 'r') as f:
        content = f.read()

    converted = 0
    skipped = 0
    errors = []

    pattern_const = re.compile(
        r'^(\s*)static const String (\w+) =\s*(.+?);',
        re.MULTILINE | re.DOTALL
    )

    def replace_const(m):
        nonlocal converted, skipped, errors
        indent = m.group(1)
        var_name = m.group(2)
        raw_value = m.group(3)

        if var_name in T:
            nl, en, es, ar = T[var_name]
            t_call = make_t_call(nl, en, es, ar)
            converted += 1
            return f"{indent}static String get {var_name} => {t_call};"
        else:
            value = extract_string_value(raw_value)
            errors.append(f"No translation for '{var_name}' = '{value[:60]}'")
            skipped += 1
            return m.group(0)

    content = pattern_const.sub(replace_const, content)

    pattern_func = re.compile(
        r'^(\s*)static String (\w+)\(([^)]*)\) =>\s*(.+?);',
        re.MULTILINE | re.DOTALL
    )

    def replace_func(m):
        nonlocal converted, skipped, errors
        indent = m.group(1)
        func_name = m.group(2)
        params = m.group(3)
        raw_value = m.group(4)

        # Skip already-converted entries (either starts with _t or contains _t in ternary/switch)
        if '_t(' in raw_value:
            return m.group(0)

        if func_name in T:
            nl, en, es, ar = T[func_name]
            t_call = make_param_t_call(nl, en, es, ar)
            converted += 1
            return f"{indent}static String {func_name}({params}) => {t_call};"
        else:
            value = extract_string_value(raw_value)
            errors.append(f"No translation for func '{func_name}({params})' = '{value[:60]}'")
            skipped += 1
            return m.group(0)

    content = pattern_func.sub(replace_func, content)

    if not dry_run:
        with open(file_path, 'w') as f:
            f.write(content)

    print(f"Converted: {converted}")
    print(f"Skipped: {skipped}")
    print(f"Errors: {len(errors)}")
    for e in errors[:30]:
        print(f"  {e}")
    if len(errors) > 30:
        print(f"  ... and {len(errors) - 30} more")

if __name__ == '__main__':
    main()
