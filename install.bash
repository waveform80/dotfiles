#!/bin/bash

set -eu

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-${HOME}/.config}


task_apt() {
    case "$1" in
        title)
            echo "Do full apt upgrade"
            ;;
        default)
            echo 0
            ;;
        postinst)
            # No need for apt update; do_install always does that first
            sudo apt full-upgrade -y --autoremove --purge
            ;;
    esac
}


task_dev() {
    local highlight

    case "$1" in
        title)
            echo "Install dev tools (git, tig, ctags, ...)"
            ;;
        default)
            echo 1
            ;;
        packages)
            if apt-cache show bat >/dev/null 2>&1; then
                highlight=bat
            else
                highlight=highlight
            fi
            echo build-essential git git-email tig exuberant-ctags ${highlight}
            echo screen bison flex fossil lcov mercurial
            ;;
        postinst)
            mkdir -p "$XDG_CONFIG_HOME"/git
            ln -sf "$HOME"/dotfiles/gitconfig "$XDG_CONFIG_HOME"/git/config
            ln -sf "$HOME"/dotfiles/gitignore "$XDG_CONFIG_HOME"/git/ignore
            ln -sf "$HOME"/dotfiles/tigrc "$HOME"/.tigrc
            mkdir -p "$HOME"/projects/work "$HOME"/projects/home
            ;;
    esac
}


task_pico() {
    case "$1" in
        title)
            echo "Install mcu dev tools (avr-libc, dfu-programmer, ...)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo dfu-util dfu-programmer avrdude avr-libc device-tree-compiler
            echo gcc-arm-none-eabi gdbserver hexdiff hexcurse lrzsz
            ;;
    esac
}


task_doc() {
    case "$1" in
        title)
            echo "Install documentation tools (sphinx, graphviz, ...)"
            ;;
        default)
            echo 1
            ;;
        packages)
            echo python3-sphinx python3-sphinx-rtd-theme
            echo texlive-latex-recommended texlive-latex-extra
            echo texlive-xetex texlive-fonts-recommended latexmk xindy
            echo pdftk-java groff texlive
            # Graphical generation
            echo inkscape xdot fritzing mscgen
            # Blog bits
            echo pelican python3-typogrify
            ;;
    esac
}


task_pack() {
    case "$1" in
        title)
            echo "Install packaging tools (pull-lp-source, sbuild, ...)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo ubuntu-dev-tools packaging-dev sbuild shellcheck
            ;;
        postinst)
            ln -sf "$HOME"/dotfiles/gbp.conf "$HOME"/.gbp.conf
            ln -sf "$HOME"/dotfiles/quiltrc-dpkg "$HOME"/.quiltrc-dpkg
            ln -sf "$HOME"/dotfiles/dputcf "$HOME"/.dput.cf
            ln -sf "$HOME"/dotfiles/sbuildrc "$HOME"/.sbuildrc
            ln -sf "$HOME"/dotfiles/mk-sbuildrc "$HOME"/.mk-sbuild.rc
            ln -sf "$HOME"/dotfiles/reportbugrc "$HOME"/.reportbugrc
            ln -sf "$HOME"/dotfiles/merge.bash "$HOME"/.local/bin/merge
            ln -sf "$HOME"/dotfiles/proposed.bash "$HOME"/.local/bin/proposed-enable
            ln -sf "$HOME"/dotfiles/sync-images "$HOME"/.local/bin/sync-images
            ;;
    esac
}


task_db() {
    case "$1" in
        title)
            echo "Install db tools (sqlite3, pg-client)"
            ;;
        default)
            echo 1
            ;;
        packages)
            echo sqlite3 postgresql-client sc jq
            if apt-cache show pspg >/dev/null 2>&1; then
                echo pspg
            fi
            ;;
        postinst)
            ln -sf "$HOME"/dotfiles/psqlrc "$HOME"/.psqlrc
            ;;
    esac
}


task_py() {
    case "$1" in
        title)
            echo "Install Python stuff (ipython, jupyter, libs)"
            ;;
        default)
            echo 1
            ;;
        packages)
            echo ipython3 python3-dev python3-pip python3-virtualenv
            echo python3-pygments virtualenvwrapper tox pylint
            # Blog bits
            echo pelican python3-typogrify
            # Libraries
            echo python3-html5lib python3-lxml python3-numpy
            echo python3-pil python3-argcomplete python3-ruamel.yaml
            echo python3-zmq
            if apt-cache show python3-cbor2 >/dev/null 2>&1; then
                echo python3-cbor2
            fi
            ;;
        postinst)
            ln -sf "$HOME"/dotfiles/pystartup "$HOME"/.pystartup
            ln -sf "$HOME"/dotfiles/pylintrc "$HOME"/.pylintrc
            ;;
    esac
}


