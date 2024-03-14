#!/bin/bash
                                                                                                              #
SCRIPT_LOCATION=$(realpath "$0")                                                                              #
WORK_LOCATION=$(dirname "$SCRIPT_LOCATION")                                                                   #
BINARY_NAME=motiv                                                                                             #
                                                                                                              #
# the MOTIV_INSTALL_BINARY has to be actually set via the first argument, see -h                              #
MOTIV_INSTALL_BINARY=~/motiv/build/motiv                                                                      #
TARGET_BINARY_DIR=$WORK_LOCATION/Motiv.AppDir/usr/bin                                                         #
TARGET_BINARY=$TARGET_BINARY_DIR/$BINARY_NAME                                                                 #
TARGET_LIB=$WORK_LOCATION/Motiv.AppDir/usr/lib                                                                #
                                                                                                              #
APPDIR_TEMPLATE_ARCHIVE=$WORK_LOCATION/../aux_files/Motiv.AppDir.tar.gz                                       #
APPDIR_PATH=$WORK_LOCATION/Motiv.AppDir                                                                       #
APPIMAGE_PATH=$WORK_LOCATION/Motiv.AppImage                                                                   #
                                                                                                              #
APPIMAGETOOL_PATH=$WORK_LOCATION/appimagetool-x86_64.AppImage                                                 #
                                                                                                              #
# helper scripts                                                                                              #
# list-utility, used for dependency suggestions                                                               #
LIST_SCRIPT=$WORK_LOCATION/list_dependencies.sh                                                               #
LIST_SCRIPT_MODE=strace+ldd                                                                                   #
# wrapper for linuxdeploy                                                                                     #
LINUXDEPLOY_SCRIPT_PATH=$WORK_LOCATION/../aux_scripts/prepare_for_appimagetool_via_linuxdeploy.sh             #
                                                                                                              #
# temporary files                                                                                             #
COPY_DIALOGUE_LIST=$WORK_LOCATION/../aux_scripts/tmp_copy_dialogue.txt                                        #
LDEPLOY_LIST=$WORK_LOCATION/../aux_scripts/linuxdeploy_path_list.txt                                          #
LDEPLOY_LIST_W=$WORK_LOCATION/../aux_scripts/linuxdeploy_path_warnings.txt                                    #
                                                                                                              #
# togglable values (yes/no)                                                                                   #
NORMALIZED_PATHS=no                                                                                           #
                                                                                                              #
# default: all 'no'                                                                                           #
ALWAYS_WORKAROUND=no                                                                                          #
SKIP_WORKAROUND_QUESTION=no                                                                                   #
ALWAYS_SET_RPATH_TO_ORIGIN=no                                                                                 #
SKIP_RPATH_QUESTION=no                                                                                        #
                                                                                                              #
# rpath settings (for manual patchelf use)                                                                    #
BINARY_RPATH=\$ORIGIN/../lib                                                                                 #
LIBRARY_RPATH=\$ORIGIN                                                                                       #
                                                                                                              #
###############################################################################################################

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


# copy-wrapper for list_dependencies.sh script
copy_dialogue() {
    local valid_modes=$($LIST_SCRIPT -m)
    clear -x
    while true; do
        if [ -f $LIST_SCRIPT ]; then
            echo -e "${BG_BLUE}Q${NOFORMAT} what ${CYAN}dependency search mode${NOFORMAT} do you want to use?"
            echo "  "$valid_modes
            read -p "${BG_BLUE}>${NOFORMAT} " answer
            echo "  "
            if [[ " ${valid_modes[*]} " =~ " ${answer} " ]]; then
                LIST_SCRIPT_MODE=$answer
                # "" <=> explicit empty arg
                # .sh <what to analyze> <in which mode> <print with prefix> <in a specific file>
                $LIST_SCRIPT "$MOTIV_INSTALL_BINARY" "$LIST_SCRIPT_MODE" "" "$COPY_DIALOGUE_LIST"
                break
            else
                clear -x
                echo "please try again"
            fi
        else	
            echo "${RED}error${NOFORMAT}: can't find list utility, expected in -> $LIST_SCRIPT"
            exit 1
        fi
    done

    sleep 1
    clear -x
    if [ -f $COPY_DIALOGUE_LIST ]; then
        echo "${BG_BLUE}Q${NOFORMAT} the dependencies list is ready, do you wish to review the libraries ?"
        echo "  -> list location: ${COPY_DIALOGUE_LIST}"
        read -p "press ${CYAN}any letter${NOFORMAT} to resume the script ... " confirmation
    else
        echo "... ${LIST_SCRIPT} has failed to produce a list of dependencies !"
    fi

    for dep_pth in $(cat $COPY_DIALOGUE_LIST); do
        if [ -f $dep_pth ]; then
            # TODO: how shall symlinks be treated?  
            # -> see "cp --help"
            #cp --dereference $dep_pth $TARGET_LIB
            #cp --no-dereference $dep_pth $TARGET_LIB
            cp $dep_pth $TARGET_LIB
        else
            echo "can't find ${dep_pth}, skipping ..."
        fi
    done
    rm -f $COPY_DIALOGUE_LIST
}

