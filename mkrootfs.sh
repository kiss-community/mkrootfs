#!/bin/sh -e
# shellcheck disable=1090,1091

# Bootstrapper for KISS Linux
# See LICENSE file for copyright and license details

# Functions
msg() { printf '\033[1;35m-> \033[m%s\n' "$@" ;}
die() { printf '\033[1;31m!> ERROR: \033[m%s\n' "$@" >&2; exit 1 ;}

# If there is no config file, we copy config.def
# to config. After we make sure config file is
# in place, we source the contents
! [ -e config ] && cp config.def config
. "${0%/*}/config"

msg "Checking to see if the environment can bootstrap successfully..."
checkenv

# Let's get current working directory
BASEDIR="$PWD"

# Check whether absolutely required variables are set.
[ "$PKGS" ]    || die "You must set PKGS variable to continue the bootstrapper"
[ "$MNTDIR" ]  || die "You must specify fakeroot location 'MNTDIR' in order to continue the bootstrapper"
[ "$TARBALL" ] || die "You must specify the TARBALL variable to continue the bootstrapper"

# Print variables from the configuration file
# shellcheck disable=2154
cat <<EOF
Here are the configuration values:

MNTDIR    = $MNTDIR

Build Options
CFLAGS    = $CFLAGS
CXXFLAGS  = $CXXFLAGS
MAKEFLAGS = $MAKEFLAGS

Repository and package options

REPO            = $REPO
HOST REPO PATH  = $HOST_REPO
REPOS ENABLED   = $HOST_REPO_PATH
PKGS            = $PKGS

Tarball will be written as:
$BASEDIR/$TARBALL

EOF

# If there is NOCONFIRM, skip the prompt.
[ "$NOCONFIRM" ] || {
    printf '\033[1;33m?> \033[mDo you want to start the bootstrapper? (Y/n)\n'
    read -r ans
    case "$ans" in [Yy]*|'') ;; *) die "User exited" ; esac
}

# Script starts here

msg "Starting Script..."
# Save the time that we started the bootstrapper.
awk 'BEGIN { srand(); print srand() }' > "$BASEDIR/starttime"
msg "Setting KISS_ROOT to $MNTDIR"
export KISS_ROOT="$MNTDIR"

# Check whether REPO and REPO_PATH variables exist
[ "$REPO" ] || die "REPO variable is not set"

mkdir -p "$MNTDIR/var/db/kiss" /tmp
rm -rf "$HOST_REPO" "$MNTDIR/var/db/kiss/repo"
# Create parent directories for the repositories, and
# remove pre-existing repositories. We then shallow
# clone the repositories to both locations.
case $REPO in
    git+*)
        msg "Cloning repository"
        git clone --depth 1 "${REPO##*+}" "$HOST_REPO"
    ;;
    local+*)
        msg "Copying repository"
        cp -r "${REPO##*+}" "$HOST_REPO"
    ;;
esac
cp -r "$HOST_REPO" "$MNTDIR/var/db/kiss/repo"

msg "Repo Download Complete, starting 'postrepodown' procedure if there is one"
(
    cd "$HOST_REPO"
    postrepodown
)

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
export KISS_PATH="${HOST_REPO_PATH:-$HOST_REPO/core}"

msg "Starting build from the PKGS variable"

# shellcheck disable=2154
for pkg in $PKGS; do
    # Get the package directory so we can get version
    # and release numbers.
    pkgdir=$(kiss search "$pkg" | sed 1q)
    read -r ver rel < "$pkgdir/version"

    # Check if the package is already installed and skip.
    [ "$(kiss list "$pkg")" = "$pkg $ver-$rel" ] && continue

    # Build and install every package explicitly.
    # While not ideal, this keeps forked packages, as well as
    # ones built with potentially different CFLAGS from polluting
    # the tarball.
    KISS_PROMPT=0 kiss build "$pkg"
    KISS_PROMPT=0 kiss install "$pkg"
done

# You can check out about post-installation
# from the configuration file
msg "Installation Complete, starting 'postinstall' procedure if there is one"
postinstall

msg "Generating rootfs to $BASEDIR"
(
    cd "$MNTDIR" || die "Could not change directory to $MNTDIR"
    tar -cJf "$BASEDIR/$TARBALL" .
)

msg "Generating Checksums"
b3sum "$BASEDIR/$TARBALL" > "$BASEDIR/$TARBALL.b3sum"

msg "Done!"

read -r stime < "$BASEDIR/starttime"
rm "${BASEDIR:?}/starttime"
etime=$(awk 'BEGIN { srand(); print srand() }')
elapsed_sec=$((etime - stime))
elapsed_min=$((elapsed_sec / 60))
elapsed_hrs=$((elapsed_min / 60))
elapsed_sec=$((elapsed_sec % 60))
elapsed_min=$((elapsed_min % 60))
msg "Took ${elapsed_hrs}h.${elapsed_min}m.${elapsed_sec}s"
