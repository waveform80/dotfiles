# Path to your oh-my-zsh installation.
export ZSH=~/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="agnoster-waveform"

# Uncomment the following line to use case-sensitive completion.
CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git virtualenvwrapper python ubuntu safe-paste zsh-navigation-tools)

# User configuration
export DEFAULT_USER=dave
export PATH=$PATH:$HOME/.local/bin
# export MANPATH="/usr/local/man:$MANPATH"
export WORKON_HOME=~/envs
export PYTHONSTARTUP=~/.pystartup
export DEBFULLNAME="Dave Jones"
export DEBEMAIL="dave@waveform.org.uk"
export LESS=" -R"
export LESSOPEN="| /usr/bin/pygmentize -f terminal256 -O style=perldoc %s"

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# GPG key
export GPGKEY=A057F8D5

# AWS keys
[ -f $HOME/Dropkeys/keys ] && source $HOME/Dropbox/keys/aws.sh

# Use uneven column widths when listing completions to reduce the number of
# rows printed
setopt LIST_PACKED

# Disable automatic changing of dir without "cd"
unsetopt AUTO_CD

# Set up a directory stack with "cd"
export DIRSTACKSIZE=10
setopt AUTO_PUSHD
setopt PUSHD_MINUS

# Execute history expansions on request instead of editing them first
unsetopt HIST_VERIFY

# Enable sharing history like KSH, disable mutually excl. options
unsetopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

# Act like sh/ksh with >> against non-existing file
setopt APPEND_CREATE >&/dev/null

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias dquilt="quilt --quiltrc=${HOME}/.quiltrc-dpkg"

# Load the landscape dev-env
[ -f ~/.landscape-env ] && . ~/.landscape-env || true
[ -f ~/.landscape-api ] && . ~/.landscape-api || true
