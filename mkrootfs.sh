#!/bin/sh -e
# shellcheck disable=1090

# Bootstrapper for Carbs Linux
# See LICENSE file for copyright and license details


# Functions
msg() { printf '\033[1;35m-> \033[m%s\n' "$@" ;}
error() { printf '\033[1;31mERROR: \033[m%s\n' "$@" ;} >&2
die() { error "$1"; exit 1 ;}
ask() { printf '\033[1;33m== %s ==\n(y/N) ' "$1" ; read ans; case "$ans" in [Yy]*) return 0 ;; *) return 1 ;; esac ;}


# Exit if the user is not root
! [ "$(id -u)" -eq 0 ] && die "Please run as root"

# Let's get current working directory
BASEDIR="$PWD"

# If there is no config file, we copy config.def
# to config. After we make sure config file is
# in place, we source the contents
! [ -e config ] && cp config.def config
. "$PWD/config"

# Check whether absolutely required variables are set.
[ -n "$PKGS" ] || die "You must set PKGS variable to continue the bootstrapper"
[ -n "$MNTDIR" ] || die "You must specify fakeroot location \"MNTDIR\" in order to continue the bootstrapper"


# Print variables from the configuration file
cat <<EOF
Here are the configuration values:

MNTDIR = $MNTDIR

Build Options
CFLAGS = $CFLAGS
CXXFLAGS = $CXXFLAGS
MAKEFLAGS = $MAKEFLAGS

Repository and package options

REPO = $REPO
REPOSITORY PATH = $HOST_REPO_PATH
PKGS = $PKGS

EOF

# Check if there is no NOWELCOME variable set in
# the configuration file. If there is such variable
# set in the configuration, the bootstrapper will 
# start immediately
[ "$NOCONFIRM" ] || {
    ask "Do you want to start the bootstrapper?" || die "User exited"
}

# Script starts here

msg "Starting Script..."
msg "Setting KISS_ROOT to $MNTDIR"
export KISS_ROOT="$MNTDIR"

# Check whether REPO and REPO_PATH variables exist
[ "$REPO" ] && {
    # Remove if /tmp/repo already exists
    rm -rf /tmp/repo
    git clone --depth 1 "$REPO" /tmp/repo
    msg "Cloning repository to /var/db/kiss/repo"
    rm -rf "$MNTDIR/var/db/kiss/repo"
    git clone --depth 1 "$REPO" "$MNTDIR/var/db/kiss/repo"
    export KISS_PATH="${HOST_REPO_PATH:-/tmp/repo/core}"
} || die "REPO variable is not set"

msg "Starting build from the PKGS variable"

# Word Splitting is intentional here, as we are
# passing package names seperately
# shellcheck disable=SC2086
{
    yes '' | KISS_ASROOT=1 kiss b $PKGS
    yes '' | KISS_ASROOT=1 kiss i $PKGS
}

# You can check out about post-installation 
# from the configuration file
msg "Installation Complete, starting custombuild procedure if there is one"
postinstall

# Remove junk from the rootfs
msg "Cleaning package cache"
rm -rf "$MNTDIR/root/.cache"

msg "Generating rootfs to $BASEDIR"
cd "$MNTDIR" || die "Could not change directory to $MNTDIR"
tar -cpvJf "$BASEDIR/carbs-rootfs-$(date +%Y%m%d).tar.xz" .
cd "$BASEDIR" || die "Could not change directory to $BASEDIR"
msg "Done!"
