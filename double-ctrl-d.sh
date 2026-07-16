#!/usr/bin/env bash

# Run claude-code in a pty and send Ctrl+D twice for every Ctrl+D pressed,
# so a single Ctrl+D exits. claude-code's "Press ctrl+d again to exit"
# confirmation is hardcoded (not rebindable via keybindings.json), and
# piping into claude's stdin would drop it into non-interactive print mode,
# so a pseudo-terminal wrapper is the only way to filter keystrokes.
#
# May be symlinked into PATH as `claude`; the real binary is found by
# skipping this script when searching PATH.

#CMD="$(basename "$0")"
CMD="claude"


# find actual executable
EXEC=
SELF="$(realpath "$0")"
while IFS= read -r candidate
do
    if test "$(realpath "$candidate")" != "$SELF"
    then
        EXEC="$candidate"
        break
    fi
done < <(which -a "$CMD")

if test -z "$EXEC"
then
    echo "$0: ERROR no real '$CMD' binary found in PATH" >&2
    exit 1
fi


# claude-code is installed as a brew cask; check at most once a day whether
# a newer version is available and offer to upgrade.
check_for_update() {
    command -v brew >/dev/null 2>&1 || return

    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/double-ctrl-d"
    local cache_file="$cache_dir/last-update-check"
    local now last
    now=$(date +%s)
    last=$(cat "$cache_file" 2>/dev/null || echo 0)

    if (( now - last < 86400 ))
    then
        return
    fi

    mkdir -p "$cache_dir"
    echo "$now" > "$cache_file"

    if brew outdated --cask claude-code --quiet 2>/dev/null | grep -q .
    then
        local reply
        read -r -p "note: a newer claude-code is available — update now? [y/N] " reply < /dev/tty > /dev/tty
        if [[ "$reply" =~ ^[Yy]$ ]]
        then
            brew upgrade --cask claude-code
        fi
    fi
}


# Without a terminal on both ends claude runs non-interactively anyway;
# pass pipes/redirections through untouched.
if ! test -t 0 || ! test -t 1
then
    exec "$EXEC" "$@"
fi

check_for_update

exec expect -f <(cat <<'EOF'
spawn -noecho {*}$argv

# Keep the pty's window size in sync with the real terminal.
proc sync_winsize {} {
    global spawn_out
    stty rows [stty rows] columns [stty columns] < $spawn_out(slave,name)
}
trap sync_winsize WINCH
sync_winsize

# Ctrl+D reaches us in one of three encodings depending on what keyboard
# protocol claude has negotiated with the terminal:
#   legacy:                    0x04
#   kitty protocol (ghostty):  CSI 100;<mods>u
#   xterm modifyOtherKeys:     CSI 27;<mods>;100~
# For the escape encodings, double only if the modifier is exactly ctrl
# (ignoring caps/num lock bits 64/128).
proc ctrl_only {mods} {
    return [expr {(($mods - 1) & ~192) == 4}]
}
interact {
    "\004" { send -- "\004\004" }
    -re {\x1b\[100;([0-9]+)u} {
        set seq $interact_out(0,string)
        send -- $seq
        if {[ctrl_only $interact_out(1,string)]} { send -- $seq }
    }
    -re {\x1b\[27;([0-9]+);100~} {
        set seq $interact_out(0,string)
        send -- $seq
        if {[ctrl_only $interact_out(1,string)]} { send -- $seq }
    }
}

lassign [wait] pid spawnid oserr status
exit $status
EOF
) "$EXEC" "$@"
