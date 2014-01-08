#!/usr/bin/env bash

set -e

VERSION='0.0.1'

# Real path to this script, temporary working directory
self_path="$(test -L "$0" && readlink "$0" || realpath "$0")"
temp_dir="$(dirname "$(mktemp -u)")/ffoxup"

# Default options
url='http://download.cdn.mozilla.net/pub/mozilla.org/firefox/releases/latest'
install_dir="$HOME/.local/lib/firefox"
symlink="$HOME/.local/bin/firefox"
iconfile="$HOME/.local/share/icons/firefox.png"
desktopfile="$HOME/.local/share/applications/firefox.desktop"
architecture="$(uname -m)"
language="en-US"

# help/documentation
doc="
------------------------------------------------------------
              __  __
             / _|/ _|
            | |_| |_ _____  ___   _ _ __
            |  _|  _/ _ \ \/ / | | | '_ \\
            | | | || (_) >  <| |_| | |_) |
            |_| |_| \___/_/\_\\\\__,_| .__/
                                   | |
                                   |_|

    Installed to: $self_path
    Version: v$VERSION
    License: Public Domain / Unlicensed <http://unlicense.org/>
    Website: <https://github.com/kafene/ffoxup>
    Download base URL: <$url>

    Options:

        -u | --url
            URL to download from.
            This overrides the options for language,
            architecture, and version to download.

        -d | --directory
            Directory to install Firefox to.
            Make sure it is not the same as the symlink!
            Example: -d /usr/local/lib/firefox
            Default: \$HOME/.local/lib/firefox

        -s | --symlink
            Symlink to create to Firefox binary.
            Use 'none' to skip creating a symlink.
            Example: -s /usr/local/bin/firefox
            Default: \$HOME/.local/bin/firefox

        -i | --iconfile
            Icon filename to create.
            Use 'none' to skip creating an icon file.
            Example: -i /usr/local/share/icons/firefox.png
            Default: \$HOME/.local/share/icons/firefox.png

        -D | --desktopfile
            Desktop file to create.
            Use 'none' to skip creating a .desktop file.
            Example: -D /usr/local/share/applications/firefox.desktop
            Default: \$HOME/.local/share/applications/firefox.desktop

        -a | --architecture
            Architecture to download.
            Refer to the download URL for a list of options.
            Example: -a i686
            Default: The result of 'uname -m'

        -l | --language
            Language to download.
            Refer to the download URL for a list of options.
            Example: -l pt-BR
            Default: en-US

        -u | --update
            Perform a self-update.

        --uninstall
            Uninstalls Firefox.
            This will remove the configured symlink file,
            the icon, the .desktop file, and the installation
            directory. It will not remove any configuration
            directories such as \$HOME/.firefox.

        -h | -H | --help
            Print this help message.

        -v | -V | --version
            Display the current program version.
------------------------------------------------------------
"

# .desktop file template
desktopfile_contents="[Desktop Entry]
Version=1.0
Name=Firefox
Comment=Mozilla Firefox
GenericName=Mozilla Firefox
Exec=firefox %u
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=firefox
Categories=Application;Internet;Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;\
application/xml;application/vnd.mozilla.xul+xml;\
application/rss+xml;application/rdf+xml;\
image/gif;image/jpeg;image/png;
StartupNotify=true
StartupWMClass=Firefox
"

# Parse command line options
while [[ "$1" =~ ^- ]]; do
    case "$1" in
        -u | --url)
            shift
            url="$1"
        ;;
        -s | --symlink)
            shift
            symlink="$1"
        ;;
        -d | --directory)
            shift
            install_dir="$(realpath "$1")"
        ;;
        -i | --iconfile)
            shift
            iconfile="$(realpath "$1")"
        ;;
        -D | --desktopfile)
            shift
            desktopfile="$(realpath "$1")"
        ;;
        -a | --architecture)
            shift
            architecture="$1"
        ;;
        -l | --language)
            shift
            language="$1"
        ;;
        -u | --update)
            update_url="https://raw.github.com/kafene/ffoxup/master/ffoxup.sh"
            wget -O "$self_path" "$update_url"
            echo "updated!"
            exit 0
        ;;
        --uninstall)
            do_uninstall=1
        ;;
        -h | -H | --help)
            echo "$doc"
            exit 0
        ;;
        -v | -V | --version)
            echo "ffoxup v$VERSION"
            exit 0; ;;
        *)
            echo "Invalid option: $1"
            exit 1
        ;;
    esac
    shift
done

# trim any trailing `/` off
# usually realpath will take care of this but I'm taking an extra caution.
install_dir="$(echo "$install_dir" | sed -e 's/\/*$//g')"
temp_dir="$(echo "$temp_dir" | sed -e 's/\/*$//g')"

