#!/bin/bash
                                                                                                  #
SCRIPT_LOCATION=$(realpath "$0")                                                                  #
WORK_LOCATION=$(dirname "$SCRIPT_LOCATION")                                                       #
                                                                                                  #
APP_DIR_LOCATION=$WORK_LOCATION/AppDir                                                            #
mkdir -p $APP_DIR_LOCATION                                                                        #
# dev repo: https://github.com/Azera5/motiv                                                       #
# dev branch: main+Prototype                                                                      #
# primary repo: https://github.com/parcio/motiv                                                   #
# primary branch: main                                                                            #
GIT_REPO=https://github.com/parcio/motiv                                                          #
BRANCH=main                                                                                       #
                                                                                                  #
# source code & ressources                                                                        #
# is our first argument, e.g. ~/motiv                                                             #
MOTIV_PATH=not-set-yet                                                                            #
                                                                                                  #
# if there's an *unrelated* installment, we can analyze it and suggest dependencies               #
# is our second argument                                                                          #
# most of the time it's .../build/motiv or .../bin/motiv                                          #
BIN_ANALYZE_PATH=not-set-yet                                                                      #
                                                                                                  #
# list-utility, used for dependency suggestions                                                   #
LIST_SCRIPT=$WORK_LOCATION/list_dependencies.sh                                                   #
                                                                                                  #
# local deps path                                                                                 #
# otf2-3.0.3.tar.gz                                                                               #
OTF2_PATH=$WORK_LOCATION/../aux_files/otf2-3.0.3.tar.gz                                           #
                                                                                                  #
###################################################################################################


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


list_dialogue() {
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
                echo " "
                $LIST_SCRIPT $BIN_ANALYZE_PATH $LIST_SCRIPT_MODE "    - "
                break
            else
                clear -x
                echo "please try again"
            fi
        else	
            clear -x
            echo "${RED}error${NOFORMAT}: can't find list utility, expected in -> $LIST_SCRIPT"
            exit 1
        fi
    done
}

show_help_message() {
    if [ "$1" == "refresh" ]; then
        clear -x
    fi
    echo "./guided_motiv_image_creation_via_appimage-builder.sh <${CYAN}motiv *source* location${NOFORMAT}> <${CYAN}dir to the motiv binary${NOFORMAT}>"
    echo "-> e.g. ./guided_motiv_image_creation_via_appimage-builder.sh ~/motiv ~/motiv/build/motiv"
    echo "-> the two arguments can have a different base! e.g. we cloned to ~/Downloads/motiv but installed to /usr/local/bin/motiv"
    echo "-> why *two* paths? the first is used for another installation into ${APP_DIR_LOCATION}, the second one is used to analyze dependencies"
    echo -e "\nalternative:\n"
    echo "./guided_motiv_image_creation_via_appimage-builder.sh ${CYAN}-a${NOFORMAT}"
    echo "-> this will (automatically) clone & install into /tmp/motiv_tmp"
    echo -e "\ntests:\n"
    echo "-> depending on the recipe (wether a test section is definied or not), we might have to pull docker images"
    echo "-> if docker isn't installed:"
    echo "   sudo apt-get install docker.io"
    echo "   sudo groupadd docker"
    echo "   sudo usermod -aG docker $USER"
    echo "-> a restart might be necessary, https://appimage-builder.readthedocs.io/en/latest/intro/tutorial.html see for more details"
    exit 0
}

install() {
    cd $MOTIV_PATH
    git submodule update --init --recursive

    # we use the tutorial-instructions for appimage-builder
    cmake . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
    make
    make install DESTDIR=$APP_DIR_LOCATION
}


if [ ! -d $1 ] && [ "$1" != "-a" ]; then
    clear -x
    echo "${RED}error${NOFORMAT}: can't find the motiv source dir!"
    echo "expected path -> ${MOTIV_PATH}"
    echo "clone & retry -> git clone -b ${BRANCH} ${GIT_REPO}"
    exit 1
fi

# error checks & information
if [ "$1" == "-h" ]; then
    show_help_message refresh
