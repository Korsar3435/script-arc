#!/bin/bash
                                                                    #
SCRIPT_LOCATION=$(realpath "$0")                                    #
WORK_LOCATION=$(dirname "$SCRIPT_LOCATION")                         #
                                                                    #
SHELLRC_PATH=/home/$(whoami)/.bashrc                                #
                                                                    #
# set via arguments                                                 #
CLONE_LOCATION=not-set-yet                                          #
INSTALL_LOCATION=not-set-yet                                        #
                                                                    #
# dev repo: https://github.com/Azera5/motiv                         #
# dev branch: main+Prototype                                        #
# set via arguments                                                 #
GIT_REPO=https://github.com/parcio/motiv                            #
BRANCH=main                                                         #
                                                                    #
# local deps path                                                   #
# otf2-3.0.3.tar.gz                                                 #
OTF2_PATH=$WORK_LOCATION/aux_files/otf2-3.0.3.tar.gz                #
                                                                    #
#####################################################################


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


setup_motiv_deps_via_apt() {
    #update & upgrade
    sudo apt update
    sudo apt upgrade

    sudo apt-get install -y build-essential git cmake qt6-base-dev freeglut3-dev
}

setup_motiv_deps_via_pacman() {
    #update & upgrade
    sudo pacman -Syu
	
    sudo pacman -S --noconfirm gcc gcc-libs make cmake git qt6-base freeglut
}

setup_motiv_deps_via_zypper() {
    #update & upgrade
    sudo zypper refresh
    sudo zypper update

    sudo zypper --non-interactive install gcc gcc-c++ gcc-fortran cmake-full git-core qtutilities-qt6 freeglut
}

check_for_install_success() {
    local expected_bin_path=$1
    if [ -f $expected_bin_path ]; then   
        echo "*************************************"
        echo "*** motiv installation complete ! ***"
        echo "*************************************"
        sleep 1
        exit 0
    else
        echo "something went wrong..."
        exit 1
    fi
}

path_var_dialogue() {
    local expected_bin_path=$1
    if [ -f $SHELLRC_PATH ]; then
        clear -x
        while true; do
            echo "${BG_BLUE}Q${NOFORMAT} do you wish to add ${CYAN}${expected_bin_path}${NOFORMAT} to ${CYAN}\$PATH${NOFORMAT} ? (y/n)"
            echo "  -> preview: export PATH=${expected_bin_path}:\$PATH; $(echo "export PATH=${expected_bin_path}:\$PATH") >> $SHELLRC_PATH"
            echo "  -> hint: that's not necessary for install locations like /usr/local"
            read -p "${BG_BLUE}>${NOFORMAT} " answer
            if [ "$answer" == "y" ]; then
                export PATH=$expected_bin_path:$PATH 
                echo "export PATH=${expected_bin_path}:\$PATH" >> $SHELLRC_PATH
                break
            elif [ "$answer" == "n" ]; then
                break
            else
                clear -x
                echo "input must be: y or n"
            fi
        done
    else
        echo "${YELLOW}warning${NOFORMAT}: can't find /home/$(whoami)/${SHELLRC_PATH}, SHELLRC_PATH variable can be adjustet in ${SCRIPT_LOCATION}"
    fi
}

show_help_message() {
    if [ "$1" == "refresh" ]; then
        clear -x
    fi
    echo "./regular_motiv_installation.sh <${CYAN}clone location${NOFORMAT}> <${CYAN}optional git repo${NOFORMAT}> <${CYAN}optional branch${NOFORMAT}> <${CYAN}optional install location${NOFORMAT}>"
    echo "-> e.g. ./regular_motiv_installation.sh ~/Downloads/motiv https://github.com/Azera5/motiv main+Prototype /usr/local"
    exit 0
}

clean_up_clone_dir_dialogue() {
    clear -x
    while true; do
        echo "${BG_BLUE}Q${NOFORMAT} do you wish to ${CYAN}remove${NOFORMAT} the cloned ${CYAN}source dir${NOFORMAT} ? (y/n)"
        echo "  -> preview: sudo rm -f -r ${CLONE_LOCATION}"
        read -p "${BG_BLUE}>${NOFORMAT} " answer
        if [ "$answer" == "y" ]; then
            sudo rm -f -r $CLONE_LOCATION
            break
        elif [ "$answer" == "n" ]; then
            break
        else
            clear -x
            echo "input must be: y or n"
        fi
    done
}



