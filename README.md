ffoxup
======

firefox updater in bash

it automatically detects the latest version.

if mozilla changes their directory structure or CDN url,
this could break things, but for now it works.

see `ffoxup.sh` for details, including help doc.

quick install:

```bash
wget -O "$HOME/.local/bin/ffoxup" "https://raw.github.com/kafene/ffoxup/master/ffoxup.sh"; chmod +x "$HOME/.local/bin/ffoxup"
```
