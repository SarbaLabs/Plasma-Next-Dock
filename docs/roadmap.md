# Development status and roadmap

The functional, compatibility and modular development phases are complete. The next milestone is the first tagged source release.

| Phase | Status | Outcome |
| --- | --- | --- |
| 1. Desktop features | Accepted | Independent docks, window previews, keyboard navigation, drag and drop, appearance and edge reservation |
| 2. Source compatibility | Validated | Shared source installer tested across distribution families, down to Plasma 6.3.6 and Qt 6.8.2 |
| 3. Code consolidation | Merged | Geometry, settings and task presentation reorganized while preserving existing profiles |
| 4. Modular v1.0 | Implemented and validated | Module API 1, per-dock module placement and five official modules |
| 5. Source distribution | In progress | Installer, family-specific instructions and compatibility matrix available |
| 6. First release | Upcoming | Stable tag, release notes and an AUR recipe targeting that tag |

## Completed work

CachyOS and Debian were the first reference desktops. The maintainer also tested mixed-scale displays and hotplug on CachyOS, and verified the dock on Intel integrated graphics and Virtio on Debian. The [compatibility matrix](compatibility.md) records the distribution versions, installation methods, desktop observations and automated test coverage. The [test log](testing.md) preserves results from earlier revisions.

The modular dock supports applications menu, unpinned applications, folders, Trash and USB storage modules. Each dock controls its own module placement. The native KDE launcher study is closed. The implemented Applications menu uses KDE’s application hierarchy and Plasma Search providers in a dock-owned popup. The [module guide](modules.md) describes the public contract and the [delivery record](development-history.md#modular-v10-delivery-record) preserves the original design and acceptance criteria.

## Remaining release work

1. **Identify the build.** Define the v1.0.0 project version and expose it through `plasma-next-dock --version` so users can identify a build in a bug report.
2. **Verify the source archive.** Extract the release candidate into a temporary directory on the existing reference VM, build with `./install.sh` into a temporary prefix, and launch a demo with isolated settings. This checks the archive contents using the already validated installation procedure.
3. **Publish the first source release.** Once the maintainer makes the repository public, protect `main`, publish the stable tag and release notes, and point the [installation instructions](installation.md) to the released source.
4. **Distribute through the AUR.** Build the same stable tag with a PKGBUILD for Arch and CachyOS. Verify installation, upgrade, independent module loading and removal before publishing the recipe.

The [development history](development-history.md) includes the original PR notes and the [indicator parity checklist](development-history.md#final-version-parity-requirement).
