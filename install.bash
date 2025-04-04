#!/bin/bash

set -eu

DESTDIR=/usr/local
CONFDIR=/etc
XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-${HOME}/.config}
DISTRO=$(lsb_release -is)
RELEASE=$(lsb_release -rs)
case "$DISTRO" in
    (Ubuntu)
        BOOT=/boot/firmware
        ;;
    (*)
        BOOT=/boot
        ;;
esac
UPDATE_INITRAMFS=0
REBOOT_REQUIRED=0


task_apt() {
    case "$1" in
        title)
            echo "Do full apt upgrade"
            ;;
        default)
            echo 1
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
            echo 0
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
            DIFF_HIGHLIGHT=/usr/share/doc/git/contrib/diff-highlight
            if [ -d "$DIFF_HIGHLIGHT" ] && ! [ -e "$DIFF_HIGHLIGHT"/diff-highlight ]; then
                sudo make -C "$DIFF_HIGHLIGHT"
            fi
            ;;
    esac
}


task_mcu() {
    case "$1" in
        title)
            echo "Install microcontroller tools (dtc, mpremote, ...)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo dfu-util dfu-programmer avrdude avr-libc device-tree-compiler
            echo gcc-arm-none-eabi gdbserver hexdiff hexcurse lrzsz i2c-tools
            if apt-cache show pyboard-rshell >/dev/null 2>&1; then
                echo pyboard-rshell
            fi
            if apt-cache show micropython-mpremote >/dev/null 2>&1; then
                echo micropython-mpremote
            fi
            ;;
    esac
}


task_doc() {
    case "$1" in
        title)
            echo "Install documentation tools (sphinx, graphviz, ...)"
            ;;
        default)
            echo 0
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
            echo ubuntu-dev-tools packaging-dev sbuild shellcheck dput-ng
            echo python3-colorzero python3-dateutil
            ;;
        postinst)
            ln -sf "$HOME"/dotfiles/gbp.conf "$HOME"/.gbp.conf
            ln -sf "$HOME"/dotfiles/quiltrc-dpkg "$HOME"/.quiltrc-dpkg
            ln -sfn "$HOME"/dotfiles/dput.d "$HOME"/.dput.d
            ln -sf "$HOME"/dotfiles/sbuildrc "$HOME"/.sbuildrc
            ln -sf "$HOME"/dotfiles/mk-sbuildrc "$HOME"/.mk-sbuild.rc
            ln -sf "$HOME"/dotfiles/reportbugrc "$HOME"/.reportbugrc
            sudo install "$HOME"/dotfiles/merge "$DESTDIR"/bin/
            sudo install "$HOME"/dotfiles/enable-proposed "$DESTDIR"/bin/
            sudo install "$HOME"/dotfiles/sync-images "$DESTDIR"/bin/
            sudo install "$HOME"/dotfiles/get-patches "$DESTDIR"/bin/
            sudo install "$HOME"/dotfiles/get-livefs "$DESTDIR"/bin/
            sudo install "$HOME"/dotfiles/get-uploads "$DESTDIR"/bin/
            sudo install "$HOME"/dotfiles/sbuildwrap "$DESTDIR"/bin/
            ;;
    esac
}


task_travel() {
    case "$1" in
        title)
            echo "Install travel tools (bt-tether, dot-ip, setfor)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo bluez dbus python3-netifaces
            if grep -q "Raspberry Pi" /proc/cpuinfo; then
                echo python3-colorzero python3-dot3k python3-smbus
                echo python3-libgpiod
                if [ "$DISTRO" = "Ubuntu" ]; then
                    if [[ "$RELEASE" < "24.04" ]]; then
                        echo python3-rpi.gpio
                    else
                        echo python3-rpi-lgpio
                    fi
                fi
            fi
            ;;
        preinst)
            if grep -q "Raspberry Pi" /proc/cpuinfo; then
                if [ "$DISTRO" = "Ubuntu" ]; then
                    sudo add-apt-repository -y ppa:waveform/collator
                fi
            fi
            ;;
        postinst)
            sudo install "$HOME"/dotfiles/setfor "$DESTDIR"/bin/
            sudo install "$HOME"/dotfiles/bt-tether "$DESTDIR"/bin/
            if grep -q "Raspberry Pi" /proc/cpuinfo; then
                sudo install "$HOME"/dotfiles/dot-ip "$DESTDIR"/bin/
                sudo install --mode 644 "$HOME"/dotfiles/dot-ip.service "$CONFDIR"/systemd/system/
                sudo systemctl daemon-reload
            fi
            ;;
    esac
}


task_db() {
    case "$1" in
        title)
            echo "Install db tools (sqlite3, pg-client)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo sqlite3 postgresql-client sc jq
            if apt-cache show pspg >/dev/null 2>&1; then
                echo pspg
            fi
            ;;
        postinst)
            ln -sf "$HOME"/dotfiles/psqlrc "$HOME"/.psqlrc
            ln -sf "$HOME"/dotfiles/sqliterc "$HOME"/.sqliterc
            ;;
    esac
}


