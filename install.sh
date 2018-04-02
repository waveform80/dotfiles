#!/bin/bash

set -eu

# Install stuff
sudo apt update

if [ $(lsb_release -is) = "Ubuntu" ]; then
    VIM=vim-gtk3
    MUTT=mutt-patched
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
    MUTT=mutt
fi

PACKAGES="\
    atool \
    build-essential \
    curl \
    ${MUTT} \
    ${VIM} \
    vim-addon-manager \
    vim-scripts \
    git \
    git-core \
    zsh \
    byobu \
    ranger \
    ipython \
    ipython3 \
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
    sc"

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
    curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | bash
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

# Set up vim with all your favourite plugins and bits
ln -sf $HOME/dotfiles/vimrc $HOME/.vimrc
vim-addons install align supertab

# Set up elinks
mkdir -p $HOME/.elinks
ln -sf $HOME/dotfiles/elinks.conf $HOME/.elinks/elinks.conf

# Set up mutt
mkdir -p $HOME/.mutt
mkdir -p $HOME/.mutt/cache
ln -sf $HOME/dotfiles/muttsidebar $HOME/.mutt/sidebar.muttrc
ln -sf $HOME/dotfiles/muttrc $HOME/.mutt/muttrc

# Set up ranger
mkdir -p $HOME/.config/ranger
cp /usr/share/doc/ranger/config/scope.sh $HOME/.config/ranger/
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

# Stuff for Debian packaging
ln -sf $HOME/dotfiles/gbp.conf $HOME/.gbp.conf
ln -sf $HOME/dotfiles/quiltrc-dpkg $HOME/.quiltrc-dpkg