# Uninstall (this is done after options parsed, so the correct files are used.)
if [ -n "$do_uninstall" ]; then
    # Confirm everything
    echo "I am going to execute the following commands:"
    echo "    rm -rf $install_dir/"
    echo "    rm -rf $temp_dir/"
    echo "    rm -f $symlink"
    echo "    rm -f $iconfile"
    echo "    rm -f $desktopfile"

    read -p "Shall I proceed? [y/N] "
    [ -z "$REPLY" ] || [[ ! "$REPLY" =~ ^[Yy]$ ]] && exit 0

    rm -rf "$install_dir/"
    rm -rf "$temp_dir/"
    rm -f "$symlink"
    rm -f "$iconfile"
    rm -f "$desktopfile"
    echo "Firefox has been removed."
    exit 0
fi

# Check program dependencies (except stuff from coreutils/busybox)
dependencies="egrep wget sed tar realpath"
missing=""

for dependency in $dependencies; do
    if ! command -v "$1" >/dev/null "$dependency"; then
        missing="$missing    $dependency\n"
    fi
done

if [ -n "$missing" ]; then
    printf "Missing dependencies:\n$missing"
    exit 1
fi

echo "URL:                $url"
echo "Symlink:            $symlink"
echo "Install Directory:  $install_dir"
echo "Icon file:          $iconfile"
echo "Desktop file:       $desktopfile"
echo "Architecture:       $architecture"
echo "Language:           $language"

# Just before starting stuff that will make some system changes...
read -p "Everything look okay? [Y/n] "
[[ ! "$REPLY" =~ ^[Yy]$ ]] && [ -n "$REPLY" ] && exit 0

# Create temporary directory
mkdir -vp "$temp_dir"

# If user submitted a url and its a tarball then use it
# Otherwise try to detect the latest version from the
# Mozilla CDN directory listing.
if [ -n "$url" ] && [[ "$url" =~ \.tar\.[A-Za-z0-9]{1,5}$ ]]; then
    latest="$(basename "$url")"
    url="$(dirname "$url")/"
else
    url="$url/linux-$architecture/$language/"
    echo "Downloading directory listing ..."

    latest="$(wget -q -O - "$url" \
        | egrep -o 'href="([^"]+).tar.bz2"' \
        | sed -r 's/href="([^"]+)"/\1/')"
fi

if [ -z "$latest" ]; then
    echo "Failed to detect download URL for latest version."
    exit 1
fi

echo "Detected version to download: $latest ..."

# Before making the large download.
read -p "Continue to download Firefox tarball? [Y/n] "
[[ ! "$REPLY" =~ ^[Yy]$ ]] && [ -n "$REPLY" ] && exit 0

# Download, but if the target already exists, resume download instead.
if [ -f "$temp_dir/$latest" ]; then
    wget -c -O "$temp_dir/$latest" "$url/$latest"
else
    wget -O "$temp_dir/$latest" "$url/$latest"
fi

echo "Download complete ..."

if [ ! -f "$temp_dir/$latest" ] || [ ! -s "$temp_dir/$latest" ]; then
    echo "Downloading tarball failed."
    exit 1
fi

echo "Extracting tarball ..."
tar xjf "$temp_dir/$latest" -C "$temp_dir"

# It should contain a single directory called "firefox"
if [ ! -d "$temp_dir/firefox" ]; then
    echo "Failed to find extracted 'firefox' directory."
    exit 1
fi

# Note - neither of these should have a trailing slash for "cp" to work right
echo "Copying the downloaded 'firefox' folder contents to $install_dir ..."
mkdir -vp "$install_dir"
cp -rf "$temp_dir/firefox" "$install_dir"

echo "Making the Firefox binary executable (+x) ..."
chmod +x "$install_dir/firefox"

if [ ! "$symlink" = "none" ]; then
    echo "Removing old symlink ..."
    rm -f "$symlink"
    echo "Creating new symlink ..."
    ln -s "$install_dir/firefox" "$symlink"
fi

if [ ! "$iconfile" == "none" ]; then
    mkdir -vp "$(dirname "$iconfile")"
    echo "Copying Firefox icon to $iconfile ..."
    cp "$install_dir/browser/icons/mozicon128.png" "$iconfile"
fi

if [ ! "$desktopfile" == "none" ]; then
    mkdir -vp "$(dirname "$desktopfile")"
    echo "Creating desktop file ..."
    echo "$desktopfile_contents" > "$desktopfile"
fi

echo "Firefox has been updated."
