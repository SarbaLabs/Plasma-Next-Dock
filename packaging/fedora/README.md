# Fedora KDE 45 package preview

Install the six runtime RPMs from their download directory on Fedora KDE 45
(x86_64). DNF resolves runtime dependencies from the configured repositories.

```sh
sudo dnf install ./plasma-next-dock-0*.fc45.x86_64.rpm ./plasma-next-dock-module-*-0*.fc45.x86_64.rpm ./plasma-next-dock-module-unpinned-0*.fc45.noarch.rpm
```

The system launcher runs `/usr/bin/plasma-next-dock`. Existing source installs
under `~/.local` can take precedence. Modules can be removed separately, for
example with `sudo dnf remove plasma-next-dock-module-folders`.

## Build from a checkout

Run on Fedora 45 from the Git project root. The archive contains the committed
sources, so the spec in the checkout must match the revision being packaged.

```sh
sudo dnf install rpm-build redhat-rpm-config cmake-rpm-macros dnf5-plugins
spec=packaging/fedora/plasma-next-dock.spec
sudo dnf builddep "$spec"
topdir=$(rpm --eval '%{_topdir}')
base=$(rpmspec -q --srpm --qf '%{NAME}-%{VERSION}' "$spec")
mkdir -p "$topdir/SOURCES"
git archive --format=tar.gz --prefix="$base/" -o "$topdir/SOURCES/$base.tar.gz" HEAD
rpmbuild -ba "$spec"
```

The binary packages land under `RPMS/` in the RPM build tree. The corresponding
source package lands under `SRPMS/`.