# error checks & information
if [ "$1" == "-h" ]; then
    show_help_message refresh
elif [ "$#" -eq 1 ]; then
    CLONE_LOCATION=$1
    INSTALL_LOCATION=$1
elif [ "$#" -eq 2 ]; then
    CLONE_LOCATION=$1
    INSTALL_LOCATION=$1
    GIT_REPO=$2
elif [ "$#" -eq 3 ]; then
    CLONE_LOCATION=$1
    INSTALL_LOCATION=$1
    GIT_REPO=$2
    BRANCH=$3
elif [ "$#" -eq 4 ]; then
    CLONE_LOCATION=$1
    INSTALL_LOCATION=$4
    GIT_REPO=$2
    BRANCH=$3
elif [ "$#" -gt 4 ]; then
    echo "${RED}error${NOFORMAT}: to many arguments! see -h down below"
    show_help_message
    exit 1
else
    echo "${RED}error${NOFORMAT}: not enough arguments! see -h down below"
    show_help_message
    exit 1
fi


cd ~

apt_available=false
pacman_available=false
zypper_available=false

# what kind of package manager do we have?
if command -v apt &> /dev/null; then   
    echo "apt available"
	apt_available=true
elif command -v pacman &> /dev/null; then
    echo "pacman available"
	pacman_available=true
elif command -v zypper &> /dev/null; then
    echo "zypper available"
	zypper_available=true
else
    echo "nothing available!"
	exit 1
fi

# general dependencies
if [ "$apt_available" = true ] && [ "$pacman_available" = false ] && [ "$zypper_available" = false ]; then
    setup_motiv_deps_via_apt
elif [ "$apt_available" = false ] && [ "$pacman_available" = true ] && [ "$zypper_available" = false ]; then
    setup_motiv_deps_via_pacman
elif [ "$apt_available" = false ] && [ "$pacman_available" = false ] && [ "$zypper_available" = true ]; then
    setup_motiv_deps_via_zypper
else
    echo "multiple available!"
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
        echo "${RED}error${NOFORMAT}: can't find local otf2 sources, expected in ${WORK_LOCATION}/aux_files/otf2-3.0.3.tar.gz"
        exit 1
    fi
fi

echo "*************************************"
echo "*** manual preparation complete ! ***"
echo "*************************************"
sleep 1



# installation
export CC=$(which gcc)
export CXX=$(which g++)
export FC=$(which gfortran)

sleep 1
echo "installing in 3 ..."
sleep 1
echo "installing in 2 ..."
sleep 1
echo "installing in 1 ..."
sleep 1

# parent dir
mkdir -p $(dirname "$CLONE_LOCATION")
cd $(dirname "$CLONE_LOCATION")

# clone
git clone -b $BRANCH $GIT_REPO
sleep 1
cd $CLONE_LOCATION
git submodule update --init --recursive

if [ "${CLONE_LOCATION}" == "${INSTALL_LOCATION}" ]; then
    echo "clone & install dir identical ... ${CLONE_LOCATION} == ${INSTALL_LOCATION}"
    # local installation
    # -S . <=> source location (we're in the clone dir!)
    # -B build <=> build into a subdir "build"
    cmake -S . -B build
    cmake --build build
    path_var_dialogue $CLONE_LOCATION/build
    check_for_install_success $CLONE_LOCATION/build/motiv
else
    echo "clone & install dir *not* identical ...  ${CLONE_LOCATION} != ${INSTALL_LOCATION}"
    # custom installation; classical choice: /usr/local
    cmake -S . -B build -DCMAKE_INSTALL_PREFIX=$INSTALL_LOCATION
    cmake --build build
    cmake --install build
    # it makes sense to clean up in this case
    sleep 1
    if [ -d $CLONE_LOCATION ]; then
        clean_up_clone_dir_dialogue
    else    
        echo "${YELLOW}warning${NOFORMAT}: can't clean up! expected clone dir can't be found -> ${CLONE_LOCATION}"
    fi
    path_var_dialogue $INSTALL_LOCATION/bin
    check_for_install_success $INSTALL_LOCATION/bin/motiv
fi