task_py() {
    case "$1" in
        title)
            echo "Install Python stuff (ipython, jupyter, libs)"
            ;;
        default)
            echo 0
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


task_mutt() {
    case "$1" in
        title)
            echo "Install e-mail client (mutt, notmuch, isync)"
            ;;
        default)
            echo 0
            ;;
        after)
            echo task_sendmail
            ;;
        packages)
            echo isync neomutt notmuch abook
            ;;
        postinst)
            mkdir -p "$HOME"/.mail/{home,work}
            mkdir -p "$HOME"/.cache/mutt/{home,work}
            sudo install "$HOME"/dotfiles/mailfilter "$DESTDIR"/bin/
            ln -sf "$HOME"/dotfiles/mbsyncrc "$HOME"/.mbsyncrc
            ln -sf "$HOME"/dotfiles/notmuch-home "$HOME"/.mail/home/.notmuch-config
            ln -sf "$HOME"/dotfiles/notmuch-work "$HOME"/.mail/work/.notmuch-config
            ln -sf "$HOME"/dotfiles/mailcap "$HOME"/.mailcap
            mkdir -p "$XDG_CONFIG_HOME"/systemd/user/
            ln -sf "$HOME"/dotfiles/mbsync@.service "$XDG_CONFIG_HOME"/systemd/user/
            ln -sf "$HOME"/dotfiles/mbsync@.timer "$XDG_CONFIG_HOME"/systemd/user/
            systemctl enable --user mbsync@home.timer
            systemctl enable --user mbsync@work.timer
            ;;
    esac
}


task_sendmail() {
    case "$1" in
        title)
            echo "Install e-mail sender (msmtp)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo msmtp-mta
            ;;
        postinst)
            ln -sf "$HOME"/dotfiles/dot_msmtprc "$HOME"/.msmtprc
            chmod 600 "$HOME"/dotfiles/dot_msmtprc
            ;;
    esac
}


task_fs() {
    case "$1" in
        title)
            echo "Install fs tools (ranger, ncdu, entr, atool)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo atool ncdu entr inotify-tools ranger shed mc lz4 zstd
            echo p7zip-full moreutils python3-ruamel.yaml lsscsi
            ;;
        postinst)
            mkdir -p "$XDG_CONFIG_HOME"/ranger
            ln -sf "$HOME"/dotfiles/ranger.conf "$XDG_CONFIG_HOME"/ranger/rc.conf
            if apt-cache show bat >/dev/null 2>&1; then
                ranger --copy-config=scope || true
                sed -i -e 's/\bbat\b/batcat/' "$XDG_CONFIG_HOME"/ranger/scope.sh
            fi
            sudo install -d "$DESTDIR"/share/dotfiles
            sudo install -m 644 "$HOME"/dotfiles/functions.bash "$DESTDIR"/share/dotfiles/
            sudo install "$HOME"/dotfiles/flashcard "$DESTDIR"/bin/
            sudo install "$HOME"/dotfiles/mountcard "$DESTDIR"/bin/
            sudo install "$HOME"/dotfiles/customizecard "$DESTDIR"/bin/
            ;;
    esac
}


task_net() {
    case "$1" in
        title)
            echo "Install net tools (curl, w3m, elinks, zsync)"
            ;;
        default)
            echo 0
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
            echo 0
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
        postinst)
            sudo install "$HOME"/dotfiles/sync-dory "$DESTDIR"/bin/
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
            if [ "$DISTRO" = "Ubuntu" ]; then
                # kmscon is already packaged in kinetic onwards
                if [[ "$RELEASE" < "22.10" ]]; then
                    sudo add-apt-repository -y ppa:waveform/kmscon
                fi
            else
                cat << EOF | sudo sh -c 'cat > /etc/apt/sources.list.d/kmscon.list'
deb http://ppa.launchpad.net/waveform/kmscon/ubuntu hirsute main
# deb-src http://ppa.launchpad.net/waveform/kmscon/ubuntu hirsute main
EOF
            fi
            ;;
        postinst)
            sudo mkdir -p /etc/kmscon
            cat << EOF | sudo sh -c 'cat >> /etc/kmscon/kmscon.conf'
xkb-repeat-delay=200
xkb-repeat-rate=25

drm

font-name=Ubuntu Mono
font-size=14
EOF
            REBOOT_REQUIRED=1
            ;;
    esac
}


task_tmux() {
    case "$1" in
        title)
            echo "Install & configure tmux"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo byobu tmux python3-cbor2
            if grep -q "Raspberry Pi" /proc/cpuinfo; then
                echo python3-smbus python3-libgpiod
            fi
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
            echo 0
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
            [ -d "$vim_pack"/vim-flavored-markdown ] || git clone https://github.com/jtratner/vim-flavored-markdown.git "$vim_pack"/vim-flavored-markdown
            #git clone https://github.com/Vimjas/vim-python-pep8-indent "$vim_pack"/vim-python-pep8-indent
            #git clone https://github.com/mg979/vim-visual-multi "$vim_pack"/vim-visual-multi
            sudo update-alternatives --set editor "${vim_path}"
            ;;
    esac
}


