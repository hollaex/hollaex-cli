#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

echo "#### hex-cli Uninstaller ####"

echo "Are you sure you want to uninstall hex-cli from your computer? (y/n)"

read answer

if [ "$answer" != "${answer#[Nn]}" ] ;then
    echo "*** Exiting... ***"
    exit 0;
fi

# Remove old hollaex-cli related files together If it's left on system.
if [[ -d "$HOME/.hollaex-cli" ]]; then
    sudo rm /usr/local/bin/hollaex
    sudo rm -r $HOME/.hollaex-cli
fi

sudo rm /usr/local/bin/hex
sudo rm -r $HOME/.hex-cli

echo "Jobs all done!"
echo "If you want to reinstall hex-cli later, Please visit https://github.com/bitholla/hex-cli for further information."