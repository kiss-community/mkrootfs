#!/bin/sh -e
# Bootstrapper for Carbs Linux
# See LICENSE file for copyright and license details


# Functions
out() { printf "%s\\n" "$@" ;}
msg() { printf "\033[1;35m=>\033[m $1\\n" ;}
error() { msg "\033[1;31mERROR: \033[m$1" ;} >&2
die() { error "$1"; exit 1 ;}
ask() { printf "\033[1;33m== $1 ==\\n(y/N) "; read ans; case "$ans" in [Yy]*) return 0 ;; *) return 1 ;; esac ;}
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
out \
"Here are the configuration values:" \
"" \
"MNTDIR = $MNTDIR" \
"" \
"Build Options" \
"CFLAGS = $CFLAGS" \
"CXXFLAGS = $CXXFLAGS" \
"MAKEFLAGS = $MAKEFLAGS" \
"" \
"Repository and package options" \
"" \
"REPO = $REPO" \
"REPOSITORY PATH = $REPO_PATH" \
"PKGS = $PKGS"


# Check if there is no NOWELCOME variable set in
# the configuration file. If there is such variable
# set in the configuration, the bootstrapper will 
# start immediately
if [ -z "$NOCONFIRM" ]; then
	ask "Do you want to start the bootstrapper?" || die "User exited"
else
	msg "NOCONFIRM variable exists, starting without asking."
fi


# Script starts here

msg "Starting Script..."

msg "Setting KISS_ROOT to $MNTDIR"
export KISS_ROOT="$MNTDIR"

# Check whether REPO and REPO_PATH variables exist
if [ -n "$REPO" ]; then
	# Remove if /tmp/repo already exists
	rm -rf /tmp/repo
	git clone --depth 1 "$REPO" /tmp/repo
	msg "Cloning repository to /var/db/kiss/repo"
	git clone "$REPO" "$MNTDIR/var/db/kiss/repo"
	export KISS_PATH="${HOST_REPO_PATH:-/tmp/repo/core}"
else
	msg "REPO variable does not exist, current repository
will be copied directly to the root filesystem"
fi

msg "Starting build from the PKGS variable"

# Word Splitting is intentional here, as we are
# passing package names seperately
# shellcheck disable=SC2086
kiss b $PKGS
msg "Package build complete, starting package installation"
# shellcheck disable=SC2086
kiss i $PKGS
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
