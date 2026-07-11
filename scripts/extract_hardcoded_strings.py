#!/usr/bin/env python3
"""Extract all hardcoded static const String entries from driver_strings.dart."""
import re
import sys

def main():
    path = sys.argv[1] if len(sys.argv) > 1 else 'apps/driver/lib/l10n/driver_strings.dart'
    with open(path, 'r') as f:
        content = f.read()
    
    # Pattern: static const String varName = 'literal';
    # or multi-line: static const String varName =\n      'literal';
    # Skip entries that reference other variables (not string literals)
    # Skip @Deprecated entries
    
    lines = content.split('\n')
    i = 0
    entries = []
    while i < len(lines):
        line = lines[i]
        # Check for @Deprecated annotation - skip next entry
        if '@Deprecated' in line:
            i += 1
            continue
        
        # Match: static const String varName = '...'
        m = re.match(r"^\s*static const String (\w+) =\s*'", line)
        if m:
            var_name = m.group(1)
            # Collect the full string value (might span multiple lines)
            # Find the closing quote
            start_idx = line.find("'") + 1
            # Check if it's a multi-line string
            remaining = line[start_idx:]
            if remaining.endswith("';"):
                value = remaining[:-2]
            elif remaining.endswith("'"):
                # Multi-line string - collect continuation lines
                value_parts = [remaining[:-1]]
                i += 1
                while i < len(lines):
                    next_line = lines[i].strip()
                    if next_line.endswith("';"):
                        value_parts.append(next_line[:-2])
                        break
                    elif next_line.endswith("'"):
                        value_parts.append(next_line[:-1])
                        i += 1
                        continue
                    else:
                        value_parts.append(next_line)
                        i += 1
                value = ' '.join(value_parts)
            else:
                i += 1
                continue
            
            entries.append((i + 1, var_name, value))
        
        # Also match: static String funcName(params) => 'literal';
        m2 = re.match(r"^\s*static String (\w+)\(([^)]*)\) =>\s*'", line)
        if m2:
            func_name = m2.group(1)
            params = m2.group(2)
            start_idx = line.find("=> '") + 4
            remaining = line[start_idx:]
            if remaining.endswith("';"):
                value = remaining[:-2]
                entries.append((i + 1, f"{func_name}({params})", value))
        
        i += 1
    
    # Output entries
    for line_num, name, value in entries:
        print(f"L{line_num}\t{name}\t{value}")

if __name__ == '__main__':
    main()
