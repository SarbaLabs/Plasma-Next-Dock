# Development status and roadmap

The functional, compatibility and modular development phases are complete. The [first stable source release](https://github.com/SarbaLabs/Plasma-Next-Dock/releases/tag/v1.00.00) is available. The next milestone is the AUR recipe.

| Phase | Status | Outcome |
| --- | --- | --- |
| 1. Desktop features | Accepted | Independent docks, window previews, keyboard navigation, drag and drop, appearance and edge reservation |
| 2. Source compatibility | Validated | Shared source installer tested across distribution families, down to Plasma 6.3.6 and Qt 6.8.2 |
| 3. Code consolidation | Merged | Geometry, settings and task presentation reorganized while preserving existing profiles |
| 4. Modular v1.0 | Implemented and validated | Module API 1, per-dock module placement and five official modules |
| 5. Source distribution | Archive validated | Public repository, tested source installer, family-specific instructions and compatibility matrix |
| 6. First release | Published | Stable tag v1.00.00 and release notes |

## Completed work

CachyOS and Debian were the first reference desktops. The maintainer also tested mixed-scale displays and hotplug on CachyOS, and verified the dock on Intel integrated graphics and Virtio on Debian. The [compatibility matrix](compatibility.md) records the distribution versions, installation methods, desktop observations and automated test coverage. The [test log](testing.md) preserves results from earlier revisions.

The modular dock supports applications menu, unpinned applications, folders, Trash and USB storage modules. Each dock controls its own module placement. The native KDE launcher study is closed. The implemented Applications menu uses KDE’s application hierarchy and Plasma Search providers in a dock-owned popup. The [module guide](modules.md) describes the public contract and the [delivery record](development-history.md#modular-v10-delivery-record) preserves the original design and acceptance criteria.

### Source archive and public access

On 26 November 2026, CachyOS and Debian 13.7 built the same GitHub source archive for commit [`c159f86`](https://github.com/SarbaLabs/Plasma-Next-Dock/commit/c159f86589d4c230f80e93b9db76e3f955b359b5). Its SHA-256 digest matched on both machines. On each system, `./install.sh` built the extracted sources, passed all 19 CTest entries and installed the dock into a temporary prefix. The installed executable reported `plasma-next-dock 1.00.00` and rendered the demo in a Wayland session.

The repository became public on the same day. Anonymous access was verified. GitHub now requires a pull request to merge into `main`, with zero required approvals, and blocks force pushes and deletion of the branch.

## Remaining release work

**Distribute through the AUR.** Build the same stable tag with a PKGBUILD for Arch and CachyOS. Verify installation, upgrade, independent module loading and removal before publishing the recipe.

The [development history](development-history.md) includes the original PR notes and the [indicator parity checklist](development-history.md#final-version-parity-requirement).
