#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

echo "#### HollaEx CLI Uninstaller ####"

echo "Uninstalling HollaEx CLI..."

# Remove old hollaex-cli related files together If it's left on system.
if [[ -d "$HOME/.hollaex-cli" ]]; then
    sudo rm /usr/local/bin/hollaex
    sudo rm -r $HOME/.hollaex-cli
fi

sudo rm /usr/local/bin/hollaex
sudo rm -r $HOME/.hollaex-cli

echo "HollaEx CLI has been successfully removed from your computer."
echo "If you want to reinstall HollaEx CLI, Please visit https://github.com/bitholla/hollaex-cli for further information."