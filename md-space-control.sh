#!/usr/bin/env bash

# Script: md-space-control.sh
# Purpose: Reformat Markdown files to have tight lists (no empty lines between items)
# Usage: md-space-control.sh [OPTIONS] [file1.md file2.md ...]
#        cat file.md | md-space-control.sh [OPTIONS]

# Function to show usage
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [file1.md file2.md ...]
       cat file.md | $(basename "$0") [OPTIONS]

Reformat Markdown files to have tight lists (no empty lines between list items).
When no files are provided, acts as a pipe filter reading from stdin.

OPTIONS:
    -h, --help      Show this help message and exit

EXAMPLES:
    # Process files in-place
    $(basename "$0") document1.md document2.md
    
    # Process all .md files in current directory
    $(basename "$0") *.md
    
    # Use as a pipe filter
    cat README.md | $(basename "$0") > README_clean.md
    
    # Process clipboard content
    pbpaste | $(basename "$0") | pbcopy

EOF
}

# Function to process markdown content
process_markdown() {
    awk '
    BEGIN {
        in_frontmatter = 0
        frontmatter_ended = 0
        in_list = 0
        prev_marker = ""
        prev_indent = -1
        prev_list_class = ""
        current_output_marker = "-"  # Track what we are outputting: dash or asterisk
        last_top_level_marker = ""  # Track the last top-level marker we saw
    }
    
    # Handle frontmatter
    NR == 1 && /^---$/ {
        in_frontmatter = 1
        print
        next
    }
    
    in_frontmatter && /^---$/ {
        in_frontmatter = 0
        frontmatter_ended = 1
        print
        next
    }
    
    in_frontmatter {
        print
        next
    }
    
    # Regular processing after frontmatter
    /^[[:space:]]*[-*+][[:space:]]/ || /^[[:space:]]*[-*+][[:space:]]*$/ || /^[[:space:]]*[0-9]+\.[[:space:]]/ {
        # This is a list item
        
        # Extract indentation level
        match($0, /^[[:space:]]*/)
        indent = RLENGTH
        
        # Extract marker
        if (match($0, /^[[:space:]]*[0-9]+\.[[:space:]]/)) {
            marker = "ordered"
            list_class = "ordered"
        } else if (match($0, /^[[:space:]]*[-*+][[:space:]]/) || match($0, /^[[:space:]]*[-*+]$/)) {
            # Extract the specific marker character
            match($0, /^[[:space:]]*/)
            prefix_len = RLENGTH
            marker = substr($0, prefix_len + 1, 1)
            list_class = "unordered"
        }
        
        # Determine if we need a separator
        need_separator = 0
        
        if (!in_list && NR > 1 && last_line != "") {
            # Starting a new list after non-list content
            need_separator = 1
            current_output_marker = "-"  # Reset to dash for new list
        } else if (in_list && indent == 0) {
            if (prev_indent == 0) {
                # Top-level to top-level - check exact marker
                if (marker != prev_marker) {
                    need_separator = 1
                    # Alternate the output marker
                    if (current_output_marker == "-") {
                        current_output_marker = "*"
                    } else {
                        current_output_marker = "-"
                    }
                }
            } else {
                # Coming from nested to top-level
                # We need to track the last top-level marker
                if (marker != last_top_level_marker && last_top_level_marker != "") {
                    need_separator = 1
                    # Also need to alternate the output marker
                    if (current_output_marker == "-") {
                        current_output_marker = "*"
                    } else {
                        current_output_marker = "-"
                    }
                }
            }
        }
        # That is it - no other cases need separators
        # All nested lists should be tight
        
        if (need_separator) {
            print ""
        }
        
        
        # Handle marker normalization for unordered lists
        if (list_class == "unordered") {
            spaces = ""
            for (i = 0; i < indent; i++) spaces = spaces " "
            
            # Check if this is an empty list item
            if (match($0, /^[[:space:]]*[-*+]$/)) {
                # Replace the whole line with just the marker (no trailing space)
                if (indent > 0) {
                    $0 = spaces "-"
                } else {
                    $0 = spaces current_output_marker
                }
            } else {
                # Regular list item with content
                if (indent > 0) {
                    # Nested items always use dash
                    sub(/^[[:space:]]*[-*+]/, spaces "-")
                } else {
                    # Top-level: use current_output_marker
                    sub(/^[[:space:]]*[-*+]/, spaces current_output_marker)
                }
            }
        }
        
        # Update tracking variables
        if (indent == 0) {
            last_top_level_marker = marker
        }
        
        in_list = 1
        prev_marker = marker
        prev_indent = indent
        prev_list_class = list_class
        
        # Handle trailing whitespace
        if (match($0, /  $/)) {
            # Two spaces at end = line break, convert to backslash
            sub(/  $/, "\\")
        } else {
            # Remove other trailing whitespace
            sub(/[[:space:]]+$/, "")
        }
        print
        next
    }
    {
        # Not a list item
        if (in_list && $0 != "") {
            print ""  # Add empty line after list block
            in_list = 0
            prev_marker = ""
            prev_list_class = ""
            last_top_level_marker = ""
            current_output_marker = "-"  # Reset to dash for next list
        }
        if ($0 != "" || !in_list) {
            # Handle trailing whitespace
            if (match($0, /  $/)) {
                # Two spaces at end = line break, convert to backslash
                sub(/  $/, "\\")
            } else {
                # Remove other trailing whitespace
                sub(/[[:space:]]+$/, "")
            }
            print
        }
        last_line = $0
    }
    '
}


# Parse options
files=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            echo "Use -h or --help for usage information." >&2
            exit 1
            ;;
        *)
            files[${#files[@]}]="$1"
            shift
            ;;
    esac
done

# If no files specified, act as a pipe filter
if [ ${#files[@]} -eq 0 ]; then
    process_markdown
    exit 0
fi

# Process files
for file in "${files[@]}"; do
    # Check if file exists
    if [ ! -f "$file" ]; then
        echo "Warning: '$file' not found, skipping..." >&2
        continue
    fi
    
    # Check if file has .md extension
    if [[ ! "$file" =~ \.md$ ]]; then
        echo "Warning: '$file' is not a .md file, skipping..." >&2
        continue
    fi
    
    # Create temporary file
    tmpfile=$(mktemp)
    
    # Process the file
    if process_markdown < "$file" > "$tmpfile"; then
        # Replace original file with processed version
        mv "$tmpfile" "$file"
        echo "✓ Processed: $file" >&2
    else
        # Remove temp file on error
        rm -f "$tmpfile"
        echo "✗ Error processing: $file" >&2
    fi
done