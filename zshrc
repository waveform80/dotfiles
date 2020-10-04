# User configuration
export DEFAULT_USER=dave
export PATH=$PATH:$HOME/.local/bin:/snap/bin
# export MANPATH="/usr/local/man:$MANPATH"
export WORKON_HOME=~/envs
export PYTHONSTARTUP=~/.pystartup
export DEBFULLNAME="Dave Jones"
export DEBEMAIL="dave@waveform.org.uk"
export LESS=" -R"
export LESSOPEN="| /usr/bin/pygmentize -f terminal256 -O style=perldoc %s"

# GPG key
export GPGKEY=A057F8D5

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
setopt EXTENDED_HISTORY

# Act like sh/ksh with >> against non-existing file
setopt APPEND_CREATE >&/dev/null

alias ls="ls --color=auto"
alias dir="dir --color=auto"
alias vdir="vdir --color=auto"
alias grep="grep --color=auto"
alias egrep="egrep --color=auto"
alias fgrep="fgrep --color=auto"
alias tiga="tig --all"
alias dquilt="quilt --quiltrc=${HOME}/.quiltrc-dpkg"
alias sbs="sbuild --no-arch-any --no-arch-all --source"
alias sbsf="sbuild --no-arch-any --no-arch-all --source --force-orig-source"
alias sbb="sbuild --arch-any --arch-all --no-source"

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
if [ -z "$SSH_AUTH_SOCK" -a ! -d $XDG_RUNTIME_DIR/keyring ]; then
    eval $(ssh-agent -s)
fi

if ! ssh-add -l >/dev/null; then
    if setopt | grep -q interactive; then
        echo -n "Add SSH keys? [y/N] "
        if read -q; then
            echo
            if [ -f $HOME/.ssh/id_rsa ]; then
                ssh-add
            fi
            if [ -f $HOME/.ssh/id_keepass ] && [ -d $HOME/keys ]; then
                $HOME/keys/db-add-keys -k $HOME/.ssh/id_keepass -e "Local SSH key" $HOME/keys/DavesDb.kdbx
            fi
        fi
    fi
fi
