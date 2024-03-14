#!/bin/bash

check_command() {
    command -v "$1" >/dev/null 2>&1
}

echo -e "\n\n**** Hardware ****"
echo -e "[CPU]\n"
if check_command lscpu; then
    lscpu
else
    echo "lscpu unavailable"
fi

echo -e "[RAM]\n"
if check_command free; then
    free -h
else
    echo "free unavailable"
fi

echo -e "[GPU]\n"
if check_command lspci; then
    lspci
else
    echo "lspci unavailable"
fi

echo -e "[HDD]\n"
if check_command df; then
    df -h
else
    echo "df unavailable"
fi


echo -e "\n\n**** Software ****"
echo -e "[OS]\n"
if check_command uname; then
    uname -a
else
    echo "uname unavailable"
fi

if [ -f /etc/os-release ]; then
    cat /etc/os-release
else
    echo "/etc/os-release unavailable"
fi

echo -e "[FS]\n"
if check_command df; then
    df -hT | awk '{print $2}' | sort | uniq -c | grep -v "Type"
else
    echo "df unavailable"
fi

echo -e "[DE]\n"
if [ -n "$XDG_CURRENT_DESKTOP" ]; then
    echo $XDG_CURRENT_DESKTOP
else
    echo "$XDG_CURRENT_DESKTOP unavailable"
fi

if [ -n "$XDG_SESSION_TYPE" ]; then
    echo $XDG_SESSION_TYPE
else
    echo "$XDG_SESSION_TYPE unavailable"
fi

echo -e "\n\n**** Misc. ****"

if check_command ip; then
    ip addr
else
    echo "ip unavailable"
fi

if check_command uptime; then
    uptime
else
    echo "uptime unavailable"
fi
echo -e "\n"

echo "$PATH = ${PATH}"
echo -e "\n"
echo "$LD_LIBRARY_PATH = ${LD_LIBRARY_PATH}"
echo -e "\n"