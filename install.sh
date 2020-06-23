#!/bin/bash

set -eu

# Install stuff
sudo apt update

if which X >/dev/null 2>&1; then
    if [ $(lsb_release -is) = "Ubuntu" ]; then
        VIM=vim-gtk3
        if command -v gsettings >/dev/null; then
            # Disable annoying bits of unity
            gsettings set com.canonical.Unity.Lenses remote-content-search "none"
            gsettings set com.canonical.Unity.ApplicationsLens display-available-apps false

            # Style it nicely
            gsettings set org.gnome.desktop.interface gtk-theme 'Radiance'
            gsettings set org.gnome.desktop.wm.preferences theme 'Radiance'
        fi
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
    vim-addon-manager \
    vim-scripts \
    git \
    git-core \
    tig \
    zsh \
    byobu \
    ranger \
    ipython \
    ipython3 \
    ${PSPG} \
    postgresql-client \
    pastebinit \
    python-dev \
    python-pip \
    python-virtualenv \
    python-pygments \
    python3-dev \
    python3-pip \
    python3-virtualenv \
    virtualenvwrapper \
    exuberant-ctags \
    lsb-release \
    libjpeg-dev \
    libtiff5-dev \
    libfreetype6-dev \
    liblcms2-dev \
    sc \
    zsync"

sudo apt install -y $PACKAGES

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

# Install powerline fonts
cd
if [ ! -d fonts ]; then
    git clone https://github.com/powerline/fonts.git
    fonts/install.sh
fi

# Install oh-my-zsh
if [ ! -d .oh-my-zsh ]; then
    curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sed -e 's/^ *chsh/#chsh/' | bash
fi

# Install dein
if [ ! -d .vim/bundle/dein.vim ]; then
    curl -L https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh > installer.sh
    bash installer.sh $HOME/.vim/bundle/dein.vim
    rm installer.sh
fi

# Set up zsh
ln -sf $HOME/dotfiles/agnoster-waveform.zsh-theme $HOME/.oh-my-zsh/themes/agnoster-waveform.zsh-theme
ln -sf $HOME/dotfiles/zshrc $HOME/.zshrc

# Set up vim with all your favourite plugins and bits; remember to call
# dein#update() in vim after this
ln -sf $HOME/dotfiles/vimrc $HOME/.vimrc
vim-addons install align supertab

# Set up elinks
mkdir -p $HOME/.elinks
ln -sf $HOME/dotfiles/elinks.conf $HOME/.elinks/elinks.conf

# Set up mutt
mkdir -p $HOME/.mutt
mkdir -p $HOME/.mutt/cache
ln -sf $HOME/dotfiles/muttrc $HOME/.mutt/muttrc

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

# Customize Python
ln -sf $HOME/dotfiles/pystartup $HOME/.pystartup
ln -sf $HOME/dotfiles/pylintrc $HOME/.pylintrc
ln -sf $HOME/dotfiles/flake8 $HOME/.flake8

# Customize git
mkdir -p $XDG_CONFIG_HOME/git
ln -sf $HOME/dotfiles/gitconfig $XDG_CONFIG_HOME/git/config
ln -sf $HOME/dotfiles/gitignore $XDG_CONFIG_HOME/git/ignore

# Customize psql
ln -sf $HOME/dotfiles/psqlrc $HOME/.psqlrc

# Customize pastebinit
ln -sf $HOME/dotfiles/pastebinit.xml $HOME/.pastebinit.xml

# Stuff for Debian packaging
ln -sf $HOME/dotfiles/gbp.conf $HOME/.gbp.conf
ln -sf $HOME/dotfiles/quiltrc-dpkg $HOME/.quiltrc-dpkg
ln -sf $HOME/dotfiles/dputcf $HOME/.dput.cf

# Import the usual SSH keys
ssh-import-id lp:waveform
