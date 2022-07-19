#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

/bin/cat << EOF


:tt1   ;tti          LCC:1CC1         ,11tffttt            :tt;  ;tfi.tt1 ,,,
t@@8   f@@0  ,;ii;.  8@@;L@@f .:i1i:. ;@@@CLCGC;ii; ,iii.  t@@L,C@@L,.CCf,0@@;,
t@@8LLf0@@G,C@@G0@8L.0@@;L@@t.C80L0@8i:@@8tt;  :8@@1G@@1.  t@@0@@8:  ,8888@@@8G
t@@8CCC0@@CC@@L  G@@fG@@;L@@t,fCCfG@@L:@@@LLi    C@@@8,    t@@@C8@0: ,@@G.G@@,
t@@8   L@@G1@@0;;8@@i0@@;L@@fC@@Li0@@f:@@@iii11:i8@G@@C,   t@@L :0@@1,@@0 G@@1;
iGGL   tGGf ;LG00Gf: CGG:tGG1:LGGCLCG1:GGG0000fiGGL 1GGf.  iCC1  .LGG1CGf :LG0G,
      
                
EOF

echo "#### HollaEx CLI Uninstaller ####"

echo "Uninstalling HollaEx CLI..."

sudo rm /usr/local/bin/hollaex
sudo rm -r $HOME/.hollaex-cli

if [[ -d $HOME/.hollaex-cli ]] && [[ -f /usr/local/bin/hollaex ]]; then

    printf "\n\033[91mFailed to uninstall HollaEx CLI!\033[39m\n"
    echo "Please check the logs above and try again."

else 

   printf "\n\033[92mHollaEx CLI has been successfully removed from your computer.\033[39m\n"
   echo "If you want to reinstall HollaEx CLI, Please visit https://github.com/hollaex/hollaex-cli for further information."

fi