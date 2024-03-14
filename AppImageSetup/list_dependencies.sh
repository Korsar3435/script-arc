#!/bin/bash

SCRIPT_LOCATION=$(realpath "$0")                                                                            #
WORK_LOCATION=$(dirname "$SCRIPT_LOCATION")                                                                 #
                                                                                                            #
# what do we want to analyze for shared objects?                                                            #
TARGET=$1                                                                                                   #
                                                                                                            #
# how do we want to analyze our target?                                                                     #
# valid values are: all (proc & strace & ...), proc, strace                                                 #
VALID_MODES=("all" "proc" "proc+ldd" "proc+f" "proc+ldd+f" "strace" "strace+ldd" "strace+f" "strace+ldd+f") #
MODE=$2                                                                                                     #
                                                                                                            #
# do we want a special prefix for the dependency paths?                                                     #
# e.g. "dep ->" => output: "dep ->/.../xyz.so..."                                                           #
PREFIX=$3                                                                                                   #
                                                                                                            #
# this is where results are temporarily stored                                                              #
OUTPUT_LOG=$WORK_LOCATION/../aux_scripts/tmp_output.txt                                                     #
FAIL_LOG=$WORK_LOCATION/../aux_scripts/tmp_fails.txt                                                        #
                                                                                                            #
# potentially set via fourth arg, only used if a written output is wished                                   #
EXTERNAL_LOG=$4                                                                                             #
                                                                                                            #
# togglable values (0 <=> off)                                                                              #
NORMALIZED_PATHS=0                                                                                          #
                                                                                                            #
#############################################################################################################


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


# proc analysis
# has only two param (PID & ldd on/off), param regarding child procs is in check_proc_wrapper
check_proc(){
    local target_pid=$1
    local ldd_status=$2
    grep '\.so' /proc/$target_pid/maps | awk '{print $6}' | sort -u >> $OUTPUT_LOG
    # vers similar to our approach for strace
    while IFS= read -r dep; do
        if [ -f "$dep" ]; then
            if [ "$ldd_status" -eq 1 ]; then
                # script location, relevant dependency, where to write down results
                $WORK_LOCATION/../aux_scripts/static_analysis.sh $dep $OUTPUT_LOG
            fi
        else
            echo $dep >> $FAIL_LOG
        fi
    done < $OUTPUT_LOG
}

check_proc_wrapper(){
    local target_path=$1
    local ldd_status=$2
    # that's not implemented yet...
    local f_enabled=$3

    # we start the target we intend to analyze
    # that has to happen in the background, so that our script can resume
    $target_path & 2> /dev/null
    local mem_pid=$! 
    sleep 1
    while true; do
        clear -x
        echo "press ${CYAN}r${NOFORMAT} (application ${UNDERLINE}must${NOFORMAT} be running) to read from /proc/${CYAN}${mem_pid}${NOFORMAT}/maps ..."
        echo " "
        read -p "${BG_BLUE}>${NOFORMAT} " answer
        if [ "$answer" == "r" ]; then
            check_proc $mem_pid $ldd_status
            sleep 1
            kill $mem_pid
            break
        fi
    done
}

show_help_message() {
    if [ "$1" == "refresh" ]; then
        clear -x
    fi
    echo "./list_dependencies.sh <${CYAN}path to an ELF${NOFORMAT}> <${CYAN}mode${NOFORMAT}> <${CYAN}optional prefix for depedencies${NOFORMAT}>"
    echo "-> valid modes: ${VALID_MODES[*]}"
    echo "-> the amount of whitespaces indicates the amount of recursive ldd-lookups! (only in $OUTPUT_LOG)"
    exit 0
}


# error checks & information
if [ "$1" == "-h" ]; then
    show_help_message refresh
elif [ "$1" == "-m" ]; then
    echo -e "-> valid modes: ${VALID_MODES[*]}"
    exit 0
elif [ "$#" -gt 0 ]; then
    if [ ! -f $TARGET ]; then
        echo "${RED}error${NOFORMAT}: first arg not a file!"
        exit 1
    elif ! [[ " ${VALID_MODES[*]} " =~ " ${MODE} " ]]; then
        echo -e "${RED}error${NOFORMAT}: second arg not a valid mode!\n-> valid modes: ${VALID_MODES[*]}"
        exit 1
    fi
elif [ "$#" -gt 4 ]; then
    echo "${RED}error${NOFORMAT}: to many arguments! see -h down below"
    show_help_message
    exit 1
else
    echo "${RED}error${NOFORMAT}: not enough arguments! see -h down below"
    show_help_message
    exit 1
fi


# work
# notation: <target of analysis> <ldd on/off> <f on/off>
if [ "$MODE" == "all" ]; then
    check_proc_wrapper $TARGET 1 1
    cp $OUTPUT_LOG "${WORK_LOCATION}/../aux_scripts/tmp_output_part_1.txt"
    rm $OUTPUT_LOG
    sleep 1
    $WORK_LOCATION/../aux_scripts/dynamic_analysis.sh $TARGET 1 1
    cp $OUTPUT_LOG "${WORK_LOCATION}/../aux_scripts/tmp_output_part_2.txt"
    rm $OUTPUT_LOG
    sleep 1
    cat "${WORK_LOCATION}/../aux_scripts/tmp_output_part_1.txt" "${WORK_LOCATION}/../aux_scripts/tmp_output_part_2.txt" >> $OUTPUT_LOG
    rm "${WORK_LOCATION}/../aux_scripts/tmp_output_part_1.txt"
    rm "${WORK_LOCATION}/../aux_scripts/tmp_output_part_2.txt"
elif [ "$MODE" == "proc" ]; then
    check_proc_wrapper $TARGET 0 0
elif [ "$MODE" == "proc+ldd" ]; then
    check_proc_wrapper $TARGET 1 0
elif [ "$MODE" == "proc+f" ]; then
    check_proc_wrapper $TARGET 0 1
elif [ "$MODE" == "proc+ldd+f" ]; then
    check_proc_wrapper $TARGET 1 1
elif [ "$MODE" == "strace" ]; then
    $WORK_LOCATION/../aux_scripts/dynamic_analysis.sh $TARGET 0 0
elif [ "$MODE" == "strace+ldd" ]; then
    $WORK_LOCATION/../aux_scripts/dynamic_analysis.sh $TARGET 1 0
elif [ "$MODE" == "strace+f" ]; then
    $WORK_LOCATION/../aux_scripts/dynamic_analysis.sh $TARGET 0 1
elif [ "$MODE" == "strace+ldd+f" ]; then
    $WORK_LOCATION/../aux_scripts/dynamic_analysis.sh $TARGET 1 1
fi


# print log entries
if [ "$#" -gt 1 ]; then
    cat $OUTPUT_LOG | sort -u | while read -r dep; do
    if [ "$NORMALIZED_PATHS" -eq 1 ]; then
        dep=$(realpath $dep)
    fi
    if [ "$#" -eq 4 ]; then
        echo "${PREFIX}${dep}" >> $EXTERNAL_LOG
    else
        echo "${PREFIX}${dep}"
    fi
    done
else
    cat $OUTPUT_LOG | sort -u | while read -r dep; do
        echo $dep	
    done
fi


rm -f $FAIL_LOG
rm $OUTPUT_LOG
