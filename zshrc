# User configuration
export DEFAULT_USER=dave
export PATH=$PATH:$HOME/.local/bin:/snap/bin
[ -d $HOME/keys ] && export PATH=$PATH:$HOME/keys
# export MANPATH="/usr/local/man:$MANPATH"
export WORKON_HOME=~/envs
export PYTHONSTARTUP=~/.pystartup
if [ -x /usr/bin/batcat ]; then
    export LESSOPEN="| /usr/bin/batcat --color always --theme ansi-dark --plain %s"
    export LESS=" -R"
elif [ -x /usr/bin/highlight ]; then
    export LESSOPEN="| /usr/bin/highlight --force --out-format=xterm256 %s"
    export LESS=" -R"
elif [ -x /usr/bin/pygmentize ]; then
    export LESSOPEN="| /usr/bin/pygmentize -f terminal256 -O style=perldoc %s"
    export LESS=" -R"
fi

# Use uneven column widths when listing completions to reduce the number of
# rows printed
setopt LIST_PACKED

# Set up a directory stack with "cd"
DIRSTACKSIZE=10
setopt AUTO_PUSHD
setopt PUSHD_MINUS

# Execute history expansions on request instead of editing them first
HISTSIZE=1500
SAVEHIST=1000
HISTFILE=~/.zsh_history
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_SPACE
setopt HIST_IGNORE_DUPS
setopt INC_APPEND_HISTORY_TIME

# Act like sh/ksh with >> against non-existing file
setopt APPEND_CREATE

eval "$(dircolors)"

alias ls="ls --color=auto"
alias dir="dir --color=auto"
alias vdir="vdir --color=auto"
alias grep="grep --color=auto"
alias egrep="egrep --color=auto"
alias fgrep="fgrep --color=auto"
alias tiga="tig --all"
alias dquilt="quilt --quiltrc=${HOME}/.quiltrc-dpkg"
alias sbs="sbuild --no-arch-any --no-arch-all --source"
alias sbb="sbuild --arch-any --arch-all --no-source"
alias sba="sbuild --arch-any --arch-all --source"
alias usbcon="screen -e ^Ta /dev/ttyUSB0 115200"
alias sercon="screen -e ^Ta /dev/ttyAMA0 115200"
alias diff="diff -u --color=auto"

[ -f /etc/zsh_command_not_found ] && source /etc/zsh_command_not_found

source /usr/share/zplug/init.zsh
zplug "agnoster/agnoster-zsh-theme", as:theme, use:"*.zsh-theme"
zplug "plugins/virtualenvwrapper", from:oh-my-zsh
zplug "mdumitru/git-aliases", from:github
zplug "aperezdc/zsh-fzy", from:github
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi
zplug load

bindkey '^F' fzy-file-widget
bindkey '^R' fzy-history-widget
bindkey '^P' fzy-proc-widget

function w3g() { w3m google.com/search\?q="$1"; }
function w3w() { w3m en.wikipedia.org/w/index.php\?search="$1"; }
function w3up() { w3m packages.ubuntu.com/search\?searchon=names\&suite=all\&section=all\&keywords="$1"; }
function w3dp() { w3m packages.debian.org/search\?searchon=names\&suite=all\&section=all\&keywords="$1"; }
function w3lp() { w3m launchpad.net/+search\?field.text="$1"; }
function bug() { w3m launchpad.net/bugs/$1; }

function sync() {
    mbsync $1 && NOTMUCH_CONFIG=$HOME/.mail/$1/.notmuch-config notmuch new
}

function mutt() {
    NOTMUCH_CONFIG=$HOME/.mail/$1/.notmuch-config \
        neomutt -F $HOME/dotfiles/neomuttrc.$1;
}

function abook() { /usr/bin/abook --datafile $HOME/.mail/$1/address }

function rm-sbuild() {
    if [ -d /var/lib/schroot/chroots/$1 ]; then
        sudo rm -fr /var/lib/schroot/chroots/$1
        sudo rm /etc/schroot/chroot.d/sbuild-$1
    else
        echo "No such chroot: $1" 2>/dev/null
    fi
}

function gcal() {
    while true; do
        clear
        gcalcli agenda
        echo
        gcalcli calw --monday
        sleep 600
    done
}

function vimrecover() {
    find . -type f -name '.*.sw?' -exec vim -r "{}" -c DiffSwap \; -exec rm -iv "{}" \;
}


my_prompt_virtualenv() {
    if [[ -n $VIRTUAL_ENV ]]; then
        color=blue
        prompt_segment $color $PRIMARY_FG
        print -Pn " $(basename $VIRTUAL_ENV) "
    fi
}
my_prompt_dir() {
    prompt_segment cyan $PRIMARY_FG ' %~ '
}
AGNOSTER_PROMPT_SEGMENTS[3]=my_prompt_virtualenv
AGNOSTER_PROMPT_SEGMENTS[4]=my_prompt_dir

eval "$(direnv hook zsh)"

ssh_agent=$HOME/.ssh-agent
if [ -z $SSH_AUTH_SOCK -a ! -d $XDG_RUNTIME_DIR/keyring ]; then
    if [ -S $ssh_agent -a -O $ssh_agent -a -L $ssh_agent ]; then
        export SSH_AUTH_SOCK=$ssh_agent
    else
        eval $(ssh-agent -s)
        ln -sf $SSH_AUTH_SOCK $ssh_agent
    fi
fi
