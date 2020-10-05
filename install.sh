#!/bin/bash

set -eu

# Install stuff
sudo apt update

if which X >/dev/null 2>&1; then
    if [ $(lsb_release -is) = "Ubuntu" ]; then
        VIM=vim-gtk3
    else
        VIM=vim-gtk
    fi
else
    VIM=vim-nox
fi

if apt-cache show pspg >/dev/null 2>&1; then
    PSPG=pspg
else
    PSPG=
fi

PACKAGES="\
    ssh-import-id \
    atool \
    build-essential \
    curl \
    mutt \
    elinks \
    ${VIM} \
    fonts-powerline \
    fonts-inconsolata \
    vim-addon-manager \
    vim-scripts \
    vim-airline \
    vim-airline-themes \
    vim-python-jedi \
    vim-syntastic \
    git \
    git-core \
    tig \
    zsh \
    zplug \
    direnv \
    fzy \
    cmus \
    aewan \
    byobu \
    ranger \
    ipython3 \
    ${PSPG} \
    postgresql-client \
    pastebinit \
    python3-dev \
    python3-pip \
    python3-virtualenv \
    python3-pygments \
    virtualenvwrapper \
    exuberant-ctags \
    lsb-release \
    shed \
    sc \
    jq \
    zsync"

sudo apt install -y $PACKAGES

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

# Set up zsh
ln -sf $HOME/dotfiles/zshrc $HOME/.zshrc

# Set up vim with all your favourite plugins and bits
ln -sf $HOME/dotfiles/vimrc $HOME/.vimrc
vim-addons install align supertab python-jedi python-indent
VIM_PACK=$HOME/.vim/pack/plugins/start
mkdir -p $VIM_PACK
git clone https://tpope.io/vim/unimpaired.git $VIM_PACK/unimpaired
vim -u NONE -c "helptags $VIM_PACK/unimpaired/doc" -c q
git clone https://github.com/srstevenson/vim-picker $VIM_PACK/vim-picker
git clone https://github.com/dhruvasagar/vim-table-mode $VIM_PACK/vim-table-mode
git clone https://github.com/ConradIrwin/vim-bracketed-paste $VIM_PACK/vim-bracketed-paste
#git clone https://github.com/Vimjas/vim-python-pep8-indent $VIM_PACK/vim-python-pep8-indent
#git clone https://github.com/mg979/vim-visual-multi $VIM_PACK/vim-visual-multi

# Set up ranger
mkdir -p $HOME/.config/ranger
if [ -f /usr/share/doc/ranger/config/scope.sh ]; then
    cp /usr/share/doc/ranger/config/scope.sh $HOME/.config/ranger/
elif [ -f /usr/share/doc/ranger/config/scope.sh.gz ]; then
    gunzip -c /usr/share/doc/ranger/config/scope.sh.gz > $HOME/.config/ranger/scope.sh
fi
chmod +x $HOME/.config/ranger/scope.sh

# Set up byobu with some tmux tweaks
BYOBU_CONFIG_DIR=${BYOBU_CONFIG_DIR:-$XDG_CONFIG_HOME/byobu}
mkdir -p $BYOBU_CONFIG_DIR
ln -sf $HOME/dotfiles/tmux.conf $BYOBU_CONFIG_DIR/.tmux.conf

# Link all the other config files
mkdir -p $HOME/.mutt
mkdir -p $HOME/.mutt/cache
ln -sf $HOME/dotfiles/muttrc $HOME/.mutt/muttrc
mkdir -p $HOME/.elinks
ln -sf $HOME/dotfiles/elinks.conf $HOME/.elinks/elinks.conf
mkdir -p $HOME/.w3m
ln -sf $HOME/dotfiles/w3mrc $HOME/.w3m/config
ln -sf $HOME/dotfiles/w3mkeys $HOME/.w3m/keymap
ln -sf $HOME/dotfiles/pystartup $HOME/.pystartup
ln -sf $HOME/dotfiles/pylintrc $HOME/.pylintrc
ln -sf $HOME/dotfiles/flake8 $HOME/.flake8
mkdir -p $XDG_CONFIG_HOME/git
ln -sf $HOME/dotfiles/gitconfig $XDG_CONFIG_HOME/git/config
ln -sf $HOME/dotfiles/gitignore $XDG_CONFIG_HOME/git/ignore
ln -sf $HOME/dotfiles/psqlrc $HOME/.psqlrc
ln -sf $HOME/dotfiles/pastebinit.xml $HOME/.pastebinit.xml
ln -sf $HOME/dotfiles/tigrc $HOME/.tigrc
ln -sf $HOME/dotfiles/gbp.conf $HOME/.gbp.conf
ln -sf $HOME/dotfiles/quiltrc-dpkg $HOME/.quiltrc-dpkg
ln -sf $HOME/dotfiles/dputcf $HOME/.dput.cf

# Import the usual SSH keys
ssh-import-id lp:waveform
