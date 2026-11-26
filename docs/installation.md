# Installation and updates

Start with Git and a Plasma Wayland session. Follow [the checkout instructions](../README.md#install-from-source), then run `./install.sh` inside the checkout as your desktop user. The installer reads `ID` and
`ID_LIKE` from os-release to select the distribution's package family. Before
building, it checks the native package database. If dependencies are missing,
it prints their names and suggests a command using APT, DNF, Zypper or
pacman (paru when available to a non-root user). On OSTree-based Fedora it
suggests rpm-ostree. Only names confirmed in local repository metadata appear
in the command. If a name cannot be verified, refresh the metadata or look up
the corresponding dependency in your distribution, then rerun `./install.sh`.

A derivative can inherit these checks even if it has never been tested on
a desktop. For unrecognized families, CMake checks the build dependencies.
The source, CMake build and user installation are shared
across distributions. On small VMs, use `CMAKE_BUILD_PARALLEL_LEVEL=2 ./install.sh`
to limit peak memory use.

## Dependencies by distribution family

All builds need a C++20 toolchain, CMake 3.22 or newer, pkg-config and gettext.
For Qt 6.8 or newer, install the development files for Qt Base (including
private GUI headers), Declarative/Quick, Wayland Client and Shader Tools.
The Wayland adapter also needs libwayland, LayerShellQt and Plasma Wayland
Protocols. If the dock stops launching after a Qt update, rerun the installer to rebuild against the installed private headers.

For the desktop session, use Plasma 6 on Wayland. The dock uses Plasma
Workspace and Desktop, Qt SVG, Qt Quick Controls, Layouts, Dialogs, Shapes
and Effects, Kirigami, Breeze icons, Plasma Audio Volume and KPipeWire.
The build also links KDE Frameworks (KIO, KService, KI18n, KNotifications,
KGlobalAccel, KWindowSystem and KRunner) and Plasma Activities Stats. The installer
builds the tests, so the package lists include the Qt test tools and D-Bus.

| Family and tested desktop | Package names and distribution specifics | Full package list |
| --- | --- | --- |
| Debian 13.7 | APT. Debian 13 splits out `qt6-wayland-dev` and `qt6-wayland-dev-tools`. It uses `breeze-icon-theme`. Include `qt6-base-private-dev` for the Wayland adapter and `qml6-module-qtquick-effects` for drop shadows. | [Common APT packages](../packaging/apt-common.txt) + [Debian 13 additions](../packaging/debian-13-packages.txt) |
| Kubuntu 26.04.1 LTS and 26.10 | APT. Both tested releases use `qt6-base-dev`, `qt6-base-private-dev`, `qt6-base-dev-tools` and `kf6-breeze-icon-theme`. Install the common QML runtime packages as well as the development files. | [Common APT packages](../packaging/apt-common.txt) + [additions shared by both Kubuntu releases](../packaging/ubuntu-26.04-packages.txt) |
| Fedora KDE 45 | DNF. The private headers are in `qt6-qtbase-private-devel`. Qt Quick and shader tools use `qt6-qtdeclarative-devel` and `qt6-qtshadertools-devel`. Install `layer-shell-qt-devel` and `plasma-wayland-protocols-devel` for Wayland. | [Fedora dependencies](../packaging/fedora-45-packages.txt) |
| openSUSE Leap 16.1 | Zypper. Use `qt6-gui-private-devel`, `qt6-waylandclient-devel` and `layer-shell-qt6-devel`. The QML runtime is split across packages including `qt6-declarative-imports`, `kf6-kirigami-imports` and `kpipewire6-imports`. Native Plasma menu translations come from `plasma6-desktop-lang`. | [Leap dependencies](../packaging/opensuse-leap-16.1-packages.txt) |
| Arch family (tested on CachyOS) | Pacman or paru. Use `base-devel`, `qt6-base`, `qt6-declarative`, `qt6-shadertools`, `qt6-wayland`, `layer-shell-qt` and `plasma-wayland-protocols` alongside the KDE runtime packages. | [Arch packages](../packaging/arch-packages.txt) |

On KDE neon, `qt6-svg` supplies both Qt SVG plugins, and
`kf6-qqc2-desktop-style` supplies the `org.kde.desktop` QML module.
The installer uses these native names on neon.

For a manual installation, open Bash in the project directory and use the block for your system. The lists include the libraries, compiler and test tools used by the installer. On derivatives such as KDE neon, use the command printed by the installer to account for distribution-specific package names.

### Debian 13

```bash
sudo apt update
mapfile -t packages < <(cat packaging/apt-common.txt packaging/debian-13-packages.txt)
sudo apt install "${packages[@]}"
./install.sh
```

### Kubuntu 26.04 and 26.10

```bash
sudo apt update
mapfile -t packages < <(cat packaging/apt-common.txt packaging/ubuntu-26.04-packages.txt)
sudo apt install "${packages[@]}"
./install.sh
```

### Fedora KDE 45

```bash
mapfile -t packages < packaging/fedora-45-packages.txt
sudo dnf install "${packages[@]}"
./install.sh
```

### openSUSE Leap 16.1

```bash
mapfile -t packages < packaging/opensuse-leap-16.1-packages.txt
sudo zypper install "${packages[@]}"
./install.sh
```

### Arch and CachyOS

```bash
mapfile -t packages < packaging/arch-packages.txt
sudo pacman -S --needed "${packages[@]}"
./install.sh
```

## Bazzite KDE: build with Distrobox

On Bazzite KDE, the maintainer built the dock inside a Fedora 45 Distrobox
and confirmed it ran from the host desktop after leaving the container.

From a terminal on the **Bazzite host**, create and enter the build container:

```bash
distrobox create --name pnd-build --image registry.fedoraproject.org/fedora:45
distrobox enter pnd-build
```

**Inside the container**, clone the project and run the installer:

```bash
mkdir -p ~/git
git clone --branch v1.00.00 https://github.com/SarbaLabs/Plasma-Next-Dock.git ~/git/Plasma-Next-Dock
cd ~/git/Plasma-Next-Dock
CMAKE_BUILD_PARALLEL_LEVEL=2 ./install.sh
```

If dependencies are missing, the installer stops and prints a DNF command.
**Stay inside `pnd-build`** and run the command it prints. Alternatively, from
`~/git/Plasma-Next-Dock`, install the full Fedora 45 dependency list:

```bash
mapfile -t packages < packaging/fedora-45-packages.txt
sudo dnf install "${packages[@]}"
```

After DNF finishes, rerun the installer **inside the same container**:

```bash
CMAKE_BUILD_PARALLEL_LEVEL=2 ./install.sh
```

Once the build, tests and installation succeed, run `exit` to return to Bazzite.
The default Distrobox shares your home
directory, so the executable and desktop entry installed under `~/.local`
are available from the host's application launcher.

## Install or update from source

To install the [stable release](https://github.com/SarbaLabs/Plasma-Next-Dock/releases/tag/v1.00.00) using Git:

```bash
mkdir -p ~/git
cd ~/git
git clone --branch v1.00.00 https://github.com/SarbaLabs/Plasma-Next-Dock.git
cd Plasma-Next-Dock
./install.sh
```

The script builds, runs the available tests, and installs the executable and its
own application launcher and translation catalog under **`~/.local`**. The dock installation creates no
autostart entry and does not restart Plasma Shell. Change the destination only
when needed with `PLASMA_NEXT_DOCK_PREFIX=/your/prefix ./install.sh`.

To switch an existing checkout to the current stable version, fetch the tags and select the release. For future updates, substitute the published tag:

```bash
cd ~/git/Plasma-Next-Dock
git fetch origin --tags
git switch --detach v1.00.00
./install.sh
```

Quit and relaunch the running dock after updating. Source archives extracted from a release can use the same installer. To update an archive installation, extract the newer sources and run the installer in that directory.

## Troubleshooting

- **The build stops before CMake starts.** Read the list of missing packages. Run the suggested command, including the QML runtime modules, then rerun the installer. If a name is unconfirmed, refresh your distribution’s repository metadata and consult the family list above.
- **Compilation runs out of memory.** Try `CMAKE_BUILD_PARALLEL_LEVEL=2 ./install.sh`. Use `1` on machines with very little memory.
- **The dock stops launching after a Qt update.** Build again with the development files for the installed Qt version. If compilation still fails, include the first compiler error and your Qt and Plasma versions when reporting it.
- **A test fails.** From the checkout, run `ctest --test-dir build --rerun-failed --output-on-failure` to see the failed check. The installer installs the build after its tests pass.
- **The menu entry opens no dock.** In a terminal in your Plasma Wayland session, run `~/.local/bin/plasma-next-dock` to see the startup messages. To list the available displays, use `~/.local/bin/plasma-next-dock --list-screens`.

## Remove a source installation

Quit the running dock and run `./uninstall.sh` from the source checkout. If you supplied `PLASMA_NEXT_DOCK_PREFIX` at installation, supply the same value when uninstalling. The script removes the project’s binary, launcher, icon, translations, relay and bundled module files. It also removes its own autostart link if present. Your saved dock profiles are kept for later use.
