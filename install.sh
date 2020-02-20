#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

/bin/cat << EOF

1ttffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffttt.
.@@@000000000000000000000000000000000000000000000000000000000000000000@@@,
.0@G                                                                  L@8,
.8@G     fLL:  ;LLt         ;00L:00C         ;LfLCCCC;                C@@,
.8@G    .@@@;  i@@8  :1fti, i@@G;@@0 ,ittti, t@@0ttfL1ttt..ttt,       C@@,
.8@G    .8@@0GG0@@G:0@@LG@@f;@@C;@@0.L00L8@@;1@@0LL.  t@@CC@@1        C@@,
.8@G    .8@@LttC@@GC@@t  8@@f@@C;@@G:LGCtG@@1i@@Gtt    1@@@8:         C@8,
.8@G    .@@@;  i@@0i@@81L@@Ci@@G;@@0f@@G10@@t1@@8ffLL1i8@C0@8;.1t;    C@@,
.8@G     tff,  :fft ,1LCCf; ,ff1,fft.1LCL1ff;:fffLLLf;fff ,fLf,;i:    ;ii.
.0@G
.@@@888888888888888888888888888888888888888888888888888888888888888888880.
1ttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttttt.

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
    git clone https://github.com/bitholla/hollaex-cli.git
else       
    echo "Cloning HollaEx CLI repo from git..."
    git clone https://github.com/bitholla/hollaex-cli.git
fi

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