ffoxup
======

firefox updater in bash

it automatically detects the latest version.

if mozilla changes their directory structure or CDN url,
this could break things, but for now it works.

see `ffoxup.sh` for details, including help doc.

quick install:

```bash
o="$HOME/.local/bin/ffoxup";wget -O "$o" "https://raw.github.com/kafene/ffoxup/master/ffoxup.sh"; chmod +x "$o"
```
