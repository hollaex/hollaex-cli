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