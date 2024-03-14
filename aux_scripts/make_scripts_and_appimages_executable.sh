#!/bin/bash

SCRIPT_LOCATION=$(realpath "$0")
WORK_LOCATION=$(dirname "$SCRIPT_LOCATION")

make_executable() {
	local path=$1
    local extention=$2
    
    for file in $path/*.$extention; do
        if [ -f "$file" ]; then
            if [ -x "$file" ]; then
    		    echo "${file} is already executable!"
    		else
		        chmod a+x "$file"
                echo "${file} is now executable!"		
            fi
        fi
    done
}

# we want our shell-scripts executable
make_executable $WORK_LOCATION sh
# and our AppImages
make_executable $WORK_LOCATION AppImage

if [ -d "${WORK_LOCATION}/.." ]; then
    make_executable $WORK_LOCATION/../AppImageSetup sh
    make_executable $WORK_LOCATION/../AppImageSetup AppImage
	make_executable $WORK_LOCATION/.. sh
fi


echo " ... preparation completed!"