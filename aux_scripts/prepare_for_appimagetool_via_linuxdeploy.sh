#!/bin/bash

ANALYZE_BIN_PATH=$1

SCRIPT_LOCATION=$(realpath "$0")
WORK_LOCATION=$(dirname "$SCRIPT_LOCATION")

# list-utility, used for dependency suggestions
LIST_SCRIPT=$WORK_LOCATION/../AppImageSetup/list_dependencies.sh
LIST_SCRIPT_MODE=$2
DEPENDENCIES_LIST=$WORK_LOCATION/linuxdeploy_path_list.txt
DEPENDENCIES_WARNINGS=$WORK_LOCATION/linuxdeploy_warnings.txt

# the rest of args (apart from $1; Target & $2; Mode) are just going through
shift
shift
EXTRA_ARGS="${@}"

LINUXDEPLOY_TOOL=$(realpath "${WORK_LOCATION}/../AppImageSetup/linuxdeploy-static-x86_64.AppImage")
APPDIR_PATH=$(realpath "${WORK_LOCATION}/../AppImageSetup/Motiv.AppDir")

# if we intend to build with the help of the qt-plugin we have to specify this
# we need qmake6 for motiv (qt6 App)
QMAKE_PATH=$(which qmake6)

# togglable values (yes/no)
NORMALIZED_PATHS=no


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


# clean possible remants from earlier runs
if [ -f $DEPENDENCIES_LIST ]; then
    rm -f $DEPENDENCIES_LIST
fi
if [ -f $DEPENDENCIES_WARNINGS ]; then
    rm -f $DEPENDENCIES_WARNINGS
fi

# get dependencies
if [ -f $ANALYZE_BIN_PATH ]; then
    # .../list_dependencies.sh (invokes strace) .../motiv (the binary we're interested in) logfile
    $LIST_SCRIPT "$ANALYZE_BIN_PATH" "$LIST_SCRIPT_MODE" "" "$DEPENDENCIES_LIST"
else
    echo "${YELLOW}warning${NOFORMAT}: can't find referenced binary! ${ANALYZE_BIN_PATH}"
    echo "         skipping the use of ${LIST_SCRIPT}"
fi

sleep 1
clear -x
if [ -f $DEPENDENCIES_LIST ] ; then
    echo "${BG_BLUE}Q${NOFORMAT} the dependencies list is ready, do you wish to review the libraries ?"
    echo "  -> list location: ${DEPENDENCIES_LIST}\n"
    read -p "press any key to resume the script ... " confirmation
else
    echo "... ${LIST_SCRIPT} has failed to produce a list of dependencies !"
fi

# include found dependencies
DEPENDENCIES_FORMAT=""
while IFS= read -r path; do
    # better filter than "-f ...", the later leads to matches with .so.cache!
    if [ -f $path ]; then
        # if it exists we add the path (after normalizing: a/b/../c -> a/c)
        if [ "$NORMALIZED_PATHS" = "yes" ]; then	
            path=$(realpath $path)
        fi
        DEPENDENCIES_FORMAT+=" --library=$path"
    elif [ -d "$path" ]; then
        echo "${path} is a directory!" > $DEPENDENCIES_WARNINGS
    else
        echo "${path} is neither file nor directory!" > $DEPENDENCIES_WARNINGS
    fi
done < $DEPENDENCIES_LIST

sleep 1
# we don't match directly with "--plugin ..." (flag structure leads to problems with grep) 
if echo $EXTRA_ARGS | grep -q "plugin qt"; then
    export QMAKE=$QMAKE_PATH
    if [ ! -f $QMAKE ]; then
        echo "${RED}error${NOFORMAT}: can't find qmake -> >>--plugin qt<< will probably not work properly!"
        exit 1
    fi
fi

sleep 1
if [ -n "$EXTRA_ARGS" ]; then
    # our final parameters for the linuxdeploy tool - uncomment for debugging reasons, e.g. echo ... > dbg_input.txt
    echo "${LINUXDEPLOY_TOOL} --appdir=${APPDIR_PATH}${DEPENDENCIES_FORMAT} ${EXTRA_ARGS}"
    $LINUXDEPLOY_TOOL --appdir=$APPDIR_PATH$DEPENDENCIES_FORMAT $EXTRA_ARGS
else
    # our final parameters for the linuxdeploy tool - uncomment for debugging reasons, e.g. echo ... > dbg_input.txt
    echo "${LINUXDEPLOY_TOOL} --appdir=${APPDIR_PATH}${DEPENDENCIES_FORMAT}"
    $LINUXDEPLOY_TOOL --appdir=$APPDIR_PATH$DEPENDENCIES_FORMAT
fi