task_gui() {
    case "$1" in
        title)
            echo "Install GUI applications"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo keepassxc remmina quassel-client rhythmbox vlc
            echo gimp inkscape fritzing calibre ghex jupyter-notebook wxmaxima
            echo simple-scan openscad librecad imagemagick meld git-gui gitk
            echo gobby veusz wireshark xdot usb-creator-gtk gnome-games
            echo wl-clipboard
            ;;
    esac
}


task_zsh() {
    case "$1" in
        title)
            echo "Install & configure zsh"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo zsh direnv fzy
            ;;
        postinst)
            ln -sf "$HOME"/dotfiles/zshrc "$HOME"/.zshrc
            sudo chsh -s /usr/bin/zsh "$USER"
            pushd "$(mktemp -d)"
            git clone https://github.com/powerline/fonts
            sudo cp fonts/Terminus/PSF/*.psf.gz /usr/share/consolefonts/
            popd
            rm -fr "$OLDPWD"
            sudo sh -c 'echo FONT="/usr/share/consolefonts/ter-powerline-v16b.psf.gz" >> /etc/default/console-setup'
            zsh_plugins="$HOME"/.zsh
            mkdir -p "$zsh_plugins" "$zsh_plugins"/themes
            [ -d "$zsh_plugins"/agnoster-zsh-theme ] || git clone https://github.com/agnoster/agnoster-zsh-theme "$zsh_plugins"/agnoster-zsh-theme
            [ -d "$zsh_plugins"/git-aliases ] || git clone https://github.com/mdumitru/git-aliases "$zsh_plugins"/git-aliases
            [ -d "$zsh_plugins"/zsh-fzy ] || git clone https://github.com/aperezdc/zsh-fzy "$zsh_plugins"/zsh-fzy
            ln -sf "$zsh_plugins"/agnoster-zsh-theme/agnoster.zsh-theme "$zsh_plugins"/themes/prompt_agnoster_setup
            UPDATE_INITRAMFS=1
            REBOOT_REQUIRED=1
            ;;
    esac
}


task_uk() {
    case "$1" in
        title)
            echo "UK configuration (wifi, keyboard, etc.)"
            ;;
        default)
            echo 0
            ;;
        packages)
            echo iw
            if [ "$DISTRO" = "Ubuntu" ]; then
                if [[ "$RELEASE" > "22.04" ]]; then
                    echo python3-ruamel.yaml
                fi
            else
                echo raspi-config
            fi
            ;;
        after)
            echo task_kmscon
            ;;
        postinst)
            sudo iw reg set GB
            if [ "$DISTRO" = "Ubuntu" ]; then
                if [[ "$RELEASE" > "22.04" ]]; then
                    sudo python3 - << EOF
from ruamel.yaml import YAML
from pathlib import Path

yaml = YAML()
for conffile in Path('/etc/netplan').glob('*.yaml'):
    with conffile.open('r') as conf:
        old = yaml.load(conf)
    new = old.copy()
    for intf in old.get('network', {}).get('wifis', {}):
        new['network']['wifis'][intf]['regulatory-domain'] = 'GB'
    if old != new:
        with conffile.open('w') as conf:
            yaml.dump(conf, new)
EOF
                elif ! grep -s cfg80211.ieee80211_regdom "$BOOT"/cmdline.txt; then
                    sudo sed -i \
                        -e 's/$/ cfg80211.ieee80211_regdom=GB/' \
                        "$BOOT"/cmdline.txt
                fi
            else
                sudo raspi-config nonint do_wifi_country GB
            fi
            if [ "$DISTRO" = "Ubuntu" ] && [[ "$RELEASE" < "24.04" ]]; then
                sudo localectl set-locale en_GB.UTF-8 || true
                sudo localectl set-x11-keymap gb pc105 "" ctrl:nocaps || true
                UPDATE_INITRAMFS=1
            fi
            if [ -e /etc/default/keyboard ]; then
                sudo sed -i \
                    -e '/^XKBLAYOUT=/ s/=.*$/="gb"/' \
                    -e '/^XKBOPTIONS=/ s/=.*$/="ctrl: nocaps"/' \
                    /etc/default/keyboard
            fi
            if [ -e /etc/kmscon/kmscon.conf ]; then
                cat << EOF | sudo sh -c 'cat >> /etc/kmscon/kmscon.conf'
xkb-model=pc105
xkb-layout=gb
xkb-options=ctrl:nocaps
EOF
                REBOOT_REQUIRED=1
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
    for task in "$@"; do
        while read -r -a packages; do
            to_install+=("${packages[@]}")
        done < <($task packages)
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
        [ "$UPDATE_INITRAMFS" -ne 0 ] && sudo update-initramfs -u
        [ "$REBOOT_REQUIRED" -ne 0 ] && echo "Reboot required" >&2
    else
        echo "Install cancelled" >&2
        exit 1
    fi
}

main
