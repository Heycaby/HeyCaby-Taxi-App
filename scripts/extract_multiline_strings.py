#!/usr/bin/env python3
"""Extract all multi-line static const String entries from driver_strings.dart."""
import re
import sys

def main():
    path = sys.argv[1] if len(sys.argv) > 1 else 'apps/driver/lib/l10n/driver_strings.dart'
    with open(path, 'r') as f:
        lines = f.readlines()
    
    i = 0
    entries = []
    while i < len(lines):
        line = lines[i].rstrip('\n')
        # Match: static const String varName = (end of line)
        m = re.match(r"^(\s*)static const String (\w+) =\s*$", line)
        if m:
            var_name = m.group(2)
            line_num = i + 1
            # Collect string value from subsequent lines
            value_parts = []
            j = i + 1
            while j < len(lines):
                next_line = lines[j].strip()
                if next_line.endswith("';"):
                    # Remove trailing ';
                    val = next_line[:-2]
                    if val.startswith("'"):
                        val = val[1:]
                    value_parts.append(val)
                    end_j = j
                    break
                elif next_line.endswith("'"):
                    # String continuation
                    val = next_line
                    if val.startswith("'"):
                        val = val[1:]
                    if val.endswith("'"):
                        val = val[:-1]
                    value_parts.append(val)
                    j += 1
                else:
                    j += 1
            
            full_value = ''.join(value_parts) if len(value_parts) == 1 else ' '.join(value_parts)
            entries.append((line_num, var_name, full_value))
            i = end_j + 1 if 'end_j' in dir() else i + 1
        else:
            i += 1
    
    for line_num, name, value in entries:
        # Escape for Python dict
        value_escaped = value.replace("'", "\\'")
        print(f"    \"{name}\": (\"{value_escaped}\", \"\", \"\", \"\"),  # L{line_num}")

if __name__ == '__main__':
    main()
