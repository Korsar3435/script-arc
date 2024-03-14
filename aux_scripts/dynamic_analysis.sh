#!/bin/bash

SCRIPT_LOCATION=$(realpath "$0")
WORK_LOCATION=$(dirname "$SCRIPT_LOCATION")

TARGET_PATH=$1
STRACE_LOG=$WORK_LOCATION/tmp_strace_log.txt
OUTPUT_LOG=$WORK_LOCATION/tmp_output.txt
FAIL_LOG=$WORK_LOCATION/tmp_fails.txt

# 0 <=> without ldd, 1 <=> with ldd 
LDD_MODE=$2

# 0 <=> no child-proc analysis, 1 <=> with child-proc analysis
FORK_MODE=$3

# color constants
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
BG_RED=`tput setab 1`
BG_YELLOW=`tput setab 3`
BG_BLUE=`tput setab 4`
BG_CYAN=`tput setab 6`
BG_WHITE=`tput setab 7`
UNDERLINE=`tput smul` 
NOUNDERLINE=`tput rmul`
BOLD=`tput bold`
ITALIC=`tput sitm`
NOFORMAT=`tput sgr0`

clear -x
echo "${TARGET_PATH} is ${CYAN}traced${NOFORMAT} by ${CYAN}${UNDERLINE}strace${NOFORMAT}, waiting for ${CYAN}manual termination${NOFORMAT} ..."
echo " "
# goal: we want to know every dependency, even dynamically loaded plugins
# -e trace=open,openat => we want to know any opened file (=> *.so)
if [ "$FORK_MODE" -eq 1 ]; then
    strace -f -e trace=open,openat $TARGET_PATH 2>$STRACE_LOG
else
    strace -e trace=open,openat $TARGET_PATH 2>$STRACE_LOG
fi
# we're waiting for the user to terminate!


# basic awk samples: https://www.golinuxcloud.com/awk-examples-with-command-tutorial-unix-linux/
# -> awk '{print $0}' /tmp/userdata.txt + pattern matching
# match: "<anything>.so<anything>" (that includes for example ""abc.so", "a" "x.so" but not "a")
# "sort -u" => removes duplicats
# the rest (resulting dependencies) will be fed in our while loop, an iteration per single dep(endency)
awk 'match($0, /".*\.so[^"]*"/) { print substr($0, RSTART, RLENGTH) }' $STRACE_LOG | sort -u | while read -r dep; do
    # cut the first and last symbol (both ")
    dep=${dep:1:-1}
    if [ -f "$dep" ]; then
        echo $dep >> $OUTPUT_LOG
        if [ "$LDD_MODE" -eq 1 ]; then
            # script location, relevant dependency, where to write down results
            $WORK_LOCATION/static_analysis.sh $dep $OUTPUT_LOG
        fi
    else
        echo $dep >> $FAIL_LOG
    fi
done

rm $STRACE_LOG
