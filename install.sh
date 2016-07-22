#!/bin/bash

set -eu

# Install stuff
sudo apt-get update
sudo apt-get install -y \
	build-essential \
	curl \
	vim-nox \
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
	python3-virtualenv \
	virtualenvwrapper \
	exuberant-ctags \
	lsb-release

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}

if [ $(lsb_release -is) = "Ubuntu" ]; then
    # Disable annoying bits of unity
    gsettings set com.canonical.Unity.Lenses remote-content-search "none"
    gsettings set com.canonical.Unity.ApplicationsLens display-available-apps false

    # Style it nicely
    gsettings set org.gnome.desktop.interface gtk-theme 'Radiance'
    gsettings set org.gnome.desktop.wm.preferences theme 'Radiance'
fi

# Change default shell to zsh
chsh -s $(which zsh) || true

# Install powerline fonts
cd
git clone https://github.com/powerline/fonts.git
fonts/install.sh

# Install oh-my-zsh
curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | bash

# Install NeoBundle
curl -L https://raw.githubusercontent.com/Shougo/neobundle.vim/master/bin/install.sh | bash

# Set up zsh
ln -sf $HOME/dotfiles/agnoster-waveform.zsh-theme $HOME/.oh-my-zsh/themes/agnoster-waveform.zsh-theme
ln -sf $HOME/dotfiles/zshrc $HOME/.zshrc

# Set up vim with all your favourite plugins and bits
ln -sf $HOME/dotfiles/vimrc $HOME/.vimrc
vim-addons install align supertab taglist vcscommand

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
