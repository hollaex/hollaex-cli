#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

echo "#### hollaex-cli Installer ####"

if [ -d "$HOME/.hollaex-cli" ]; then
    echo "You already installed previous version of hollaex-cli."
    echo "Are you sure you want to replace existing one to latest? (y/n)"
    REPLACE_EXISTING_TO_LATEST=true
else
    echo "Are you sure you want to proceed to install hollaex-cli? (y/n)"
fi

read answer

if [ "$answer" != "${answer#[Nn]}" ] ;then
    echo "*** Exiting... ***"
    exit 0;
fi

if [ "$REPLACE_EXISTING_TO_LATEST" == "true" ]; then
    echo "Replacing existing hollaex-cli to latest"
    sudo rm -r $HOME/.hollaex-cli
    sudo rm /usr/local/bin/hollaex
    git clone https://github.com/bitholla/hollaex-cli.git
else       
    echo "Cloning hollaex-cli repo from git"
    git clone https://github.com/bitholla/hollaex-cli.git
fi

chmod +x $(pwd)/hollaex-cli
sudo mv $(pwd)/hollaex-cli $HOME/.hollaex-cli
sudo ln -s $HOME/.hollaex-cli/hollaex /usr/local/bin/hollaex

# ex -sc '2i|SCRIPTPATH=$HOME/.hollaex-cli' -cx $HOME/.hollaex-cli/hollaex
# ex -sc '2i|SCRIPTPATH=$HOME/.hollaex-cli' -cx $HOME/.hollaex-cli/tools_generator.sh

echo "hollaex-cli v$(cat $HOME/.hollaex-cli/version) has been successfully installed!"
echo "If you want to uninstall hollaex-cli later, Please visit https://github.com/bitholla/hollaex-cli for further information."