#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

# Parameter support to specify version of the CLI to install.
export HOLLAEX_INSTALLER_VERSION_TARGET=${1:-"master"}

/bin/cat << EOF


:tt1   ;tti          LCC:1CC1         ,11tffttt            :tt;  ;tfi.tt1 ,,,
t@@8   f@@0  ,;ii;.  8@@;L@@f .:i1i:. ;@@@CLCGC;ii; ,iii.  t@@L,C@@L,.CCf,0@@;,
t@@8LLf0@@G,C@@G0@8L.0@@;L@@t.C80L0@8i:@@8tt;  :8@@1G@@1.  t@@0@@8:  ,8888@@@8G
t@@8CCC0@@CC@@L  G@@fG@@;L@@t,fCCfG@@L:@@@LLi    C@@@8,    t@@@C8@0: ,@@G.G@@,
t@@8   L@@G1@@0;;8@@i0@@;L@@fC@@Li0@@f:@@@iii11:i8@G@@C,   t@@L :0@@1,@@0 G@@1;
iGGL   tGGf ;LG00Gf: CGG:tGG1:LGGCLCG1:GGG0000fiGGL 1GGf.  iCC1  .LGG1CGf :LG0G,


EOF

echo "#### HollaEx CLI Installer ####"

if [[ -d "$HOME/.hollaex-cli" ]] || [[ -d "$HOME/.hollaex-cli" ]]; then
    printf "\n\033[93mYou already installed previous version of HollaEx CLI.\033[39m\n"
    REPLACE_EXISTING_TO_LATEST=true
fi

if [[ "$REPLACE_EXISTING_TO_LATEST" == "true" ]]; then
    printf "\n\033[93mReplacing existing HollaEx CLI to latest...\033[39m\n\n"
    sudo rm -r $HOME/.hollaex-cli
    sudo rm /usr/local/bin/hollaex
fi 

echo "Cloning HollaEx CLI repo from git..."
git clone https://github.com/hollaex/hollaex-cli.git -b $HOLLAEX_INSTALLER_VERSION_TARGET


chmod +x $(pwd)/hollaex-cli
sudo mv $(pwd)/hollaex-cli $HOME/.hollaex-cli
sudo ln -s $HOME/.hollaex-cli/hollaex /usr/local/bin/hollaex

if [[ -d $HOME/.hollaex-cli ]] && [[ -f /usr/local/bin/hollaex ]]; then

    printf "\n\033[92mHollaEx CLI v$(cat $HOME/.hollaex-cli/version) has been successfully installed!\033[39m\n"

    if [[ "$REPLACE_EXISTING_TO_LATEST" == false ]]; then
        echo "Start configuring your exchange with the command: 'hollaex setup'."
        echo "To see the full list of commands, use 'hollaex help'."
    fi  

else 

    printf "\n\033[91mFailed to install HollaEx CLI!\033[39m\n"
    echo "Please check the logs above and try again."

fi