check_paths() {
    if strings $1 | grep -q "/usr"; then
        clear -x
        while [ "$ALWAYS_WORKAROUND" == "no" ]; do
            echo -e "${BG_BLUE}Q${NOFORMAT} ${YELLOW}absolute paths${NOFORMAT} detected ... how to proceed? \n  e <=> exit script \n  i <=> ignore, append * for all \n  w <=> workaround, append * for all\n"
            echo -e "  -> location: ${1}\n"
            echo -e "  -> preview: sed -i -e 's#/usr#../#g' ${1}\n\n"
            read -p "${BG_BLUE}>${NOFORMAT} " answer
            if [ "$answer" == "e" ]; then
                exit 0
            elif [ "$answer" == "i" ]; then
                break
            elif [ "$answer" == "i*" ]; then
                SKIP_WORKAROUND_QUESTION=yes
                break
            elif [ "$answer" == "w" ]; then
                sed -i -e 's#/usr#../#g' $1
                break
            elif [ "$answer" == "w*" ]; then
                ALWAYS_WORKAROUND=yes
                break
            else
                clear -x
                echo "input must be: e, i or i*, w or w* (* = for all further questions)"
            fi
        done
        if [ "$ALWAYS_WORKAROUND" == "yes" ] ; then
            sed -i -e 's#/usr#././#g' $1
        fi
    fi
}

set_rpaths() {
    clear -x
    while [ "$ALWAYS_SET_RPATH_TO_ORIGIN" == "no" ]; do
        echo -e "${BG_BLUE}Q${NOFORMAT} do you wish to set ${CYAN}rpath${NOFORMAT} for ${CYAN}${1}${NOFORMAT} ?\n  e <=> exit script \n  n <=> no, append * for all \n  y <=> yes, append * for all\n"
        echo -e "  -> preview: patchelf --force-rpath --set-rpath \$ORIGIN ${1}\n"
        read -p "${BG_BLUE}>${NOFORMAT} " answer
        if [ "$answer" == "e" ]; then
            exit 0
        elif [ "$answer" == "n" ]; then
            break
        elif [ "$answer" == "n*" ]; then
            SKIP_RPATH_QUESTION=yes
            break
        elif [ "$answer" == "y" ]; then
            patchelf --force-rpath --set-rpath $LIBRARY_RPATH $1
            break
        elif [ "$answer" == "y*" ]; then
            ALWAYS_SET_RPATH_TO_ORIGIN=yes
            break
        else
            clear -x
            echo "input must be: e, n or n*, y or y* (* = for all further questions)"
        fi
    done
    if [ "$ALWAYS_SET_RPATH_TO_ORIGIN" == "yes" ] ; then
        patchelf --force-rpath --set-rpath $LIBRARY_RPATH $1
    fi
}

set_rpath_binary() {
    while [ "$ALWAYS_SET_RPATH_TO_ORIGIN" == "no" ]; do
        echo -e "${BG_BLUE}Q${NOFORMAT} do you wish to set ${CYAN}rpath${NOFORMAT} for the ${CYAN}target binary${NOFORMAT} ?\n  e <=> exit script \n  n <=> no, append * for all \n  y <=> yes, append * for all\n"
        echo -e "  -> preview: patchelf --force-rpath --set-rpath \$ORIGIN/../lib ${TARGET_BINARY}\n"
        read -p "${BG_BLUE}>${NOFORMAT} " answer
        if [ "$answer" == "e" ]; then
            exit 0
        elif [ "$answer" == "n" ]; then
            break
        elif [ "$answer" == "n*" ]; then
            SKIP_RPATH_QUESTION=yes
            break
        elif [ "$answer" == "y" ]; then
            patchelf --force-rpath --set-rpath $BINARY_RPATH $TARGET_BINARY
            break
        elif [ "$answer" == "y*" ]; then
            ALWAYS_SET_RPATH_TO_ORIGIN=yes
            break
        else
            clear -x
            echo "input must be: e, n or n*, y or y* (* = for all further questions)"
        fi
    done
    if [ "$ALWAYS_SET_RPATH_TO_ORIGIN" == "yes" ] ; then
        patchelf --force-rpath --set-rpath $BINARY_RPATH $TARGET_BINARY
    fi
}

show_help_message() {
    if [ "$1" == "refresh" ]; then
        clear -x
    fi
    echo "./create_motiv_image_via_appimagetool.sh <${CYAN}motiv *binary* location${NOFORMAT}>"
    echo "-> e.g. ./create_motiv_image_via_appimagetool.sh ~/motiv/build/motiv"
    echo "-> ${CYAN}patchelf${NOFORMAT} is requiered for rpath manipulation"
    exit 0
}


# just to be sure that our .sh and .AppImage tools are executable
$WORK_LOCATION/../aux_scripts/make_scripts_and_appimages_executable.sh

# error checks & information
if [ "$1" == "-h" ]; then
    show_help_message refresh
