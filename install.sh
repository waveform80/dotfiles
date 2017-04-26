#!/bin/bash

set -eu

# Install stuff
sudo apt update

PACKAGES="\
    build-essential \
    curl \
    vim-gtk \
    vim-addon-manager \
    vim-scripts \
    git \
    git-core \
    zsh \
    byobu \
    ipython \
    ipython3 \
    python-dev \
    python-pip \
    python-virtualenv \
    python3-dev \
    python3-pip \
    virtualenvwrapper \
    exuberant-ctags \
    lsb-release \
    libjpeg-dev \
    libtiff5-dev \
    libfreetype6-dev \
    liblcms2-dev"

# python3-virtualenv was added in 16.04
if dpkg -l python3-virtualenv >/dev/null 2>&1; then
    PACKAGES="$PACKAGES python3-virtualenv"
fi

sudo apt install -y $PACKAGES

set +e

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

if command -v gsettings >/dev/null; then
    if [ $(lsb_release -is) = "Ubuntu" ]; then
        # Disable annoying bits of unity
        gsettings set com.canonical.Unity.Lenses remote-content-search "none"
        gsettings set com.canonical.Unity.ApplicationsLens display-available-apps false

        # Style it nicely
        gsettings set org.gnome.desktop.interface gtk-theme 'Radiance'
        gsettings set org.gnome.desktop.wm.preferences theme 'Radiance'
    fi
fi

# Install powerline fonts
cd
git clone https://github.com/powerline/fonts.git
fonts/install.sh

# Install oh-my-zsh
curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | bash

# Install dein
curl -L https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh > installer.sh
bash installer.sh $HOME/.vim/bundle/dein.vim
rm installer.sh

# Set up zsh
ln -sf $HOME/dotfiles/agnoster-waveform.zsh-theme $HOME/.oh-my-zsh/themes/agnoster-waveform.zsh-theme
ln -sf $HOME/dotfiles/zshrc $HOME/.zshrc

# Set up vim with all your favourite plugins and bits
ln -sf $HOME/dotfiles/vimrc $HOME/.vimrc
vim-addons install align supertab taglist

# Set up byobu with some tmux tweaks
BYOBU_CONFIG_DIR=${BYOBU_CONFIG_DIR:-$XDG_CONFIG_HOME/byobu}
mkdir -p $BYOBU_CONFIG_DIR
ln -sf $HOME/dotfiles/tmux.conf $BYOBU_CONFIG_DIR/.tmux.conf

# Customize Python
ln -sf $HOME/dotfiles/pystartup $HOME/.pystartup

# Customize git
mkdir -p $XDG_CONFIG_HOME/git
ln -sf $HOME/dotfiles/gitconfig $XDG_CONFIG_HOME/git/config
ln -sf $HOME/dotfiles/gitignore $XDG_CONFIG_HOME/git/ignore

# Customize psql
ln -s $HOME/dotfiles/psqlrc $HOME/.psqlrc
