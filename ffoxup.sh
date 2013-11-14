#!/usr/bin/env bash

set -e

is_executable() {
    command -v "$1" >/dev/null
}

check_dependencies() {
    local missing=""
    for dependency in ${@}; do
        if ! is_executable "$dependency"; then
            missing="$missing    $dependency\n"
        fi
    done
    if test -n "$missing"; then
        printf "Missing dependencies:\n$missing"
        exit 1
    fi
}

ensure_user_wishes_to_continue() {
    read -p "Continue? [Y/n] "
    if [[ ! "$REPLY" =~ ^[Yy]$ ]] && [ -n "$REPLY" ]; then
        echo "Okay, nevermind."
        exit
    fi
}

create_directory() {
    if test ! -d "$1"; then
        mkdir -p "$1"
        echo "mkdir: created directory \`$1\`"
    fi
}

file_exists() {
    test -f "$1"
}

file_is_not_empty() {
    test -s "$1"
}

is_directory() {
    test -d "$1"
}

is_empty() {
    test -z "$1"
}

download_or_resume() {
    if file_exists "$1"; then
        wget -c -O "$1" "$2"
    else
        wget -O "$1" "$2"
    fi
}

display_version() {
    echo "$this v$VERSION"
}

display_help_message() {
    echo "------------------------------------------------------------
              __  __
             / _|/ _|
            | |_| |_ _____  ___   _ _ __
            |  _|  _/ _ \ \/ / | | | '_ \\
            | | | || (_) >  <| |_| | |_) |
            |_| |_| \___/_/\_\\\\__,_| .__/
                                   | |
                                   |_|

    Installed to: $self
    Version: $(display_version)
    License: Public Domain / Unlicensed <http://unlicense.org/>
    Website: <https://github.com/kafene/$this>
    Download URL: <$url>

    Options:

        -u | --url
            URL to download from.
            This overrides the options for language,
            architecture, and version to download.

        -d | --directory
            Directory to install Firefox to.
            Make sure it is not the same as the symlink!
            Example: -d /usr/local/lib/firefox
            Default: $HOME/.local/lib/firefox

        -s | --symlink
            Symlink to create to Firefox binary.
            Use 'none' to skip creating a symlink.
            Example: -s /usr/local/bin/firefox
            Default: $HOME/.local/bin/firefox

        -i | --iconfile
            Icon filename to create.
            Use 'none' to skip creating an icon file.
            Example: -i /usr/local/share/icons/firefox.png
            Default: $HOME/.local/share/icons/firefox.png

        -D | --desktopfile
            Desktop file to create.
            Use 'none' to skip creating a .desktop file.
            Example: -D /usr/local/share/applications/firefox.desktop
            Default: $HOME/.local/share/applications/firefox.desktop

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

        -h | -H | --help
            Print this help message.

        -v | -V | --version
            Display the current program version."
    echo "------------------------------------------------------------"
    exit 0
}

do_self_update() {
    echo "Updating $self ..."
    download_or_resume "$self" "$update_url"
    echo "$this has been updated."
    exit 0
}

parse_command_line_options() {
    while [[ "$1" =~ ^- ]]; do
        case "$1" in
            -u | --url) shift; url="$1"; ;;
            -s | --symlink) shift; symlink="$1"; ;;
            -d | --directory) shift; directory=$($rp "$1"); ;;
            -i | --iconfile) shift; iconfile=$($rp "$1"); ;;
            -D | --desktopfile) shift; desktopfile=$($rp "$1"); ;;
            -a | --architecture) shift; architecture="$1"; ;;
            -l | --language) shift; language="$1"; ;;
            -u | --update) do_self_update; exit 0; ;;
            -h | -H | --help) display_help_message; exit 0; ;;
            -v | -V | --version) display_version; exit 0; ;;
            *) echo "Invalid option: $1"; exit 1; ;;
        esac
        shift
    done
}

show_current_state() {
    echo "URL: $url"
    echo "Symlink: $symlink"
    echo "Directory: $directory"
    echo "Icon file: $iconfile"
    echo "Desktop file: $desktopfile"
    echo "Architecture: $architecture"
    echo "Language: $language"
}

create_temporary_working_directory() {
    create_directory "$tempdir"
}

full_url_was_given_by_user() {
    is_empty $url && [[ "$url" =~ \.tar\.(bz2|gz)$ ]]
}