task_email() {
    case "$1" in
        title)
            echo "Install e-mail client (mutt, notmuch, isync)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo isync neomutt notmuch msmtp-mta abook
            ;;
        postinst)
            mkdir -p "$HOME"/.mail/{home,work}
            mkdir -p "$HOME"/.cache/mutt/{home,work}
            ln -sf "$HOME"/dotfiles/mbsyncrc "$HOME"/.mbsyncrc
            ln -sf "$HOME"/dotfiles/notmuch-home "$HOME"/.mail/home/.notmuch-config
            ln -sf "$HOME"/dotfiles/notmuch-work "$HOME"/.mail/work/.notmuch-config
            ln -sf "$HOME"/dotfiles/dot_msmtprc "$HOME"/.msmtprc
            chmod 600 "$HOME"/dotfiles/msmtprc
            ln -sf "$HOME"/dotfiles/mailcap "$HOME"/.mailcap
            mkdir -p "$XDG_CONFIG_HOME"/systemd/user/
            ln -sf "$HOME"/dotfiles/mbsync@.service "$XDG_CONFIG_HOME"/systemd/user/
            ln -sf "$HOME"/dotfiles/mbsync@.timer "$XDG_CONFIG_HOME"/systemd/user/
            systemctl enable --user mbsync@home.timer
            systemctl enable --user mbsync@work.timer
            ;;
    esac
}


task_fs() {
    case "$1" in
        title)
            echo "Install fs tools (ranger, ncdu, entr, atool)"
            ;;
        default)
            echo 1
            ;;
        packages)
            echo atool ncdu entr inotify-tools ranger shed mc lz4 zstd
            echo p7zip-full
            ;;
        postinst)
            mkdir -p "$XDG_CONFIG_HOME"/ranger
            ln -sf "$HOME"/dotfiles/ranger.conf "$XDG_CONFIG_HOME"/ranger/rc.conf
            if apt-cache show bat >/dev/null 2>&1; then
                ranger --copy-config=scope
                sed -i -e 's/\bbat\b/batcat/' "$XDG_CONFIG_HOME"/ranger/scope.sh
            fi
            ln -sf "$HOME"/dotfiles/flash.bash "$HOME"/.local/bin/flashcard
            ln -sf "$HOME"/dotfiles/mount.bash "$HOME"/.local/bin/mountcard
            ;;
    esac
}


task_net() {
    case "$1" in
        title)
            echo "Install net tools (curl, w3m, elinks, zsync)"
            ;;
        default)
            echo 1
            ;;
        packages)
            echo curl w3m elinks pastebinit zsync nmap sshuttle sshfs
            echo nfs-common
            ;;
        postinst)
            mkdir -p "$HOME"/.elinks
            ln -sf "$HOME"/dotfiles/elinks.conf "$HOME"/.elinks/elinks.conf
            mkdir -p "$HOME"/.w3m
            ln -sf "$HOME"/dotfiles/w3mrc "$HOME"/.w3m/config
            ln -sf "$HOME"/dotfiles/w3mkeys "$HOME"/.w3m/keymap
            ln -sf "$HOME"/dotfiles/pastebinit.xml "$HOME"/.pastebinit.xml
            ;;
    esac
}


task_ssh() {
    case "$1" in
        title)
            echo "Install & configure SSH server"
            ;;
        default)
            echo 1
            ;;
        packages)
            echo openssh-server ssh-import-id
            ;;
        postinst)
            sudo sed -i \
                -e '/#PasswordAuthentication/ s/.*/PasswordAuthentication no/' \
                -e '/#PermitRootLogin/ s/.*/PermitRootLogin no/' \
                /etc/ssh/sshd_config
            ssh-import-id lp:waveform
            ssh-keygen -t rsa -N "" -f "$HOME"/.ssh/id_rsa
            sudo systemctl enable ssh.service
            sudo systemctl restart ssh.service
            ;;
    esac
}


task_music() {
    case "$1" in
        title)
            echo "Install media clients (cmus)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo cmus
            ;;
    esac
}


task_fonts() {
    case "$1" in
        title)
            echo "Install fonts"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo fonts-powerline fonts-inconsolata fonts-ubuntu
            ;;
    esac
}


task_kmscon() {
    case "$1" in
        title)
            echo "Install & configure kmscon (EXPERIMENTAL)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo fonts-powerline fonts-ubuntu kmscon
            ;;
        preinst)
            if command -v add-apt-repository >/dev/null; then
                # Add kmscon PPA but don't install it implicitly (still
                # experimental, etc.)
                sudo add-apt-repository -y ppa:waveform/kmscon
            else
                cat << EOF | sudo sh -c 'cat > /etc/apt/sources.list.d/kmscon.list'
