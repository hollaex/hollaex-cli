#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

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

echo "#### HollaEx CLI Uninstaller ####"

echo "Uninstalling HollaEx CLI..."

sudo rm /usr/local/bin/hollaex
sudo rm -r $HOME/.hollaex-cli

if [[ -d $HOME/.hollaex-cli ]] && [[ -f /usr/local/bin/hollaex ]]; then

    printf "\n\033[91mFailed to uninstall HollaEx CLI!\033[39m\n"
    echo "Please check the logs above and try again."

else 

   printf "\n\033[92mHollaEx CLI has been successfully removed from your computer.\033[39m\n"
   echo "If you want to reinstall HollaEx CLI, Please visit https://github.com/bitholla/hollaex-cli for further information."

fi