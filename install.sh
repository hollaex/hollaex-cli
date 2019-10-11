#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

/bin/cat << EOF

██╗  ██╗ ██████╗ ██╗     ██╗      █████╗ ███████╗██╗  ██╗  
██║  ██║██╔═══██╗██║     ██║     ██╔══██╗██╔════╝╚██╗██╔╝
███████║██║   ██║██║     ██║     ███████║█████╗   ╚███╔╝ 
██╔══██║██║   ██║██║     ██║     ██╔══██║██╔══╝   ██╔██╗ 
██║  ██║╚██████╔╝███████╗███████╗██║  ██║███████╗██╔╝ ██╗   
╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝  
                                                 ┬┌┐┌┌─┐┌┬┐┌─┐┬  ┬  ┌─┐┬─┐
                                                 ││││└─┐ │ ├─┤│  │  ├┤ ├┬┘
                                                 ┴┘└┘└─┘ ┴ ┴ ┴┴─┘┴─┘└─┘┴└─
                                                 

EOF

echo "#### HollaEx CLi Installer ####"

if [[ -d "$HOME/.hollaex-cli" ]] || [[ -d "$HOME/.hollaex-cli" ]]; then
    echo "You already installed previous version of hollaex-cli."
    REPLACE_EXISTING_TO_LATEST=true
fi

if [[ "$REPLACE_EXISTING_TO_LATEST" == "true" ]]; then
    echo "Replacing existing HollaEx CLI to latest..."
    sudo rm -r $HOME/.hollaex-cli
    sudo rm /usr/local/bin/hollaex
    git clone https://github.com/bitholla/hollaex-cli.git
else       
    echo "Cloning HollaEx CLI repo from git..."
    git clone https://github.com/bitholla/hollaex-cli.git
fi

chmod +x $(pwd)/hollaex-cli
sudo mv $(pwd)/hollaex-cli $HOME/.hollaex-cli
sudo ln -s $HOME/.hollaex-cli/hollaex /usr/local/bin/hollaex

echo "HollaEx CLI v$(cat $HOME/.hollaex-cli/version) has been successfully installed on your computer!"
echo "If you want to uninstall HollaEx CLI, Please visit https://github.com/bitholla/hollaex-cli for further information."