deb http://ppa.launchpad.net/waveform/kmscon/ubuntu hirsute main
# deb-src http://ppa.launchpad.net/waveform/kmscon/ubuntu hirsute main
EOF
            fi
            ;;
        postinst)
            sudo sed -i \
                -e '/#font-size=/ s/.*/font-size=14/' \
                -e '/#font-name=/ s/.*/font-name=Ubuntu Mono/' \
                /etc/kmscon/kmscon.conf
            cat << EOF
Installed in experimental mode: tty1 remains standard getty; all other ttys
will auto-launch kmscon. Once you are satisfied things are working, switch tty1
to kmscon like so:

sudo systemctl disable getty@tty1
sudo systemctl enable kmsconvt@tty1
EOF
            ;;
    esac
}


task_tmux() {
    case "$1" in
        title)
            echo "Install & configure tmux"
            ;;
        default)
            echo 1
            ;;
        packages)
            echo byobu tmux
            ;;
        postinst)
            ln -sf "$HOME"/dotfiles/tmux.conf "$HOME"/.tmux.conf
            ;;
    esac
}


task_vim() {
    local vim_pkg vim_path

    if command -v X >/dev/null 2>&1; then
        vim_pkg="vim-gtk3"
        vim_path="/usr/bin/vim.gtk3"
    else
        vim_pkg="vim-nox"
        vim_path="/usr/bin/vim.nox"
    fi

    case "$1" in
        title)
            echo "Install & configure vim"
            ;;
        default)
            echo 1
            ;;
        packages)
            echo aspell ${vim_pkg} vim-addon-manager vim-scripts
            echo vim-airline vim-airline-themes vim-python-jedi vim-syntastic
            ;;
        postinst)
            local vim_pack

            ln -sf "$HOME"/dotfiles/vimrc "$HOME"/.vimrc
            vim_scripts_ver=$(dpkg-query -f '${Version}' -W vim-scripts)
            if dpkg --compare-versions "$vim_scripts_ver" ge 20210101; then
                vim-addons install python-jedi
            else
                vim-addons install align supertab python-jedi python-indent
            fi
            vim_pack="$HOME"/.vim/pack/plugins/start
            mkdir -p "$vim_pack"
            [ -d "$vim_pack"/unimpaired ] || git clone https://tpope.io/vim/unimpaired.git "$vim_pack"/unimpaired
            vim -u NONE -c "helptags $vim_pack/unimpaired/doc" -c q
            [ -d "$vim_pack"/fugitive ] || git clone https://tpope.io/vim/fugitive.git "$vim_pack"/fugitive
            [ -d "$vim_pack"/tagbar ] || git clone https://github.com/preservim/tagbar "$vim_pack"/tagbar
            [ -d "$vim_pack"/vim-picker ] || git clone https://github.com/srstevenson/vim-picker "$vim_pack"/vim-picker
            [ -d "$vim_pack"/vim-table-mode ] || git clone https://github.com/dhruvasagar/vim-table-mode "$vim_pack"/vim-table-mode
            [ -d "$vim_pack"/vim-bracketed-paste ] || git clone https://github.com/ConradIrwin/vim-bracketed-paste "$vim_pack"/vim-bracketed-paste
            [ -d "$vim_pack"/vim-notmuch-address ] || git clone https://github.com/waveform80/vim-notmuch-address "$vim_pack"/vim-notmuch-address
            #git clone https://github.com/Vimjas/vim-python-pep8-indent "$vim_pack"/vim-python-pep8-indent
            #git clone https://github.com/mg979/vim-visual-multi "$vim_pack"/vim-visual-multi
            sudo update-alternatives --set editor "${vim_path}"
            ;;
    esac
}


