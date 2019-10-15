#!/bin/bash 

REPLACE_EXISTING_TO_LATEST=false

/bin/cat << EOF

             ..     .::,
                   1i.  ;tCGi.   .,,::,.
             ,   10G   f@@G,  .t0@@0fi,.
            1;  t@@;  .@@0.  .G@@G;.   .,,.
           i@:  1@@i  :@@i   C@8i    iC8@@@Gf1:,
       ..  8@C   C@f  ,@0   f@G,   i0@@8Cti::,,,.
       i1  i8@f  .88. :@1  f@t   ;0@8f;.
       t@;  ,L@C  i@, CC :CC: ,tG8C;     :1LG080L:
       i@@C;  :0G .8,1L,fLii1fLf;   .;tG8@@@@88888Ci.
    .i  ,tG@0t. Cf,C:f1:C.Lfi11i1fLG00GLti:,.    .:;i:.
     t01,   :tCt.L1if;t1it1ittii:,,..
      L@@8Gfi::1fif111;::i11ii1ti,
    .,  .:;i111i1tt1t;  :ttt1ii1t1.
     :LLt1ii1111tt1t11;;ittfi1t1;1;
      .1CGCf1;:;itt1tt1fttf;fi;tGi
        .. .:1LL1:;ftiLif:Li,LL,,t
       .;fG00f: .fGi.G1 8,,@1 L8
          ...,iC@C. C8 .@1 f@,.;
           .:1ft: ;0@; t@i t1
                .;1i, ;t: ..

EOF

echo "#### HollaEx CLI Installer ####"

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