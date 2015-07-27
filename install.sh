#!/bin/bash

# Disable annoying bits of unity
gsettings set com.canonical.Unity.Lenses remote-content-search "none"
gsettings set com.canonical.Unity.ApplicationsLens display-available-apps false

# Style it nicely
gsettings set org.gnome.desktop.interface gtk-theme 'Radiance'
gsettings set org.gnome.desktop.wm.preferences theme 'Radiance'

# Install stuff
sudo apt-get update
sudo apt-get install -y \
	build-essential \
	curl \
	vim-gnome \
	vim-addon-manager \
	vim-scripts \
	git \
	git-core \
	zsh \
	byobu \
	python-dev \
	python-pip \
	python-virtualenv \
	virtualenvwrapper

# Change default shell to zsh
chsh -s $(which zsh)

# Install powerline fonts
cd
git clone https://github.com/powerline/fonts.git
fonts/install.sh

# Install solarized theme for Gnome Terminal and set it to use Inconsolata powerline font
git clone https://github.com/sigurdga/gnome-terminal-colors-solarized.git
gnome-terminal-colors-solarized/install.sh -s dark -p Solarized
gconftool-2 --set "/apps/gnome-terminal/profiles/Solarized/font" --type string "Inconsolata for Powerline Medium 12"

# Install oh-my-zsh
curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | bash

# Install NeoBundle
curl -L https://raw.githubusercontent.com/Shougo/neobundle.vim/master/bin/install.sh | bash

# Set up zsh
ln -sf dotfiles/zshrc ~/.zshrc

# Set up vim with all your favourite plugins and bits
ln -sf dotfiles/vimrc ~/.vimrc
vim-addons install align supertab taglist vcscommand

# Set up byobu with some tmux tweaks
mkdir -p ~/.byobu
ln -sf ../dotfiles/tmux.conf ~/.byobu/.tmux.conf