task_zsh() {
    case "$1" in
        title)
            echo "Install & configure zsh"
            ;;
        default)
            echo 1
            ;;
        packages)
            echo zsh zplug direnv fzy
            ;;
        postinst)
            ln -sf "$HOME"/dotfiles/zshrc "$HOME"/.zshrc
            sudo chsh -s /usr/bin/zsh "$USER"
            pushd "$HOME"
            git clone https://github.com/powerline/fonts
            sudo cp fonts/Terminus/PSF/*.psf.gz /usr/share/consolefonts/
            sudo sh -c 'echo FONT="ter-powerline-v16b.psf.gz" >> /etc/default/console-setup'
            # XXX Run update-initramfs on ubuntu?
            popd
            ;;
    esac
}


task_uk() {
    case "$1" in
        title)
            echo "UK configuration (wifi, keyboard, etc.)"
            ;;
        default)
            echo 1
            ;;
        after)
            echo task_kmscon
            ;;
        postinst)
            sudo iw reg set GB
            sudo sed -i \
                -e '/^XKBLAYOUT=/ s/=.*$/="gb"/' \
                -e '/^XKBOPTIONS=/ s/=.*$/="ctrl: nocaps"/' \
                /etc/default/keyboard
            if [ -e /etc/kmscon/kmscon.conf ]; then
                sudo sed -i \
                    -e '/#xkb-layout=/ s/.*/xkb-layout=gb/' \
                    -e '/#xkb-options=/ s/.*/xkb-options=ctrl:nocaps/' \
                    -e '/#xkb-repeat-delay=/ s/.*/xkb-repeat-delay=200/' \
                    -e '/#xkb-repeat-rate=/ s/.*/xkb-repeat-rate=25/' \
                    -e '/#no-compose/ s/.*/compose/' \
                    /etc/kmscon/kmscon.conf
            fi
            if [ -x /usr/bin/gsettings ]; then
                gsettings set org.gnome.desktop.input-sources xkb-options "['caps:ctrl_modifier']"
            fi
            ;;
    esac
}


all_tasks() {
    declare -F | sed -e 's/^declare -f //' | grep '^task_'
}


do_task() {
    for task in $(all_tasks); do
        $task "$@"
    done
}


pick_tasks() {
    local width height max_height menu_height tasks titles defaults menu i

    readarray -t tasks < <(all_tasks)
    readarray -t titles < <(do_task title)
    readarray -t defaults < <(do_task default)

    width=$(tput cols)
    width=$((width - 8 < 20 ? width : width - 8))
    width=$((width > 80 ? 80 : width))

    menu_height=${#tasks[*]}
    max_height=$(tput lines)
    height=$((menu_height + 7))

    if (( height > max_height )); then
        height=$((max_height - 2))
        menu_height=$((height - 7))
    fi

    menu=()
    for (( i=0 ; i<${#tasks[*]} ; ++i )); do
        # shellcheck disable=SC2206
        menu+=(${tasks[$i]} "${titles[$i]}" ${defaults[$i]})
    done

    whiptail \
        --title "Dave's Installer" \
        --backtitle "Hostname: $(hostname)" \
        --checklist "Select tasks" $height $width $menu_height "${menu[@]}" \
        --separate-output 3>&1 1>&2 2>&3
}


do_preinst() {
    local task

    for task in "$@"; do
        echo "[1;32m$task preinst[0m" >&2
        $task preinst
    done
}


do_install() {
    local -a packages to_install

    to_install=(htop lsb-release)
    while [ $# -gt 0 ]; do
        while read -r -a packages; do
            to_install+=("${packages[@]}")
        done < <($1 packages)
        shift
    done
    echo "Installing ${to_install[*]}" >&2
    sudo apt update -y
    sudo apt install -y "${to_install[@]}"
}


do_postinst() {
    local task

    mkdir -p "$HOME"/.local/bin

    for task in "$@"; do
        echo "[1;32m$task postinst[0m" >&2
        $task postinst
    done
}


sort_after() {
    # Output the list of all selected tasks ($@) and all their "after" values.
    # Each line of output will be of the form "selected-task after-task". In
    # addition a spurious "all" task which depends on all selected tasks will
    # also be output (this eases the later join).
    #
    # Note that at this point there is no checking that after-task is in the
    # selected list; we'll deal with that later. The output is sorted on the
    # after-task field.

    for task in "$@"; do
        echo all "$task"
        while read -r -a deps; do
            for dep in "${deps[@]}"; do
                echo "$task" "$dep"
            done
        done < <($task after)
    done | sort -k 2
}


sort_selected() {
    # Ouptut the list of all selected tasks in sorted order.

    for task in "$@"; do
        echo "$task"
    done | sort
}


order_tasks() {
    # Join the output of sort_after and sort_selected on the after-task field
    # to eliminate any after-dependencies that aren't selected. Pass the
    # output to tsort to get it in (reverse) dependency order. Filter out
    # the made up "all" task, and finally reverse the order to get the actual
    # execution order which is this function's output.

    join -1 2 -2 1 -o '1.1 1.2' <(sort_after "$@") <(sort_selected "$@") | \
        tsort | grep -v "^all$" | tac
}


main() {
    local -a selected ordered

    readarray -t selected < <(pick_tasks)
    if (( ${#selected[*]} > 0 )); then
        readarray -t ordered < <(order_tasks "${selected[@]}")

        do_preinst "${ordered[@]}"
        do_install "${ordered[@]}"
        do_postinst "${ordered[@]}"
    else
        echo "Install cancelled" >&2
        exit 1
    fi
}

main
