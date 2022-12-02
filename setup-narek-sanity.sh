#!/bin/bash

set -x

# Grab our libs
. "`dirname $0`/setup-lib.sh"

if [ -f $OURDIR/narek-sanity-done ]; then
    exit 0
fi

cd ~

git clone https://github.com/Ngalstyan4/dotfiles.git
cd dotfiles
./setup.sh

curl -LO https://github.com/BurntSushi/ripgrep/releases/download/13.0.0/ripgrep_13.0.0_amd64.deb
sudo dpkg -i ripgrep_13.0.0_amd64.deb

# both created clusters will likely have identical bash prompts.
# this will have disambiguate the two by indicating whether the cluster
# is primary or remote service provider
echo "PS1=($CLUSTERROLE)\$PS1" >> ~/.bashrc

touch $OURDIR/narek-sanity-done
