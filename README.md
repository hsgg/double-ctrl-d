# double-ctrl-d

Claude-code ignores the standard interface where a single Ctrl+D on an empty
line exits the application. Instead, claude-code's "press ctrl+d again to exit"
confirmation is hardcoded and can't be rebound via `keybindings.json`. The
script `double-ctrl-d.sh` wraps `claude` in a pty and sends every Ctrl+D you
type twice, so a single Ctrl+D exits like it does in any other TUI.

## Requirements

- `expect` (e.g. `brew install expect` on macOS, `apt install expect` on Debian/Ubuntu)
- `claude` (claude-code) already installed and in `PATH`

## Install

The script is meant to be called `claude` and found before the real claude.
The script finds the real `claude` binary by scanning `PATH` and skipping
itself.

```sh
mkdir -p ~/bin
cp double-ctrl-d.sh ~/bin/claude
chmod +x ~/bin/claude
```

Make sure `~/bin` comes before the real claude-code install directory in
`PATH`. Verify with:

```sh
which -a claude
```

You may need to `hash -r` or restart your shell first.

You should see the shim (`~/bin/claude`) listed first, and the real binary
after it.
