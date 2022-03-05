# mkrootfs

Is a tool for generating rootfs tarballs for KISS Linux. But it can be configured to
create tarballs for KISS forks, or even to create a personalized pre-configured
tarball with an Xorg server to ease installation process.


## configuration

Configuration can be done by copying config.def file to config. There you can
configure where the rootfs will be created, packages to be installed, CFLAGS,
MAKEFLAGS, repository to be added, and the `KISS_PATH` to be used.


## extra repositories

The script by default only installs a single repository, but can accept a file
named 'repositories' to add additional repositories to the target system. This
file is structured in a plaintext manner and has 3 seperate sections.

1. Git URL
2. Target location
3. Git clone options (such as --depth 1)

Here is an example repositories file. The local repository is for example
purposes, don't actually use local repositories.

```
https://git.u.com/repo1 /var/db/kiss/personalrepo --depth 1
/home/user/kiss-repo2   /var/db/kiss/kiss-repo2   --no-local --depth 2
```

You can then add these to your KISS_PATH by editing the config file and adding
the following to your `HOST_REPO_PATH`.

```sh
HOST_REPO_PATH="/tmp/repo/core:$MNTDIR/var/db/kiss/personalrepo:$MNTDIR/var/db/kiss/kiss-repo2"
```

## postinstall

You can change the postinstall (which defaults to true) function to make manual
changes to the generated root filesystem.