elif [ "$1" == "-a" ]; then
    MOTIV_PATH=$WORK_LOCATION/tmp_source/motiv
    BIN_ANALYZE_PATH=$WORK_LOCATION/AppDir/usr/bin/motiv
    #BIN_ANALYZE_PATH=$WORK_LOCATION/tmp_source/motiv/build/motiv
elif [ "$#" -eq 2 ]; then
    MOTIV_PATH=$1
    BIN_ANALYZE_PATH=$2
elif [ "$#" -gt 2 ]; then
    echo "${RED}error${NOFORMAT}: to many arguments! see -h down below"
    show_help_message
    exit 1
else
    echo "${RED}error${NOFORMAT}: too few arguments! see -h down below"
    show_help_message
    exit 1
fi



# just to be sure that our .sh and .AppImage tools are executable
$WORK_LOCATION/../aux_scripts/make_scripts_and_appimages_executable.sh

apt_available=false
pacman_available=false
zypper_available=false

# what kind of package manager do we have?
if command -v apt &> /dev/null; then   
    echo "apt available ..."
	apt_available=true
elif command -v pacman &> /dev/null; then
    echo "pacman available ..."
	pacman_available=true
elif command -v zypper &> /dev/null; then
    echo "zypper available ..."
	zypper_available=true
else
    clear -x
    echo "${RED}error${NOFORMAT}: nothing available!"
	exit 1
fi

# general dependencies
if [ "$apt_available" = true ] && [ "$pacman_available" = false ] && [ "$zypper_available" = false ]; then
    sudo apt update
    sudo apt upgrade
	sudo apt-get install -y build-essential git cmake qt6-base-dev freeglut3-dev
elif [ "$apt_available" = false ] && [ "$pacman_available" = true ] && [ "$zypper_available" = false ]; then
    sudo pacman -Syu
    sudo pacman -S --noconfirm gcc gcc-libs make cmake git qt6-base freeglut
elif [ "$apt_available" = false ] && [ "$pacman_available" = false ] && [ "$zypper_available" = true ]; then
    sudo zypper refresh
    sudo zypper update
    sudo zypper --non-interactive install gcc gcc-c++ gcc-fortran cmake-full git-core qtutilities-qt6 freeglut
else
    clear -x
    echo "${RED}error${NOFORMAT}: multiple available!"
	exit 1	
fi

# otf2 dependency
if [ ! -d /opt/otf2 ]; then
    clear -x
    echo "can't find otf2, installing ..."
    # otf2 install if needed
    if [ -f $OTF2_PATH ]; then
        tar -xf $OTF2_PATH -C /tmp/
        cd /tmp/otf2-3.0.3
        ./configure
        make
        sudo make install
    else
        clear -x
        echo "${RED}error${NOFORMAT}: can't find local otf2 sources, expected in ${WORK_LOCATION}/../aux_files/otf2-3.0.3.tar.gz"
        exit 1
    fi
fi

clear -x
echo "*************************************"
echo "*** manual preparation complete ! ***"
echo "*************************************"
sleep 1

# potential installation via -a, we have to first clone the sources
if [ "$MOTIV_PATH" == "${WORK_LOCATION}/tmp_source/motiv" ]; then
    # create parent dir: tmp_source
    parent_dir_path=$(dirname "$MOTIV_PATH")
    mkdir -p $parent_dir_path
    cd $parent_dir_path
    git clone -b $BRANCH $GIT_REPO
    sleep 1
    # AppDir installation
    install
else
    # AppDir installation, if a source dir is given via CLI
    install
fi



clear -x
if [ -f $APP_DIR_LOCATION/usr/bin/motiv ]; then   
    echo "********************************************"
    echo "*** motiv AppDir installation complete ! ***"
    echo "********************************************"
    sleep 1
else
    clear -x
    echo "${RED}error${NOFORMAT}: something went wrong..."
    exit 1
fi

cd $WORK_LOCATION