elif [ "$#" -eq 1 ]; then
    MOTIV_INSTALL_BINARY=$1
    if ! command -v patchelf &> /dev/null; then   
        echo "${YELLOW}warning${NOFORMAT}: ${CYAN}patchelf${NOFORMAT} is ${UNDERLINE}not${NOFORMAT} available !"
        echo "-> requiered for rpath manipulation"
        read -p "press ${CYAN}any letter${NOFORMAT} to resume the script ... " confirmation
    fi
elif [ "$#" -gt 1 ]; then
    echo "${RED}error${NOFORMAT}: to many arguments! see -h down below"
    show_help_message
    exit 1
else
    echo "${RED}error${NOFORMAT}: not enough arguments! see -h down below"
    show_help_message
    exit 1
fi

# get template dir
if [ -f $APPDIR_TEMPLATE_ARCHIVE ]; then
    tar -xf $APPDIR_TEMPLATE_ARCHIVE -C $WORK_LOCATION/
else
    echo "${RED}error${NOFORMAT}: can't find dir-template (${APPDIR_TEMPLATE_ARCHIVE})"
    exit 1
fi

# we copy the binary from the install dir to our workdir
if [ -f $MOTIV_INSTALL_BINARY ]; then
    cp $MOTIV_INSTALL_BINARY $TARGET_BINARY_DIR
    # these two things have to be executable
    chmod a+x $APPDIR_PATH/AppRun
    chmod a+x $TARGET_BINARY
else
    echo "${RED}error${NOFORMAT}: can't find motiv binary in install dir"
    exit 1
fi

# we may use a script for linuxdeploy, to prepare the dependencies (/usr/lib)
clear -x
while true; do
    if [ -f $LINUXDEPLOY_SCRIPT_PATH ] ; then
        echo -e "${BG_BLUE}Q${NOFORMAT} do you wish to use ${CYAN}linuxdeploy${NOFORMAT} ?\n  e <=> exit script \n  n <=> no \n  c <=> no, copy the found depencies raw (ELF-header, env.variables have to be adjusted!) \n y <=> yes \n  qt <=> yes, including qt plugin \n"
        read -p "input: " answer
        if [ "$answer" == "e" ]; then
            exit 0
        elif [ "$answer" == "n" ]; then
            break
        elif [ "$answer" == "c" ]; then
            copy_dialogue
            break
        elif [ "$answer" == "y" ]; then
            $LINUXDEPLOY_SCRIPT_PATH $MOTIV_INSTALL_BINARY $LIST_SCRIPT_MODE
            break
        elif [ "$answer" == "qt" ]; then
            $LINUXDEPLOY_SCRIPT_PATH $MOTIV_INSTALL_BINARY $LIST_SCRIPT_MODE "--plugin qt"
            break
        else
            clear -x
            echo "input must be: e, n, y, qt"
        fi
    fi	
done

# check for absolute paths (bin)
if [ "$SKIP_WORKAROUND_QUESTION" == "no" ]; then
    check_paths $APPDIR_PATH/usr/bin/$BINARY_NAME
fi

# set rpath
clear -x
set_rpath_binary

# check for absolute paths (dependencies in lib)
# and only do that, when the lib dir is non empty (ignoring . and ..)
# otherwise $TARGET_LIB/* evaluates literally
if [ "$(ls -A "$TARGET_LIB" | wc -l)" -gt 0 ]; then
    for dep in $TARGET_LIB/*; do
        if [ "$SKIP_WORKAROUND_QUESTION" == "no" ]; then
            check_paths $dep
        fi
        # set rpath (all shared objects are in usr/lib)
        if [ "$SKIP_RPATH_QUESTION" == "no" ]; then
            set_rpaths $dep
        fi
    done
fi



# create appimage: e.g. .../appimagetool-x86_64.AppImage [SRC] [DEST]
$APPIMAGETOOL_PATH $APPDIR_PATH $APPIMAGE_PATH

# final clean up question
clear -x
while true; do
    if [ -f $APPIMAGE_PATH ]; then
        echo -e "${BG_BLUE}Q${NOFORMAT} ${CYAN}clean up${NOFORMAT} the ressources the AppImage was generated from ?\n  n <=> no \n  y <=> yes \n"
        echo "preview:  rm -r ${APPDIR_PATH}"
        echo "preview:  rm -f ${LDEPLOY_LIST}"
        echo "preview:  rm -f ${LDEPLOY_LIST_W}"
        read -p "${BG_BLUE}>${NOFORMAT} " answer
        if [ "$answer" == "n" ]; then
            break
        elif [ "$answer" == "y" ]; then
            rm -r $APPDIR_PATH
            rm -f $LDEPLOY_LIST
            rm -f $LDEPLOY_LIST_W
            break
        else
            clear -x
            echo "input must be: n or y"
        fi
    else	
        echo "${RED}error${NOFORMAT}: something went wrong, no AppImage generated!"
        exit 1
    fi
done

chmod a+x $APPIMAGE_PATH
clear -x
echo "**************************************"
echo "*** AppImage generation complete ! ***"
echo "**************************************"
exit 0