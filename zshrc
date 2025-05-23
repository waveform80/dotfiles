export DEFAULT_USER=dave
# export MANPATH="/usr/local/man:$MANPATH"
export EDITOR=vim
export WORKON_HOME="$HOME"/envs
if [ -e "$HOME"/.pystartup ]; then
    export PYTHONSTARTUP="$HOME"/.pystartup
fi
if [ -x /usr/bin/batcat ]; then
    if /usr/bin/batcat --list-themes | grep -q ansi-dark; then
        THEME=ansi-dark
    else
        THEME=ansi
    fi
    export LESSOPEN="| /usr/bin/batcat --color always --theme $THEME --plain %s"
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
HISTSIZE=15000
SAVEHIST=10000
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
alias diff="diff -u --color=auto"

# Load completion routines (with bash compatibility)
autoload -Uz compinit bashcompinit
compinit
bashcompinit

[ -f /etc/zsh_command_not_found ] && source /etc/zsh_command_not_found
[ -f /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh ] && \
    source /usr/share/virtualenvwrapper/virtualenvwrapper_lazy.sh

source "${HOME}"/.zsh/zsh-fzy/zsh-fzy.plugin.zsh
source "${HOME}"/.zsh/git-aliases/git-aliases.zsh
fpath=("${HOME}"/.zsh/themes $fpath)

autoload -Uz promptinit
promptinit
prompt agnoster

bindkey '^F' fzy-file-widget
bindkey '^R' fzy-history-widget
bindkey '^P' fzy-proc-widget

function w3g() { w3m google.com/search\?q="$1"; }
function w3w() { elinks en.wikipedia.org/w/index.php\?search="$1"; }
function w3up() { w3m packages.ubuntu.com/search\?searchon=names\&suite=all\&section=all\&keywords="$1"; }
function w3dp() { w3m packages.debian.org/search\?searchon=names\&suite=all\&section=all\&keywords="$1"; }
function w3lp() { w3m launchpad.net/ubuntu/+source/"$1"; }
function bug() { w3m launchpad.net/bugs/"$1"; }

function indent() { sed -e 's/^/    /;' "$@"; }

function sercon() {
    local uart
    local baud=115200

    if [ $# -gt 0 ]; then
        uart="$1"
        shift
    else
        for dev in /dev/ttyUSB0 /dev/ttyACM0 /dev/ttyAMA0; do
            if [ -e "$dev" ]; then
                uart="$dev"
                break
            fi
        done
    fi
    if [ -n "$uart" ]; then
        echo "Connecting to $uart at ${baud}bps" >&2
        screen -e ^Ta "$uart" "$baud"
    else
        echo "Cannot determine serial port; please specify one" >&2
        return 1
    fi
}

function mpvc() {
    mpv --vo=tct --vo-tct-width=$COLUMNS --vo-tct-height=$LINES \
        --really-quiet "$@"
}

function bindiff() {
    local dump() { hexdump -e '1/1 "%02x "' -e '"%_c\n"' "$1" }
    diff --label "$1" <(dump "$1") --label "$2" <(dump "$2")
}

function get-package() {
    local pkg="$1"
    local series="$2"

    if [ -z "$pkg" ]; then
        echo "Must specify a package name" >2
        return 1
    fi
    if [ -z "$series" ]; then
        series="$(ubuntu-distro-info --devel)"
    fi
    if [ "$(basename $(pwd))" != "$pkg" ]; then
        mkdir -p "$1"
        cd "$1"
    fi
    [ -d "$pkg" ] || git clone lp:ubuntu/+source/"$pkg"
    pull-lp-source --download-only "$pkg" "$series"
    pull-lp-debs --download-only "$pkg" "$series"
}

alias sbs="sbuildwrap --no-arch-any --no-arch-all --source"
alias sbb="sbuildwrap --arch-any --arch-all --no-source"
alias sba="sbuildwrap --arch-any --arch-all --source"

function sync() {
    local profile="$1"
    mbsync "$profile" && \
        NOTMUCH_CONFIG="$HOME"/.mail/"$profile"/.notmuch-config notmuch new
}

function mutt() {
    local profile="$1"
    shift
    NEOMUTT_PROFILE="$profile" \
    NOTMUCH_CONFIG="$HOME"/.mail/"$profile"/.notmuch-config \
        neomutt -F "$HOME"/dotfiles/neomuttrc."$profile" "$@"
}

function abook() {
    local book="$HOME"/.mail/"$1"/address
    shift
    /usr/bin/abook --datafile "$book" "$@"
}

function rm-sbuild() {
    sudo rm -fr /var/lib/schroot/chroots/"$1"
    sudo rm -f /etc/schroot/chroot.d/sbuild-"$1"
}

function dunpack() {
    local deb="$1"

    mkdir "${deb%.deb}"
    pushd "${deb%.deb}"
    ar x ../"$deb"
    mkdir DEBIAN
    [ -e "control.tar.gz" ] && tar -C DEBIAN/ -xvzf control.tar.gz
    [ -e "control.tar.xz" ] && tar -C DEBIAN/ -xvJf control.tar.xz
    [ -e "data.tar.gz" ] && tar -xvzf data.tar.gz
    [ -e "data.tar.xz" ] && tar -xvJf data.tar.xz
    popd
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


function my_prompt_virtualenv() {
    if [[ -n $VIRTUAL_ENV ]]; then
        color=blue
        prompt_segment $color $PRIMARY_FG
        print -Pn " $(basename $VIRTUAL_ENV) "
    fi
}
function my_prompt_dir() {
    prompt_segment cyan $PRIMARY_FG ' %~ '
}
AGNOSTER_PROMPT_SEGMENTS[3]=my_prompt_virtualenv
AGNOSTER_PROMPT_SEGMENTS[4]=my_prompt_dir
setopt prompt_sp

eval "$(direnv hook zsh)"

ssh_agent="$HOME"/.ssh-agent
if [ -z "$SSH_AUTH_SOCK" -a ! -d "$XDG_RUNTIME_DIR"/keyring ]; then
    if [ -S "$ssh_agent" -a -O "$ssh_agent" -a -L "$ssh_agent" ]; then
        export SSH_AUTH_SOCK="$ssh_agent"
    else
        eval $(ssh-agent -s)
        ln -sf "$SSH_AUTH_SOCK" "$ssh_agent"
    fi
fi
export GPG_TTY=$(tty)

if [ -d "$HOME"/keys ]; then
    export PATH="$PATH":"$HOME"/keys
    source "$HOME"/keys/cryptfun
fi
