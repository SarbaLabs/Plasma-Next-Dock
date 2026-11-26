# Tested desktop configurations

Plasma Next Dock targets KDE Plasma on Wayland. The oldest desktop validated during development is **Debian 13 with Plasma 6.3.6 and Qt 6.8.2**. This matrix records the pre-release campaign through 26 November 2026. For installation commands and distribution-specific dependencies, see the [source installation guide](installation.md).

## Reference desktops

All six configurations were built from the shared sources. CachyOS and Debian were the first reference desktops. The observations below cover checks made across development revisions.

| Desktop | Plasma | Qt | Installation method | Desktop checks |
| --- | --- | --- | --- | --- |
| CachyOS (rolling) | 6.8.3 on the reference VM | 6.12.1 on the reference VM | Native source build, Arch packages | On the maintainer’s two-monitor desktop, independently configured docks, different scale factors, all four edges, output disconnection and reconnection. The VM also exercised menus, drag and drop, zoom and window avoidance. |
| Debian 13.7 | 6.3.6 | 6.8.2 | Native source build, APT | Launch and update, module loading, menus, resizing and shadows. The maintainer verified blur on Virtio and Intel integrated graphics. A separate Debian packaging trial also launched successfully on a fresh Debian KDE installation. |
| Kubuntu 26.04.1 LTS | 6.6.6 | 6.10.2 | Native source build, APT | Four edges, zoom, menu, shadows and blur requests to KWin. Two profiles retained their pins after replacing and removing a module. |
| Kubuntu 26.10 | 6.7.5 | 6.11.2 | Native source build, APT | Four edges, scrolling, pinning, shadows and settings. Two existing profiles retained their pin order across restart and module replacement. |
| Fedora KDE 45 | 6.8.1 | 6.11.2 | Native source build, DNF | Four edges, launchers, menus, zoom, shadows and profile migration on Virtio. The maintainer also validated the desktop on Intel integrated graphics. |
| openSUSE Leap 16.1 | 6.6.4 | 6.11.0 | Native source build, Zypper | Four edges, extended dock, pinning, module replacement and blur requests to KWin. The maintainer also verified operation on Intel integrated graphics and a normal Plasma login after reboot. |

The CachyOS version numbers identify the VM used for the final local build. The multi-monitor checks took place separately on the maintainer’s desktop. [Desktop test records](testing.md)

## Additional installations verified by the maintainer

These installations were checked during the source installer campaign. The record confirms successful installation and operation. Exact Plasma and Qt versions were generally not recorded for this campaign.

| Family | Desktops | Installation method and scope |
| --- | --- | --- |
| Debian / Ubuntu | MX Linux KDE, KDE neon | Native build with APT dependencies. The neon native application status test passed on Qt 6.11.1. The installer accounts for neon’s Qt SVG and KDE desktop-style package names. |
| Arch | EndeavourOS, Manjaro KDE, Garuda Linux | Native build using the Arch-family dependency list. |
| Fedora | Nobara Linux KDE | Native build with DNF dependencies. |
| Fedora Atomic | Bazzite KDE | Built inside a Fedora 45 Distrobox and launched from the host desktop using the shared home directory. [Bazzite procedure](installation.md#bazzite-kde-build-with-distrobox) |
| openSUSE | openSUSE Tumbleweed KDE | Native build with Zypper dependencies. |

## Automated checks

The local CachyOS build of revision `9e96b54` passed all **19 CTest entries**. The modular dock also passed 19 tests on Debian 13.7. The later reference runs on both Kubuntu releases, Fedora 45 and Leap 16.1 each recorded 19/19 at revision `5964aa5`. These checks cover areas including settings persistence, module loading, menus and dock geometry. Multi-monitor behavior, input and compositor effects were verified separately on the desktops listed above.

The [GitHub Actions workflow](../.github/workflows/build.yml) defines container jobs for Debian 13, Ubuntu 26.04 and 26.10, Fedora 45 and Leap 16.1. It checks missing-dependency reporting, builds the project, runs CTest and inspects a staged installation. The results reported above are from the local campaigns.