# recipe generation, only if no recipe is found
clear -x
if [ ! -f $WORK_LOCATION/AppImageBuilder.yml ]; then
    while true; do
        echo -e "${BG_BLUE}Q${NOFORMAT} do you wish to generate a ${CYAN}.yaml recipe${NOFORMAT} ?\n  n <=> no \n  y <=> yes \n"
        echo -e "  -> recommendation: check for arg-count, motiv has flags, so \$1 doesn't fit!\n"
        read -p "${BG_BLUE}>${NOFORMAT} " answer
        if [ "$answer" == "y" ]; then
            $WORK_LOCATION/appimage-builder-x86_64.AppImage --generate
            break
        elif [ "$answer" == "n" ]; then
            break
        else
            clear -x
            echo "input must be: n/y"
        fi
    done
else
    "${YELLOW}attention${NOFORMAT}: an already ${CYAN}existing recipe${NOFORMAT} was detected, please check wether motiv version, dependencies etc. have changed!"
fi


# image generation
clear -x
while true; do
    echo -e "${BG_BLUE}Q${NOFORMAT} do you wish to generate an ${CYAN}AppImage${NOFORMAT} ?\n  n <=> no \n  y <=> yes \n  y+s <=> yes, also skip defined docker tests \n  s <=> print ${CYAN}suggestions${NOFORMAT} and ask again \n"
    echo -e "  -> recommendation: check/customize ${CYAN}.yaml recipe${NOFORMAT} ${UNDERLINE}before${NOFORMAT} image creation;\n  try s for possible dependencies\n"
    read -p "${BG_BLUE}>${NOFORMAT} " answer
    if [ "$answer" == "y" ]; then
        $WORK_LOCATION/appimage-builder-x86_64.AppImage --recipe AppImageBuilder.yml
        break
    elif [ "$answer" == "y+s" ]; then
        $WORK_LOCATION/appimage-builder-x86_64.AppImage --skip-test --recipe AppImageBuilder.yml
        break
    elif [ "$answer" == "n" ]; then
        break
    elif [ "$answer" == "s" ]; then
        if [ -f $BIN_ANALYZE_PATH ]; then
            list_dialogue
        else
            echo -e "${RED}error${NOFORMAT}: ${BIN_ANALYZE_PATH} is not a file,\n in order to suggest any dependencies we need an unrelated, runable installment!\n"
        fi
    else
        clear -x
        echo "input must be: n,y or s"
    fi
done

# final clean up question
clear -x
while true; do
    if [ -d $APP_DIR_LOCATION ]; then
        echo -e "${BG_BLUE}Q${NOFORMAT} ${CYAN}clean up${NOFORMAT} the ressources the AppImage was generated from ?\n  n <=> no \n  y <=> yes \n  y+r <=> yes, even the recipe \n"
        echo -e "  -> preview: rm -r ${APP_DIR_LOCATION}\n"
        if [ -d $WORK_LOCATION/tmp_source ]; then
            echo -e "  -> preview: rm -r ${WORK_LOCATION}/tmp_source\n"
        fi
        echo -e "  -> preview: rm -f ${WORK_LOCATION}/AppImageBuilder.yml (if +r)\n"
        read -p "${BG_BLUE}>${NOFORMAT} " answer
        if [ "$answer" == "n" ]; then
            break
        elif [ "$answer" == "y" ]; then
            rm -r $APP_DIR_LOCATION
            if [ -d $WORK_LOCATION/tmp_source ]; then
                rm -r $WORK_LOCATION/tmp_source
            fi
            break
        elif [ "$answer" == "y+r" ]; then
            rm -r $APP_DIR_LOCATION
            if [ -d $WORK_LOCATION/tmp_source ]; then
                rm -r $WORK_LOCATION/tmp_source
            fi
            rm -f $WORK_LOCATION/AppImageBuilder.yml
            break
        else
            clear -x
            echo "input must be: n, y or y+r"
        fi
    else	
        echo "${RED}error${NOFORMAT}: something went wrong, no AppDir found!"
        exit 1
    fi
done

# we expect that there's now an .AppImage file namend like Motiv*some arch and version specification*.AppImage
clear -x
if find $WORK_LOCATION -maxdepth 1 -type f -name "Motiv*.AppImage" -print -quit | grep -q $WORK_LOCATION; then
    echo "**************************************"
    echo "*** AppImage generation complete ! ***"
    echo "**************************************"
    exit 0
else
    echo "${RED}error${NOFORMAT}: no Motiv*.AppImage found, something went wrong ..."
    exit 1
fi
