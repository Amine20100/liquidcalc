import os
import glob
import sys

def check_swift_file(path):
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    stack = []
    in_block_comment = False
    for line_num, line in enumerate(lines, 1):
        i = 0
        in_string = False
        string_char = ''
        while i < len(line):
            ch = line[i]
            if in_block_comment:
                if ch == '*' and i + 1 < len(line) and line[i+1] == '/':
                    in_block_comment = False
                    i += 2
                    continue
                i += 1
                continue
            if not in_string and ch == '/' and i + 1 < len(line) and line[i+1] == '*':
                in_block_comment = True
                i += 2
                continue
            if not in_string and ch == '/' and i + 1 < len(line) and line[i+1] == '/':
                break
            if ch in ('"', "'") and not in_string:
                # Check for multiline string """
                if i + 2 < len(line) and line[i:i+3] == '"""':
                    # Simplification for single-line multiline
                    i += 3
                    continue
                in_string = True
                string_char = ch
                i += 1
                continue
            elif in_string and ch == string_char:
                escapes = 0
                k = i - 1
                while k >= 0 and line[k] == '\\':
                    escapes += 1
                    k -= 1
                if escapes % 2 == 0:
                    in_string = False
                i += 1
                continue
            if not in_string:
                if ch in '({[':
                    stack.append((ch, line_num))
                elif ch in ')}]':
                    matching = {'(': ')', '{': '}', '[': ']'}
                    if not stack:
                        return f"Unexpected closing {ch} at line {line_num}"
                    top, top_line = stack.pop()
                    if matching[top] != ch:
                        return f"Mismatched {top} (line {top_line}) with {ch} (line {line_num})"
            i += 1
    if stack:
        top, top_line = stack.pop()
        return f"Unclosed {top} from line {top_line}"
    return None

def main():
    swift_files = glob.glob('LiquidCalc/**/*.swift', recursive=True) + glob.glob('LiquidCalcTests/**/*.swift', recursive=True)
    errors = []
    for sf in swift_files:
        err = check_swift_file(sf)
        if err:
            errors.append(f"{sf}: {err}")

    print(f"Checked {len(swift_files)} Swift source and test files.")
    if errors:
        print("ERRORS FOUND:")
        for e in errors:
            print(f"  [FAIL] {e}")
        sys.exit(1)
    else:
        print("SUCCESS: All Swift files have 100% valid bracket and block scoping!")

if __name__ == '__main__':
    main()
