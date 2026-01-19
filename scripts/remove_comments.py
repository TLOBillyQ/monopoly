#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Lua comment remover - removes all comments from Lua files while preserving code structure
"""

import re
import os
from pathlib import Path


def remove_lua_comments(content):
    """
    Remove all comments from Lua code while preserving strings and structure.
    
    Returns:
        tuple: (cleaned_content, comment_count, line_changes)
    """
    lines = content.split('\n')
    result_lines = []
    comment_count = 0
    in_multiline_comment = False
    multiline_depth = 0
    original_line_count = len(lines)
    
    i = 0
    while i < len(lines):
        line = lines[i]
        processed_line = ""
        j = 0
        line_has_comment = False
        
        while j < len(line):
            # Handle multiline comments
            if in_multiline_comment:
                # Check for closing multiline comment --]..]=--
                if j < len(line) - 2 and line[j:j+3] == '--]':
                    k = j + 3
                    bracket_count = 0
                    while k < len(line) and line[k] == ']':
                        bracket_count += 1
                        k += 1
                    
                    # Check for = signs and final --
                    if k < len(line) - 1 and line[k:k+2] == '--':
                        # Simplified: just close if bracket count matches
                        if multiline_depth == bracket_count:
                            multiline_depth = 0
                            in_multiline_comment = False
                            comment_count += 1
                            j = k + 2
                            continue
                
                j += 1
                continue
            
            # Check for multiline comment start --[...[
            if j < len(line) - 2 and line[j:j+3] == '--[':
                k = j + 3
                bracket_count = 0
                while k < len(line) and line[k] == '[':
                    bracket_count += 1
                    k += 1
                
                if bracket_count > 0:
                    in_multiline_comment = True
                    multiline_depth = bracket_count
                    comment_count += 1
                    j = k
                    line_has_comment = True
                    continue
            
            # Check for string start (handle both " and ')
            if line[j] in ('"', "'"):
                quote = line[j]
                processed_line += line[j]
                j += 1
                # Process string content - preserve everything in strings
                while j < len(line):
                    char = line[j]
                    processed_line += char
                    if char == '\\':
                        j += 1
                        if j < len(line):
                            processed_line += line[j]
                            j += 1
                    elif char == quote:
                        j += 1
                        break
                    else:
                        j += 1
                continue
            
            # Check for single-line comment -- (not part of string)
            if j < len(line) - 1 and line[j:j+2] == '--':
                # Check if this is not a multiline comment start
                if j >= len(line) - 2 or line[j+2] != '[':
                    comment_count += 1
                    line_has_comment = True
                    break  # Rest of line is comment
            
            processed_line += line[j]
            j += 1
        
        # Process the line
        processed_line = processed_line.rstrip()
        
        # Add line if it's not empty or if we're in a multiline comment
        if processed_line or in_multiline_comment:
            result_lines.append(processed_line)
        elif not processed_line and not line_has_comment:
            # Preserve truly empty lines
            result_lines.append("")
        
        i += 1
    
    # Clean up trailing empty lines
    while result_lines and not result_lines[-1].strip():
        result_lines.pop()
    
    cleaned_content = '\n'.join(result_lines)
    final_line_count = len(result_lines)
    line_changes = original_line_count - final_line_count
    
    return cleaned_content, comment_count, line_changes


def process_lua_files(src_dir):
    """
    Process all Lua files in the source directory.
    """
    src_path = Path(src_dir)
    lua_files = sorted(src_path.rglob('*.lua'))
    
    results = []
    total_comments = 0
    
    print(f"Found {len(lua_files)} Lua files to process\n")
    
    for lua_file in lua_files:
        try:
            with open(lua_file, 'r', encoding='utf-8') as f:
                original_content = f.read()
            
            cleaned_content, comment_count, line_changes = remove_lua_comments(original_content)
            
            # Write back the cleaned content
            with open(lua_file, 'w', encoding='utf-8') as f:
                f.write(cleaned_content)
            
            total_comments += comment_count
            
            rel_path = lua_file.relative_to(src_path.parent)
            results.append({
                'file': str(rel_path),
                'comments': comment_count,
                'lines_removed': line_changes,
                'status': 'SUCCESS'
            })
            
            print(f"✓ {rel_path} - {comment_count} comments removed, {line_changes} lines reduced")
            
        except Exception as e:
            rel_path = lua_file.relative_to(src_path.parent)
            results.append({
                'file': str(rel_path),
                'comments': 0,
                'lines_removed': 0,
                'status': f'ERROR: {str(e)}'
            })
            print(f"✗ {rel_path} - ERROR: {str(e)}")
    
    return results, total_comments


def main():
    src_dir = r'c:\Users\Lzx_8\Desktop\eggitor\1_开发中\大富翁\monopoly\src'
    
    print("=" * 80)
    print("Lua Comment Remover")
    print("=" * 80)
    print(f"Processing directory: {src_dir}\n")
    
    results, total_comments = process_lua_files(src_dir)
    
    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"Total files processed: {len(results)}")
    print(f"Total comments removed: {total_comments}")
    
    successful = [r for r in results if r['status'] == 'SUCCESS']
    failed = [r for r in results if r['status'] != 'SUCCESS']
    
    print(f"Successful: {len(successful)}")
    print(f"Failed: {len(failed)}")
    
    if failed:
        print("\nFailed files:")
        for r in failed:
            print(f"  - {r['file']}: {r['status']}")
    
    print("\nDetailed Results:")
    print("-" * 80)
    print(f"{'File':<60} {'Comments':<12} {'Lines'}")
    print("-" * 80)
    
    for r in sorted(results, key=lambda x: x['file']):
        if r['status'] == 'SUCCESS':
            print(f"{r['file']:<60} {r['comments']:<12} {r['lines_removed']}")
    
    print("=" * 80)


if __name__ == '__main__':
    main()
