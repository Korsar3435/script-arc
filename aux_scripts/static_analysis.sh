#!/bin/bash

ALLOWED_DEPTH=100
START_DEPTH=0

TARGET_PATH=$1
OUTPUT_LOG=$2

SCRIPT_LOCATION=$(realpath "$0")
WORK_LOCATION=$(dirname "$SCRIPT_LOCATION")


# goal: we want to know every dependency
function note_deps() {

    local elf_target=$1
    local local_depth=$2
    local depth_for_new_targets=$2

    if ((local_depth < ALLOWED_DEPTH)); then
        ((depth_for_new_targets=(local_depth+1)))
        # grab everything that has "=> /..." (i.e. a path) and ...
        # ... show me the third part (separated by whitespaces via awk)
        # "c.so => /a/b/c.so (0x0000....)" -> "1 2 3 4" -> 3=/a/b/c.so !
        # problem: we can have whitespaces in paths (escape via \) ...
        # -> this analysis can miss these dependencies !
        local deps=$(ldd "$elf_target" | grep '=> /' | awk '{print $3}')

        for dep in $deps; do
            # if already known -> ignore
            if ! grep -q "$dep" "$OUTPUT_LOG"; then
                if [ -f "$dep" ]; then
                    # that scales the whitespace-offset
                    local mod_dep=$(printf "%*s%s" $local_depth "" "$dep") 
                    echo -n "" >> $OUTPUT_LOG
                    echo "$mod_dep" >> $OUTPUT_LOG
                fi
                # recursive call for individual dep
                note_deps $dep $depth_for_new_targets
            fi
        done
    fi
}

note_deps $TARGET_PATH $START_DEPTH