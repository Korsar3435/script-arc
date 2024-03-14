#!/bin/bash
                                                             #
SCRIPT_LOCATION=$(realpath "$0")                             #
WORK_LOCATION=$(dirname "$SCRIPT_LOCATION")                  #
                                                             #
# that's the default value (<=> spack install motiv)         #
# the first arg. overwrites this! see -h                     #
SPEC_FLAG=motiv                                              #
                                                             #
# default spack location, that the second, optional arg      #
SPACK_LOCATION=~/spack                                       #
SPACK_PARENT_DIR=$(dirname "$SPACK_LOCATION")                #
                                                             #
##############################################################

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

set_env_var() {
    export CC=$(which gcc)
    export CXX=$(which g++)
    export FC=$(which gfortran)
}

setup_apt() {
    #update & upgrade
    sudo apt update
    sudo apt upgrade
    sudo apt-get -y install build-essential gfortran coreutils

    set_env_var

    sudo apt-get -y install ca-certificates curl environment-modules git gpg lsb-release python3 python3-distutils python3-venv unzip zip cmake patch
}

setup_pacman() {
    #update & upgrade
    sudo pacman -Syu

    sudo pacman -S --noconfirm gcc gcc-libs

    set_env_var

    sudo pacman -S --noconfirm tar xz ca-certificates coreutils curl tcl git gnupg lsb-release python unzip gzip cmake patch
}

setup_zypper() {
    #update & upgrade
    sudo zypper refresh
    sudo zypper update

    sudo zypper --non-interactive install gcc gcc-c++ gcc-fortran

    set_env_var

    sudo zypper --non-interactive install tar xz ca-certificates coreutils curl Modules git-core gpg2 lsb-release python311-base python311-distutils-extra python3-pylint-venv unzip gzip cmake-full patch
}

clone_spack() {
    cd $SPACK_PARENT_DIR
    git clone -c feature.manyFiles=true https://github.com/spack/spack.git

    . $SPACK_LOCATION/share/spack/setup-env.sh
    spack compiler find
}

add_customrep() {
    . $SPACK_LOCATION/share/spack/setup-env.sh

    if [ ! -d $SPACK_LOCATION/var/spack/repos/customrep ]; then
        tar -xf $WORK_LOCATION/aux_files/customrep.tar.gz -C $SPACK_LOCATION/var/spack/repos/
    fi
    spack repo add $SPACK_LOCATION/var/spack/repos/customrep
}

prepare_spack_dependencies() {
    local apt_available=false
    local pacman_available=false
    local zypper_available=false

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
        echo "setup spack dependencies via apt"
        setup_apt
    elif [ "$apt_available" = false ] && [ "$pacman_available" = true ] && [ "$zypper_available" = false ]; then
        echo "setup spack dependencies via pacman"
        setup_pacman
    elif [ "$apt_available" = false ] && [ "$pacman_available" = false ] && [ "$zypper_available" = true ]; then
        echo "setup spack dependencies via zypper"
        setup_zypper
    else
        clear -x
        echo "${RED}error${NOFORMAT}: multiple available!"
    	exit 1	
    fi

    echo "********************************************"
    echo "*** dep preparation for spack complete ! ***"
    echo "********************************************"
    sleep 2
}

clone_spack_dialogue() {
    clear -x
    while true; do
        echo -e "${BG_BLUE}Q${NOFORMAT} do you wish to clone ${CYAN}spack${NOFORMAT} ?\n  n <=> no \n  y <=> yes \n"
        echo -e "  -> preview: git clone -c feature.manyFiles=true https://github.com/spack/spack.git\n"
        echo -e "  -> location: ${SPACK_PARENT_DIR}"
        read -p "${BG_BLUE}>${NOFORMAT} " answer
        if [ "$answer" == "y" ] ; then
            clone_spack
            break
        elif [ "$answer" == "n" ] ; then
            break
        else
            clear -x
            echo "input must be: n/y"
        fi
    done
}

add_customrep_dialogue() {
    clear -x
    while true; do
        echo -e "${BG_BLUE}Q${NOFORMAT} do you wish to extract ${CYAN}customrep${NOFORMAT} and add it ?\n  n <=> no \n  y <=> yes \n"
        echo -e "  -> preview: tar -xf ${WORK_LOCATION}/aux_files/customrep -C ${SPACK_LOCATION}/var/spack/repos/\n"
        read -p "${BG_BLUE}>${NOFORMAT} " answer
        if [ "$answer" == "y" ] ; then
            add_customrep
            break
        elif [ "$answer" == "n" ] ; then
            break
        else
            clear -x
            echo "input must be: n/y"
        fi
    done
}

show_help_message() {
    if [ "$1" == "refresh" ]; then
        clear -x
    fi
    echo "./spack_motiv_installation <${CYAN}spec${NOFORMAT}> <${CYAN}optional path to spack${NOFORMAT}>"
    echo "-> e.g. ./spack_motiv_installation.sh motiv+stats@dev /home/<some user>/Documents/spack <=> spack install motiv+stats@dev"
    echo "-> default path to spack: ${SPACK_LOCATION}, if the default or given path doesn't exist a dialogue will ask wether to clone spack to this location or not"
    exit 0
}


# error checks & information
if [ "$1" == "-h" ]; then
    show_help_message refresh
elif [ "$#" -eq 1 ]; then
    SPEC_FLAG=$1
elif [ "$#" -eq 2 ]; then
    SPEC_FLAG=$1
    SPACK_LOCATION=$2
    SPACK_PARENT_DIR=$(dirname "$SPACK_LOCATION")
elif [ "$#" -gt 2 ]; then
    echo "${RED}error${NOFORMAT}: to many arguments! see -h down below"
    show_help_message
    exit 1
else
    echo "${RED}error${NOFORMAT}: not enough arguments! see -h down below"
    show_help_message
    exit 1
fi


# is spack prepared?
if [ ! -d $SPACK_LOCATION ]; then
    prepare_spack_dependencies
    clone_spack_dialogue
fi

# do we want to use a custom repo?
if [ -d $SPACK_LOCATION/var/spack/repos ]; then
    add_customrep_dialogue
fi

echo "*********************"
echo "*** spack ready ! ***"
echo "*********************"
sleep 1


set_env_var

sleep 1
echo "installing in 3 ..."
sleep 1
echo "installing in 2 ..."
sleep 1
echo "installing in 1 ..."
sleep 1

. $SPACK_LOCATION/share/spack/setup-env.sh
spack compiler find

spack install $SPEC_FLAG

echo "motiv now usable with:"
echo ". ${SPACK_LOCATION}/share/spack/setup-env.sh"
echo "spack load ${SPEC_FLAG}"

echo "*******************************"
echo "*** installation complete ! ***"
echo "*******************************"