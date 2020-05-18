#!/bin/sh -e
# shellcheck disable=1090,1091

# Bootstrapper for Carbs Linux
# See LICENSE file for copyright and license details

{
    # Source kiss as a library so that we can use pkg_order
    #
    # Get the line number so we can remove the last line
    # that is calling the main function.
    kissloc=$(command -v kiss)
    kissln=$(wc -l < "$kissloc")

    # Save the file on a temporary .kisslib file where we
    # will be reading the library functions.
    sed "${kissln}d" "$kissloc" > .kisslib
    . ./.kisslib
    rm -f .kisslib
}

# Functions
msg() { printf '\033[1;35m-> \033[m%s\n' "$@" ;}
die() { printf '\033[1;31m!> ERROR: \033[m%s\n' "$@" >&2; exit 1 ;}


# Let's get current working directory
BASEDIR="$PWD"

# If there is no config file, we copy config.def
# to config. After we make sure config file is
# in place, we source the contents
! [ -e config ] && cp config.def config
. "${0%/*}/config"

# Check whether absolutely required variables are set.
[ "$PKGS" ]   || die "You must set PKGS variable to continue the bootstrapper"
[ "$MNTDIR" ] || die "You must specify fakeroot location 'MNTDIR' in order to continue the bootstrapper"

# Word splitting is intentional here
# shellcheck disable=2086
pkg_order $PKGS

# Print variables from the configuration file
cat <<EOF
Here are the configuration values:

MNTDIR    = $MNTDIR

Build Options
CFLAGS    = $CFLAGS
CXXFLAGS  = $CXXFLAGS
MAKEFLAGS = $MAKEFLAGS

Repository and package options

REPO      = $REPO
REPOSITORY PATH = $HOST_REPO_PATH
PKGS      = $PKGS
ORDER     = $order

EOF

# If there is NOCONFIRM, skip the prompt.
[ "$NOCONFIRM" ] || {
    printf '\033[1;33m?> \033[mDo you want to start the bootstrapper? (y/N)\n'
    read -r ans
    case "$ans" in [Yy]*|'') ;; *) die "User exited" ; esac
}

# Script starts here

msg "Starting Script..."
msg "Setting KISS_ROOT to $MNTDIR"
export KISS_ROOT="$MNTDIR"

# Check whether REPO and REPO_PATH variables exist
[ "$REPO" ] || die "REPO variable is not set"

# Create parent directories for the repositories, and
# remove pre-existing repositories. We then shallow
# clone the repositories to both locations.
msg "Cloning repository"
mkdir -p "$MNTDIR/var/db/kiss" /tmp
rm -rf /tmp/repo "$MNTDIR/var/db/kiss/repo"
git clone --depth 1 "$REPO" /tmp/repo
cp -r /tmp/repo "$MNTDIR/var/db/kiss/repo"

# Install extra repositories defined in a 'repositories'
# file if it exists. The file is formed by these three
# space seperated sections:
#
# 1: URI of git repository
# 2: The location where the repository will be cloned.
# 3: Options for the git clone, space seperation is not important.
#
[ -f repositories ] &&
while read -r repourl repodir gitopts; do
    # We already die if MNTDIR doesn't exist
    # shellcheck disable=2115
    rm -rf "$MNTDIR/$repodir"
    mkdir -p "$MNTDIR/${repodir%/*}"

    # We want word splitting here.
    # shellcheck disable=2086
    git clone $gitopts -- "$repourl" "$MNTDIR/$repodir"
done < repositories


# We export the new KISS_PATH
export KISS_PATH="${HOST_REPO_PATH:-/tmp/repo/core}"

msg "Starting build from the PKGS variable"


# shellcheck disable=2154
for pkg in $order; do
    # Get the package directory so we can get version
    # and release numbers.
    pkgdir=$(kiss s "$pkg" | sed 1q)
    read -r ver rel < "$pkgdir/version"

    # Check if the package is already installed and skip.
    [ "$(kiss l "$pkg")" = "$pkg $ver $rel" ] && continue

    # Check if a prebuild tarball exists, build the package
    # if it doesn't exist.
    #
    # pkg_order should be dealing with packages in a way that
    # no prompts are asked, but let's not take any chances
    # either.
    [ -f "${XDG_CONFIG_HOME:-$HOME/.cache}/kiss/bin/$pkg#$ver-$rel.tar.${KISS_COMPRESS:-gz}" ] ||
        KISS_NOPROMPT=1 kiss b "$pkg"
    KISS_NOPROMPT=1 kiss i "$pkg"
done

# You can check out about post-installation 
# from the configuration file
msg "Installation Complete, starting custombuild procedure if there is one"
postinstall

msg "Generating rootfs to $BASEDIR"
(
    cd "$MNTDIR" || die "Could not change directory to $MNTDIR"
    tar -cpvJf "$BASEDIR/carbs-rootfs-$(date +%Y%m%d)-$(uname -m).tar.xz" .
)
msg "Done!"
