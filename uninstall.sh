#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

echo "#### hollaex-cli Uninstaller ####"

echo "Are you sure you want to uninstall hollaex-cli from your computer? (y/n)"

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

sudo rm /usr/local/bin/hollaex
sudo rm -r $HOME/.hollaex-cli

echo "Jobs all done!"
echo "If you want to reinstall hollaex-cli later, Please visit https://github.com/bitholla/hollaex-cli for further information."