detect_latest_version_from_full_url() {
    latest=$(basename "$url")
}

detect_base_url_from_full_url() {
    url=$(dirname "$url")
}

detect_latest_version() {
    url="$url/linux-$architecture/$language/"
    echo "Downloading directory listing from $url ..."
    latest=$(download_or_resume - "$url" \
        | egrep -o 'href="([^"]+).tar.bz2"' \
        | sed -r 's/href="([^"]+)"/\1/')
}

ensure_latest_version_detected_properly() {
    if is_empty "$latest"; then
        echo "Failed to detect file to download."
        exit 1
    fi
}

download_tarball() {
    echo "URL: $url/$latest ..."
    echo "Downloading tarball ($latest) ..."
    ensure_user_wishes_to_continue
    echo "Downloading. Please stand by ..."
    download_or_resume "$tempdir/$latest" "$url/$latest"
    echo "Download complete ..."
}

ensure_tarball_downloaded_correctly() {
    if ! file_exists "$tempdir/$latest" \
    || ! file_is_not_empty "$tempdir/$latest"; then
        echo "Downloading tarball failed."
        exit 1
    fi
}

extract_tarball() {
    echo "Extracting tarball ..."
    tar xjf "$tempdir/$latest" -C "$tempdir"
}

ensure_tarball_extracted_correctly() {
    # It should contain a single directory called "firefox"
    if ! is_directory "$tempdir/firefox"; then
        echo "Failed to find extracted 'firefox' directory."
        exit 1
    fi
}

move_extracted_folder_to_installation_directory() {
    echo "Removing previous Firefox program folder ($directory) ..."
    rm -rf "$directory/"
    echo "Installing new Firefox program folder ($directory) ..."
    create_directory $(dirname "$directory")
    mv "$tempdir/firefox/" "$directory"
}

make_program_executable_executable() {
    echo "Making the Firefox executable executable ..."
    chmod +x "$directory/firefox"
}

should_create() {
    test ! "$1" == "none"
}

create_symlink() {
    if should_create "$symlink"; then
        echo "Removing old symlink ..."
        rm -f "$symlink"
        echo "Creating new symlink ..."
        ln -s "$directory/firefox" "$symlink"
    fi
}

create_icon_file() {
    if should_create "$iconfile"; then
        create_directory $(dirname "$iconfile")
        echo "Copying Firefox icon to $iconfile ..."
        cp "$directory/browser/icons/mozicon128.png" "$iconfile"
    fi
}

create_desktop_file() {
    if should_create "$desktopfile"; then
        create_directory $(dirname "$desktopfile")
        echo "Creating desktop file ..."
        echo "$desktopfile_contents" > "$desktopfile"
    fi
}

rollback_installation() {
    rm -rf "$tempdir"
    rm -rf "$directory"
    rm -f "$symlink"
    rm -f "$iconfile"
    rm -f "$desktopfile"
}

VERSION='0.0.1'

# Not all systems have realpath? Hope they have busybox then...
is_executable realpath && rp="realpath" || rp="busybox realpath"

# Check other dependencies (except stuff in coreutils/busybox)
check_dependencies egrep wget sed tar

# vars
this='ffoxup'
self=$(test -L "$0" && readlink "$0" || $rp "$0")
update_url="https://raw.github.com/kafene/$this/master/ffoxup.sh"
tempdir="$(dirname $(mktemp -u))/$this"
latest=""

# Default options
url='http://download.cdn.mozilla.net/pub/mozilla.org/firefox/releases/latest'
directory="$HOME/.local/lib/firefox"
symlink="$HOME/.local/bin/firefox"
iconfile="$HOME/.local/share/icons/firefox.png"
desktopfile="$HOME/.local/share/applications/firefox.desktop"
architecture="$(uname -m)"
language="en-US"

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
StartupWMClass=Firefox"

parse_command_line_options "$@"
show_current_state
ensure_user_wishes_to_continue
create_temporary_working_directory

if full_url_was_given_by_user; then
    detect_latest_version_from_full_url
    detect_base_url_from_full_url
else
    detect_latest_version
    ensure_latest_version_detected_properly
fi

download_tarball
ensure_tarball_downloaded_correctly
extract_tarball
ensure_tarball_extracted_correctly
move_extracted_folder_to_installation_directory
make_program_executable_executable
create_symlink
create_icon_file
create_desktop_file

echo "Firefox has been updated."
