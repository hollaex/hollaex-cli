#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

# Parameter support to specify version of the CLI to install.
export HOLLAEX_INSTALLER_VERSION_TARGET=${1:-"master"}

/bin/cat << EOF

                        ..,,,..
         ,ifGi      .:tLG8@@@@@@0Cfi,
      .iC@@@@1    :f0@@@@@0GGG08@@@@@Ci.
     10@@@0f;.  ,L@@@@C1:.     .,;f0@@@0i
   .C@@@G;     i8@@8t,              iG@@@L
  .G@@@t      i@@@0:                  f@@@C
  t@@@t      ,8@@8,                    f@@@1
 .8@@0       1@@@1                     .8@@0
 ,@@@G       f@@@;                      G@@8.
 .8@@0       1@@@1                     .8@@0
  f@@@t      ,8@@8.                    f@@@t
  .G@@@t      i@@@0,                  t@@@G
   .C@@@C;     i@@@8t,              ;G@@@C.
     18@@@Gt;.  ,C@@@8Li,.      ,;f0@@@0i
      .1G@@@@1    :f8@@@@80GGGG8@@@@@Gi.
         ,ifGi      .;tC08@@@@@@8Cfi,
                         .,,,,,.

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
git clone https://github.com/bitholla/hollaex-cli.git -b $HOLLAEX_INSTALLER_VERSION_TARGET


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